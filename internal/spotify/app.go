package spotify

import (
	"context"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"

	"interestnaut/internal/openai"

	"github.com/pkg/errors"
)

// App represents the Spotify application.
type App struct {
	client       Client
	authConfig   *AuthConfig
	openaiClient *openai.Client
	chatHistory  []openai.Message
	mu           sync.RWMutex
}

// AuthConfig represents the Spotify OAuth configuration.
type AuthConfig struct {
	ClientID     string
	ClientSecret string
	RedirectURI  string
}

// NewApp creates a new Spotify application.
func NewApp(authConfig *AuthConfig) (*App, error) {
	// Initialize OpenAI client
	oaiClient, err := openai.NewClient()
	if err != nil {
		return nil, errors.Wrap(err, "failed to initialize OpenAI client")
	}

	// Ensure authConfig is not nil before accessing fields
	if authConfig == nil {
		// Decide how to handle this - return error? Use defaults?
		// For now, returning an error seems safest.
		return nil, errors.New("AuthConfig cannot be nil when creating App")
	}

	// Initialize the Spotify client using the auth config
	spotifyClient := NewClientWithAuth(authConfig)

	return &App{
		authConfig:   authConfig,    // Store the passed config
		client:       spotifyClient, // Use the client initialized with auth
		openaiClient: oaiClient,
		chatHistory:  make([]openai.Message, 0),
	}, nil
}

// SetClient sets the underlying Spotify API client.
// This is useful after authentication completes.
func (a *App) SetClient(client Client) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.client = client
}

// GetAuthStatus returns the current authentication status
func (a *App) GetAuthStatus() map[string]interface{} {
	a.mu.RLock()
	defer a.mu.RUnlock()

	isAuthenticated := a.client != nil

	return map[string]interface{}{
		"isAuthenticated": isAuthenticated,
	}
}

// GetSavedTracks retrieves the user's saved tracks.
func (a *App) GetSavedTracks(ctx context.Context, limit, offset int) (*SavedTracks, error) {
	if a.client == nil {
		return nil, errors.New("not authenticated")
	}
	return a.client.GetSavedTracks(ctx, limit, offset)
}

// SearchTracks searches for tracks matching the query.
func (a *App) SearchTracks(ctx context.Context, query string, limit int) ([]*SimpleTrack, error) {
	if a.client == nil {
		return nil, errors.New("not authenticated")
	}
	return a.client.SearchTracks(ctx, query, limit)
}

// SaveTrack saves a track to the user's library.
func (a *App) SaveTrack(ctx context.Context, trackID string) error {
	if a.client == nil {
		return errors.New("not authenticated")
	}
	return a.client.SaveTrack(ctx, trackID)
}

// RemoveTrack removes a track from the user's library.
func (a *App) RemoveTrack(ctx context.Context, trackID string) error {
	if a.client == nil {
		return errors.New("not authenticated")
	}
	return a.client.RemoveTrack(ctx, trackID)
}

// GetAllSavedTracks retrieves all saved tracks for the user, handling pagination.
func (a *App) GetAllSavedTracks(ctx context.Context) ([]SavedTrackItem, error) {
	a.mu.RLock()
	client := a.client
	a.mu.RUnlock()

	if client == nil {
		return nil, ErrNotAuthenticated
	}

	var allTracks []SavedTrackItem
	limit := 50 // Max allowed by Spotify API
	offset := 0

	for {
		pageCtx, cancel := context.WithTimeout(ctx, 15*time.Second) // Timeout for each page request
		page, err := client.GetSavedTracks(pageCtx, limit, offset)
		cancel() // Release context resources promptly

		if err != nil {
			// Consider retries for transient errors?
			return nil, errors.Wrapf(err, "failed to get saved tracks page (offset %d)", offset)
		}

		if page == nil || len(page.Items) == 0 {
			break // No more tracks
		}

		allTracks = append(allTracks, page.Items...)

		if len(allTracks) >= page.Total {
			break // We have fetched all expected tracks
		}

		offset += limit

		// Optional: Add a small delay to avoid hitting rate limits aggressively
		time.Sleep(100 * time.Millisecond)
	}

	log.Printf("Fetched %d total saved tracks.", len(allTracks))
	return allTracks, nil
}

// GetCurrentUser retrieves the current user's profile.
func (a *App) GetCurrentUser(ctx context.Context) (*UserProfile, error) {
	if a.client == nil {
		return nil, errors.New("not authenticated")
	}
	return a.client.GetCurrentUser(ctx)
}

// FormatTracksForInitialPrompt creates a concise string representation of tracks.
func FormatTracksForInitialPrompt(tracks []SavedTrackItem) string {
	// TODO: Consider limits on prompt length. OpenAI has token limits.
	// We might need to truncate or summarize if the library is huge.
	var promptBuilder strings.Builder

	promptBuilder.WriteString("Here are some tracks the user likes:\n")

	limit := 100 // Limit the number of tracks included in the prompt for brevity/cost
	if len(tracks) > limit {
		// Optionally shuffle or select a representative sample if truncating
		tracks = tracks[:limit]
		promptBuilder.WriteString(fmt.Sprintf("(Showing first %d tracks)\n", limit))
	}

	for _, item := range tracks {
		if item.Track != nil {
			// Format: "Song Name" by Artist1, Artist2 (Album: Album Name)
			var artistNames []string
			for _, artist := range item.Track.Artists {
				artistNames = append(artistNames, artist.Name)
			}
			promptBuilder.WriteString(fmt.Sprintf("- \"%s\" by %s", item.Track.Name, strings.Join(artistNames, ", ")))
			if item.Track.Album.Name != "" {
				promptBuilder.WriteString(fmt.Sprintf(" (Album: %s)", item.Track.Album.Name))
			}
			promptBuilder.WriteString("\n")
		}
	}
	promptBuilder.WriteString("\nBased on these, suggest a new song.")

	return promptBuilder.String()
}
