package spotify

import (
	"context"
	"fmt"
	"log"
	"strings"
	"sync"
	"time"

	"interestnaut/internal/creds"
	"interestnaut/internal/openai"

	"github.com/pkg/errors"
)

// ErrNotAuthenticated definition removed, should be defined in errors.go

// App represents the Spotify application.
type App struct {
	authConfig         *AuthConfig
	client             Client
	openaiClient       *openai.WailsClient
	chatHistory        []openai.Message
	hasAnalyzedLibrary bool // Track if we've done initial analysis
	userID             string
	mu                 sync.RWMutex
}

// AuthConfig represents the Spotify OAuth configuration.
type AuthConfig struct {
	ClientID    string
	RedirectURI string
}

// NewApp creates a new Spotify application.
func NewApp(authConfig *AuthConfig) (*App, error) {
	// Initialize OpenAI client
	oaiClient, err := openai.NewWailsClient()
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
		userID:       "", // Initialize empty user ID
	}, nil
}

// SetClient sets the underlying Spotify API client.
// This is useful after authentication completes.
func (a *App) SetClient(client Client) {
	a.mu.Lock()
	defer a.mu.Unlock()
	a.client = client

	// Get the user ID from Spotify and set it on the OpenAI client
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if profile, err := client.GetCurrentUser(ctx); err == nil && profile != nil {
		a.userID = profile.ID
		if a.openaiClient != nil {
			a.openaiClient.SetUserID(profile.ID)
		}
	} else {
		log.Printf("WARNING: Failed to get user ID from Spotify: %v", err)
	}
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
	a.mu.RLock()
	client := a.client
	a.mu.RUnlock()

	if client == nil {
		return nil, errors.New("not authenticated")
	}
	return client.GetSavedTracks(ctx, limit, offset)
}

// SearchTracks searches for tracks matching the query.
func (a *App) SearchTracks(ctx context.Context, query string, limit int) ([]*SimpleTrack, error) {
	a.mu.RLock()
	client := a.client
	a.mu.RUnlock()

	if client == nil {
		return nil, errors.New("not authenticated")
	}
	return client.SearchTracks(ctx, query, limit)
}

// SaveTrack saves a track to the user's library.
func (a *App) SaveTrack(ctx context.Context, trackID string) error {
	a.mu.RLock()
	client := a.client
	a.mu.RUnlock()

	if client == nil {
		return errors.New("not authenticated")
	}
	return client.SaveTrack(ctx, trackID)
}

// RemoveTrack removes a track from the user's library.
func (a *App) RemoveTrack(ctx context.Context, trackID string) error {
	a.mu.RLock()
	client := a.client
	a.mu.RUnlock()

	if client == nil {
		return errors.New("not authenticated")
	}
	return client.RemoveTrack(ctx, trackID)
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

// GetTrackDetails retrieves detailed information for a single track.
func (a *App) GetTrackDetails(ctx context.Context, trackID string, market string) (*Track, error) {
	a.mu.RLock()
	client := a.client
	a.mu.RUnlock()

	if client == nil {
		return nil, ErrNotAuthenticated
	}
	return client.GetTrackDetails(ctx, trackID, market)
}

// GetCurrentUser retrieves the current user's profile.
func (a *App) GetCurrentUser(ctx context.Context) (*UserProfile, error) {
	a.mu.RLock()
	client := a.client
	a.mu.RUnlock()

	if client == nil {
		return nil, errors.New("not authenticated")
	}
	return client.GetCurrentUser(ctx)
}

// GetCurrentUserID returns the current user's ID.
func (a *App) GetCurrentUserID() string {
	a.mu.RLock()
	defer a.mu.RUnlock()
	return a.userID
}

// --- Playback Methods ---

// PlayTrackOnDevice starts playback of a specific track URI on a given device.
func (a *App) PlayTrackOnDevice(ctx context.Context, deviceID string, trackURI string) error {
	a.mu.RLock()
	client := a.client
	a.mu.RUnlock()

	if client == nil {
		return ErrNotAuthenticated
	}
	return client.PlayTrackOnDevice(ctx, deviceID, trackURI)
}

// PausePlaybackOnDevice pauses playback on a given device.
func (a *App) PausePlaybackOnDevice(ctx context.Context, deviceID string) error {
	a.mu.RLock()
	client := a.client
	a.mu.RUnlock()

	if client == nil {
		return ErrNotAuthenticated
	}
	return client.PausePlaybackOnDevice(ctx, deviceID)
}

// --- Credential Management ---

// ClearSpotifyCredentials clears stored Spotify tokens and resets in-memory state.
func (a *App) ClearSpotifyCredentials() error {
	log.Println("Attempting to clear Spotify credentials...")
	err := creds.ClearSpotifyCreds()
	if err != nil {
		log.Printf("ERROR: Failed to clear credentials from storage: %v", err)
		return errors.Wrap(err, "failed to clear stored credentials")
	}
	// Also clear in-memory tokens
	tokenMutex.Lock()
	accessToken = ""
	tokenExpiry = time.Time{}
	currentToken = "" // Clear legacy variable too
	currentTokenExp = time.Time{}
	tokenMutex.Unlock()
	log.Println("Cleared Spotify credentials from storage and memory.")

	// Reset the client to force re-authentication
	a.mu.Lock()
	a.client = nil
	a.mu.Unlock()

	// Start a new authentication flow
	ctx := context.Background()
	if err := RunInitialAuthFlow(ctx); err != nil {
		log.Printf("ERROR: Failed to start new auth flow after clearing credentials: %v", err)
		return errors.Wrap(err, "failed to start new auth flow")
	}

	// Create a new client with the auth config
	spotifyClient := NewClientWithAuth(a.authConfig)
	a.mu.Lock()
	a.client = spotifyClient
	a.mu.Unlock()

	return nil
}

// FormatTracksForInitialPrompt creates a concise string representation of tracks.
func FormatTracksForInitialPrompt(tracks []SavedTrackItem) string {
	var promptBuilder strings.Builder
	promptBuilder.WriteString("Here are all the tracks in the user's library. Use these to understand their music taste and suggest new songs they might enjoy. IMPORTANT: Only suggest songs that are NOT in this list:\n\n")

	// Create a more compact representation to save tokens
	// Format: "Artist - Song (Album)" one per line
	// This format uses fewer tokens than the previous verbose format
	for _, item := range tracks {
		if item.Track != nil {
			var artistNames []string
			for _, artist := range item.Track.Artists {
				artistNames = append(artistNames, artist.Name)
			}
			promptBuilder.WriteString(fmt.Sprintf("%s - %s",
				strings.Join(artistNames, ", "),
				item.Track.Name))
			if item.Track.Album.Name != "" {
				promptBuilder.WriteString(fmt.Sprintf(" (%s)", item.Track.Album.Name))
			}
			promptBuilder.WriteString("\n")
		}
	}

	promptBuilder.WriteString(fmt.Sprintf("\nAnalyzed %d tracks. Based on these, suggest songs that match their musical preferences while introducing new artists and styles. DO NOT suggest any songs from the list above. For each suggestion, explain why you think they'll like it based on specific patterns in their library.\n", len(tracks)))

	return promptBuilder.String()
}
