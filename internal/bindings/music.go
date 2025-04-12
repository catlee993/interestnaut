package bindings

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/pkg/errors"
	"interestnaut/internal/llm"
	"interestnaut/internal/openai"
	"interestnaut/internal/session"
	"interestnaut/internal/spotify"
	"log"
	"os"
	"sync"
	"time"
)

type Music struct {
	spotifyAuthConfig *spotify.AuthConfig
	spotifyClient     spotify.Client
	llmClient         llm.Client[session.Music]
	manager           session.Manager[session.Music]
	key               session.Key
	mu                sync.RWMutex
}

func NewMusicBinder(cm session.CentralManager) *Music {
	sac := &spotify.AuthConfig{
		ClientID:    os.Getenv("SPOTIFY_CLIENT_ID"),
		RedirectURI: "http://localhost:8080/callback",
	}
	llmClient, err := openai.NewClient[session.Music]()
	if err != nil {
		log.Printf("ERROR: Failed to create OpenAI client: %v", err)
		return nil
	}
	return &Music{
		spotifyAuthConfig: sac,
		spotifyClient:     spotify.NewClientWithAuth(sac),
		llmClient:         llmClient,
		manager:           cm.Music(),
		key:               session.DefaultUser,
	}
}

// SetSpotifyClient updates the underlying Spotify client within the App.
// This should be called after successful authentication.
func (m *Music) SetSpotifyClient(client spotify.Client) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.spotifyClient = client
}

// GetSavedTracks retrieves the user's saved tracks.
func (m *Music) GetSavedTracks(ctx context.Context, limit, offset int) (*spotify.SavedTracks, error) {
	return m.spotifyClient.GetSavedTracks(ctx, limit, offset)
}

// SearchTracks searches for tracks matching the query.
func (m *Music) SearchTracks(ctx context.Context, query string, limit int) ([]*spotify.SimpleTrack, error) {
	return m.spotifyClient.SearchTracks(ctx, query, limit)
}

// SaveTrack saves a track to the user's library.
func (m *Music) SaveTrack(ctx context.Context, trackID string) error {
	return m.spotifyClient.SaveTrack(ctx, trackID) // Call method on App
}

// RemoveTrack removes a track from the user's library.
func (m *Music) RemoveTrack(ctx context.Context, trackID string) error {
	return m.spotifyClient.RemoveTrack(ctx, trackID)
}

// GetCurrentUser retrieves the current user's profile.
func (m *Music) GetCurrentUser(ctx context.Context) (*spotify.UserProfile, error) {
	return m.spotifyClient.GetCurrentUser(ctx)
}

type SuggestionResponse struct {
	session.Music
	Reason string `json:"reason"`
	Title  string `json:"title"`
}

// RequestNewSuggestion gets a new suggestion based on the chat history.
func (m *Music) RequestNewSuggestion(ctx context.Context) (*spotify.SuggestedTrackInfo, error) {
	sess := m.manager.GetOrCreateSession(ctx, m.key)
	message, err := m.llmClient.ComposeMessage(ctx, &sess.Content)
	if err != nil {
		return nil, errors.Wrap(err, "failed to compose message for OpenAI")
	}

	// Request a new content
	suggestionContent, err := m.llmClient.SendMessage(ctx, message)
	if err != nil {
		return nil, errors.Wrap(err, "failed to get content from OpenAI")
	}

	var content SuggestionResponse
	if uErr := json.Unmarshal([]byte(suggestionContent), &content); uErr != nil {
		log.Printf("ERROR: Failed to parse JSON: %v. Suggestion: %s", uErr, content)
		return nil, errors.Wrap(uErr, "failed to parse content JSON from LLM")
	}
	if content.Title == "" || content.Artist == "" || content.Album == "" {
		log.Printf("ERROR: LLM content missing title, artist or album. Content: %s", content)
		return nil, errors.New("LLM content response was missing title, artist, or album")
	}

	searchQuery := fmt.Sprintf("track:\"%s\" artist:\"%s\"", content.Title, content.Artist)
	if content.Album != "" {
		searchQuery += fmt.Sprintf(" album:\"%s\"", content.Album)
	}
	searchCtx, searchCancel := context.WithTimeout(context.Background(), 10*time.Second)
	tracks, err := m.spotifyClient.SearchTracks(searchCtx, content.Title, 5)
	searchCancel()

	if err != nil {
		return nil, errors.Wrap(err, fmt.Sprintf("failed to search for suggested track '%s' by '%s'", content.Title, content.Artist))
	}

	if len(tracks) == 0 {
		return nil, fmt.Errorf("could not find '%s' by '%s' on Spotify", content.Title, content.Artist)
	}

	for _, track := range tracks {
		if track.Name == content.Title && track.Artist == content.Artist && track.Album == content.Album {
			return &spotify.SuggestedTrackInfo{
				ID:          track.ID,
				Name:        track.Name,
				Artist:      track.Artist,
				PreviewURL:  track.PreviewUrl,
				AlbumArtURL: track.AlbumArtUrl,
				Reason:      content.Reason,
			}, nil
		}
	}

	return nil, fmt.Errorf("could not find '%s' by '%s' on Spotify", content.Title, content.Artist)
}

// ProvideSuggestionFeedback sends user feedback to OpenAI and records the outcome.
func (m *Music) ProvideSuggestionFeedback(ctx context.Context, outcome session.Outcome, title, artist, album string) error {
	sess := m.manager.GetOrCreateSession(context.Background(), m.key)
	key := session.KeyerMusicInfo(title, artist, album)
	if err := m.manager.UpdateSuggestionOutcome(ctx, sess, key, outcome); err != nil {
		return errors.Wrap(err, "failed to update suggestion outcome")
	}

	return nil
}

// GetValidToken exposes the function to get a valid access token for the frontend SDK.
func (m *Music) GetValidToken(ctx context.Context) (string, error) {
	return spotify.GetValidToken(ctx)
}

// GetAuthStatus exposes the App's GetAuthStatus method.
func (m *Music) GetAuthStatus() map[string]interface{} {
	return map[string]interface{}{
		"isAuthenticated": m.spotifyClient != nil,
	}
}

// PlayTrackOnDevice calls the App method to start playback.
func (m *Music) PlayTrackOnDevice(ctx context.Context, deviceID string, trackURI string) error {
	// Create a background context to pass to the underlying app method
	return m.spotifyClient.PlayTrackOnDevice(ctx, deviceID, trackURI)
}

// PausePlaybackOnDevice calls the App method to pause playback.
func (m *Music) PausePlaybackOnDevice(ctx context.Context, deviceID string) error {
	// Create a background context to pass to the underlying app method
	return m.spotifyClient.PausePlaybackOnDevice(ctx, deviceID)
}

// ClearSpotifyCredentials clears stored Spotify tokens.
func (m *Music) ClearSpotifyCredentials() error {
	if err := m.ClearSpotifyCredentials(); err != nil {
		return errors.Wrap(err, "failed to clear Spotify credentials")
	}

	spotifyClient := spotify.NewClientWithAuth(&spotify.AuthConfig{
		ClientID:    os.Getenv("SPOTIFY_CLIENT_ID"),
		RedirectURI: "http://localhost:8080/callback",
	})

	m.SetSpotifyClient(spotifyClient)

	return nil
}
