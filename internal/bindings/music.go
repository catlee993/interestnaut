package bindings

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/pkg/errors"
	"interestnaut/internal/directives"
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
	spotifyAuthConfig      *spotify.AuthConfig
	spotifyClient          spotify.Client
	llmClient              llm.Client[session.Music]
	manager                session.Manager[session.Music]
	baselineFunc, taskFunc func() string
	mu                     sync.RWMutex
}

func NewMusicBinder(ctx context.Context, cm session.CentralManager) *Music {
	sac := &spotify.AuthConfig{
		ClientID:    os.Getenv("SPOTIFY_CLIENT_ID"),
		RedirectURI: "http://localhost:8080/callback",
	}
	llmClient, err := openai.NewClient[session.Music]()
	if err != nil {
		log.Printf("ERROR: Failed to create OpenAI client: %v", err)
		return nil
	}
	spotifyClient := spotify.NewClient()
	baselineFunc := func() string {
		return directives.GetMusicBaseline(ctx, spotifyClient)
	}
	taskFunc := func() string {
		return directives.MusicDirective
	}
	return &Music{
		spotifyAuthConfig: sac,
		spotifyClient:     spotifyClient,
		llmClient:         llmClient,
		manager:           cm.Music(),
		baselineFunc:      baselineFunc,
		taskFunc:          taskFunc,
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
func (m *Music) GetSavedTracks(limit, offset int) (*spotify.SavedTracks, error) {
	return m.spotifyClient.GetSavedTracks(context.Background(), limit, offset)
}

// SearchTracks searches for tracks matching the query.
func (m *Music) SearchTracks(query string, limit int) ([]*spotify.SimpleTrack, error) {
	return m.spotifyClient.SearchTracks(context.Background(), query, limit)
}

// SaveTrack saves a track to the user's library.
func (m *Music) SaveTrack(trackID string) error {
	return m.spotifyClient.SaveTrack(context.Background(), trackID) // Call method on App
}

// RemoveTrack removes a track from the user's library.
func (m *Music) RemoveTrack(trackID string) error {
	return m.spotifyClient.RemoveTrack(context.Background(), trackID)
}

// GetCurrentUser retrieves the current user's profile.
func (m *Music) GetCurrentUser() (*spotify.UserProfile, error) {
	return m.spotifyClient.GetCurrentUser(context.Background())
}

type SuggestionResponse struct {
	session.Music
	Reason       string `json:"reason"`
	Title        string `json:"title"`
	PrimaryGenre string `json:"primary_genre"`
}

// RequestNewSuggestion gets a new suggestion based on the chat history.
func (m *Music) RequestNewSuggestion() (*spotify.SuggestedTrackInfo, error) {
	ctx := context.Background()
	sess := m.manager.GetOrCreateSession(ctx, m.manager.Key(), m.taskFunc, m.baselineFunc)
	messages, err := m.llmClient.ComposeMessages(ctx, &sess.Content)
	if err != nil {
		return nil, errors.Wrap(err, "failed to compose message for OpenAI")
	}

	// Request a new content
	suggestionContent, err := m.llmClient.SendMessages(ctx, messages...)
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
	searchCtx, searchCancel := context.WithTimeout(ctx, 10*time.Second)
	tracks, err := m.spotifyClient.SearchTracks(searchCtx, searchQuery, 5)
	searchCancel()

	if err != nil {
		return nil, errors.Wrap(err, fmt.Sprintf("failed to search for suggested track '%s' by '%s'", content.Title, content.Artist))
	}

	if len(tracks) == 0 {
		// try without album before giving up
		searchQuery = fmt.Sprintf("track:\"%s\" artist:\"%s\"", content.Title, content.Artist)
		searchCtx, searchCancel = context.WithTimeout(ctx, 10*time.Second)
		tracks, err = m.spotifyClient.SearchTracks(searchCtx, searchQuery, 5)
		searchCancel()
		if err != nil || len(tracks) == 0 {
			return nil, fmt.Errorf("could not find '%s' by '%s' on Spotify", content.Title, content.Artist)
		}
	}

	for _, track := range tracks {
		if track.Name == content.Title && track.Artist == content.Artist {
			suggestion := session.Suggestion[session.Music]{
				Title:        content.Title,
				PrimaryGenre: content.PrimaryGenre,
				UserOutcome:  session.Pending,
				Reasoning:    content.Reason,
				Content: session.Music{
					Artist: content.Artist,
					Album:  content.Album,
				},
			}
			if sErr := m.manager.AddSuggestion(
				ctx,
				sess,
				suggestion,
				session.EqualMusicSuggestions,
				session.KeyerMusicSuggestion,
			); sErr != nil {
				log.Printf("ERROR: Failed to add suggestion: %v", sErr)
				return nil, errors.Wrap(sErr, "failed to add suggestion")
			}

			return &spotify.SuggestedTrackInfo{
				ID:          track.ID,
				Name:        track.Name,
				Artist:      track.Artist,
				Album:       track.Album,
				PreviewURL:  track.PreviewUrl,
				AlbumArtURL: track.AlbumArtUrl,
				Reason:      content.Reason,
			}, nil
		}
	}

	return nil, fmt.Errorf("could not find '%s' by '%s' on Spotify", content.Title, content.Artist)
}

// ProvideSuggestionFeedback sends user feedback to OpenAI and records the outcome.
func (m *Music) ProvideSuggestionFeedback(outcome session.Outcome, title, artist, album string) error {
	ctx := context.Background()
	sess := m.manager.GetOrCreateSession(ctx, m.manager.Key(), m.taskFunc, m.baselineFunc)
	key := session.KeyerMusicInfo(title, artist, album)
	if err := m.manager.UpdateSuggestionOutcome(ctx, sess, key, outcome); err != nil {
		return errors.Wrap(err, "failed to update suggestion outcome")
	}

	return nil
}

// GetValidToken exposes the function to get a valid access token for the frontend SDK.
func (m *Music) GetValidToken() (string, error) {
	return spotify.GetValidToken(context.Background())
}

// GetAuthStatus exposes the App's GetAuthStatus method.
func (m *Music) GetAuthStatus() map[string]interface{} {
	return map[string]interface{}{
		"isAuthenticated": m.spotifyClient != nil,
	}
}

// PlayTrackOnDevice calls the App method to start playback.
func (m *Music) PlayTrackOnDevice(deviceID string, trackURI string) error {
	// Create a background context to pass to the underlying app method
	return m.spotifyClient.PlayTrackOnDevice(context.Background(), deviceID, trackURI)
}

// PausePlaybackOnDevice calls the App method to pause playback.
func (m *Music) PausePlaybackOnDevice(deviceID string) error {
	// Create a background context to pass to the underlying app method
	return m.spotifyClient.PausePlaybackOnDevice(context.Background(), deviceID)
}

// ClearSpotifyCredentials clears stored Spotify tokens.
func (m *Music) ClearSpotifyCredentials() error {
	err := spotify.ClearSpotifyCredentials(context.Background())
	spotifyClient := spotify.NewClient()

	m.SetSpotifyClient(spotifyClient)

	return err
}
