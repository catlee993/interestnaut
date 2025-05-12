package bindings

import (
	"context"
	"fmt"
	"interestnaut/internal/app/directives"
	"interestnaut/internal/app/eventbus"
	"interestnaut/internal/app/gemini"
	"interestnaut/internal/app/llm"
	"interestnaut/internal/app/openai"
	"interestnaut/internal/app/session"
	"interestnaut/internal/app/spotify"
	"log"
	"sync"
	"time"

	"github.com/pkg/errors"
)

const limit = 5

// Music represents the music-related functionality
type Music struct {
	spotifyAuthConfig      *spotify.AuthConfig
	spotifyClient          spotify.Client
	llmClients             map[string]llm.Client[session.Music]
	manager                session.Manager[session.Music]
	centralManager         session.CentralManager
	baselineFunc, taskFunc func() string
	mu                     sync.Mutex
}

func NewMusicBinder(ctx context.Context, cm session.CentralManager, clientID string) *Music {
	sac := &spotify.AuthConfig{
		ClientID:    clientID,
		RedirectURI: "http://localhost:8080/callback",
	}

	// Create a map of LLM clients for both providers
	llmClients := make(map[string]llm.Client[session.Music])

	// Initialize OpenAI client
	openaiClient, err := openai.NewClient[session.Music](cm)
	if err != nil {
		log.Printf("WARNING: Failed to create OpenAI client: %v", err)
	} else {
		llmClients["openai"] = openaiClient
	}

	// Initialize Gemini client
	geminiClient, err := gemini.NewClient[session.Music](cm)
	if err != nil {
		log.Printf("WARNING: Failed to create Gemini client: %v", err)
	} else {
		llmClients["gemini"] = geminiClient
	}

	// No longer fail if no clients were created - they can be refreshed later
	if len(llmClients) == 0 {
		log.Printf("WARNING: No LLM clients available, credentials may need to be added")
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
		llmClients:        llmClients,
		manager:           cm.Music(),
		centralManager:    cm,
		baselineFunc:      baselineFunc,
		taskFunc:          taskFunc,
	}
}

// GetSavedTracks retrieves the user's saved tracks.
func (m *Music) GetSavedTracks(limit, offset int) (*spotify.SavedTracks, error) {
	return m.spotifyClient.GetSavedTracks(context.Background(), limit, offset)
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

// RequestNewSuggestion gets a new suggestion based on the chat history.
func (m *Music) RequestNewSuggestion() (*spotify.SuggestedTrackInfo, error) {
	ctx := context.Background()

	sess := m.manager.GetOrCreateSession(ctx, m.manager.Key(), m.taskFunc, m.baselineFunc)

	// Get current LLM provider from settings
	provider := m.centralManager.Settings().GetLLMProvider()

	// Get the appropriate client
	llmClient, ok := m.llmClients[provider]
	if !ok {
		// Fall back to openai if the requested provider is not available
		log.Printf("WARNING: Requested LLM provider '%s' not available, falling back to openai", provider)
		llmClient, ok = m.llmClients["openai"]
		if !ok {
			log.Printf("WARNING: No LLM clients available, providing a default suggestion")
			// Create a fallback track with a warning message
			fallbackTrack := &spotify.SuggestedTrackInfo{
				ID:          "",
				Name:        "LLM Suggestion Unavailable",
				Artist:      "System Message",
				Album:       "Interestnaut",
				PreviewURL:  "",
				AlbumArtURL: "",
				Reason:      "LLM services are currently unavailable. Please ensure your API keys are correctly configured.",
				URI:         "",
			}
			return fallbackTrack, nil
		}
	}

	messages, err := llmClient.ComposeMessages(ctx, &sess.Content)
	if err != nil {
		return nil, errors.Wrap(err, "failed to compose message for LLM")
	}

	// Request a new content
	suggestion, err := llmClient.SendMessages(ctx, messages...)
	if err != nil {
		return nil, errors.Wrap(err, "failed to get suggestion from LLM")
	}

	// Check both top-level and content fields for artist
	artist := suggestion.Artist
	if artist == "" {
		artist = suggestion.Content.Artist
	}

	if suggestion.Title == "" || artist == "" {
		log.Printf("ERROR: LLM content missing title or artist. Content: %+v", suggestion)
		return nil, errors.New("LLM content response was missing title or artist")
	}

	searchQuery := fmt.Sprintf("track:\"%s\" artist:\"%s\"", suggestion.Title, artist)
	if suggestion.Album != "" || suggestion.Content.Album != "" {
		album := suggestion.Album
		if album == "" {
			album = suggestion.Content.Album
		}
		searchQuery += fmt.Sprintf(" album:\"%s\"", album)
	}
	tracks, err := m.searchTracks(ctx, searchQuery, limit)

	if err != nil {
		return nil, errors.Wrap(err, fmt.Sprintf("failed to search for suggested track '%s' by '%s'", suggestion.Title, artist))
	}

	if len(tracks) == 0 {
		// try without album before giving up
		searchQuery = fmt.Sprintf("track:\"%s\" artist:\"%s\"", suggestion.Title, artist)
		tracks, err = m.searchTracks(ctx, searchQuery, limit)
		if err != nil || len(tracks) == 0 {
			return nil, fmt.Errorf("could not find '%s' by '%s' on Spotify", suggestion.Title, artist)
		}
	}

	matchedTrack := m.match(ctx, suggestion.Title, artist, tracks)
	if matchedTrack == nil {
		return nil, fmt.Errorf("could not find '%s' by '%s' on Spotify", suggestion.Title, artist)
	}

	// Use the matched track's information for the session to ensure consistent key matching
	// This is critical because the agent might suggest slightly off information
	sessionSuggestion := session.Suggestion[session.Music]{
		PrimaryGenre: suggestion.PrimaryGenre,
		UserOutcome:  session.Pending,
		Reasoning:    suggestion.Reason,
		Content: session.Music{
			Title:  matchedTrack.Name,
			Artist: matchedTrack.Artist,
			Album:  matchedTrack.Album,
		},
	}
	if sErr := m.manager.AddSuggestion(
		ctx,
		sess,
		sessionSuggestion,
	); sErr != nil {
		log.Printf("ERROR: Failed to add suggestion: %v", sErr)
		return nil, errors.Wrap(sErr, "failed to add suggestion")
	}

	return &spotify.SuggestedTrackInfo{
		ID:          matchedTrack.ID,
		Name:        matchedTrack.Name,
		Artist:      matchedTrack.Artist,
		Album:       matchedTrack.Album,
		PreviewURL:  matchedTrack.PreviewUrl,
		AlbumArtURL: matchedTrack.AlbumArtUrl,
		Reason:      suggestion.Reason,
		URI:         matchedTrack.URI,
	}, nil
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
	// Lock to prevent race conditions during auth operations
	m.mu.Lock()
	defer m.mu.Unlock()

	// Check if client exists and has valid credentials
	isAuthenticated := false

	// Only report as authenticated if we can get a valid token
	if m.spotifyClient != nil {
		// Try to get a token, but don't return error to avoid crashing
		_, err := m.GetValidToken()
		isAuthenticated = (err == nil)
	}

	return map[string]interface{}{
		"isAuthenticated": isAuthenticated,
	}
}

// PlayTrackOnDevice calls the App method to start playback.
func (m *Music) PlayTrackOnDevice(deviceID string, trackURI string) error {
	return m.spotifyClient.PlayTrackOnDevice(context.Background(), deviceID, trackURI)
}

// PausePlaybackOnDevice calls the App method to pause playback.
func (m *Music) PausePlaybackOnDevice(deviceID string) error {
	return m.spotifyClient.PausePlaybackOnDevice(context.Background(), deviceID)
}

// ClearSpotifyCredentials clears stored Spotify tokens.
func (m *Music) ClearSpotifyCredentials() error {
	err := spotify.ClearSpotifyCredentials(context.Background())
	spotifyClient := spotify.NewClient()

	m.setSpotifyClient(spotifyClient)

	return err
}

// SearchTracks searches for tracks matching the query.
func (m *Music) SearchTracks(query string, limit int) ([]*spotify.SimpleTrack, error) {
	return m.spotifyClient.SearchTracks(context.Background(), query, limit)
}

func (m *Music) searchTracks(ctx context.Context, query string, limit int) ([]*spotify.SimpleTrack, error) {
	searchCtx, searchCancel := context.WithTimeout(ctx, 10*time.Second)
	defer searchCancel()
	return m.spotifyClient.SearchTracks(searchCtx, query, limit)
}

// match finds a track that matches the given title and artist, using direct matching first
// and falling back to fuzzy matching if no direct match is found.
func (m *Music) match(_ context.Context, title, artist string, tracks []*spotify.SimpleTrack) *spotify.SimpleTrack {
	// First try direct match
	for _, track := range tracks {
		if track.Name == title && track.Artist == artist {
			return track
		}
	}

	// If no direct match, try fuzzy matching
	var bestMatch *spotify.SimpleTrack
	bestScore := 0.0

	for _, track := range tracks {
		titleScore := calculateSimilarity(track.Name, title)
		artistScore := calculateSimilarity(track.Artist, artist)
		// Weights don't need to sum to 1, but should be in a reasonable range
		// Using 0.7 for title and 0.8 for artist to emphasize artist matching
		score := (titleScore * 0.5) + (artistScore * 0.5)

		if score > bestScore {
			bestScore = score
			bestMatch = track
		}
	}

	// Adjust threshold proportionally (0.8 * 1.5 = 1.2)
	if bestScore >= 0.75 {
		return bestMatch
	}

	return nil
}

// setSpotifyClient updates the underlying Spotify client within the App.
// This should be called after successful authentication.
func (m *Music) setSpotifyClient(client spotify.Client) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.spotifyClient = client
}

// RefreshLLMClients attempts to recreate LLM clients that may have failed to initialize
func (m *Music) RefreshLLMClients() {
	m.mu.Lock()
	defer m.mu.Unlock()

	log.Println("Refreshing Music LLM clients")

	// Check if OpenAI client is missing
	if _, ok := m.llmClients["openai"]; !ok {
		openaiClient, err := openai.NewClient[session.Music](m.centralManager)
		if err != nil {
			log.Printf("WARNING: Failed to create OpenAI client: %v", err)
		} else {
			m.llmClients["openai"] = openaiClient
			log.Println("Successfully created OpenAI client for Music")
		}
	}

	// Check if Gemini client is missing
	if _, ok := m.llmClients["gemini"]; !ok {
		geminiClient, err := gemini.NewClient[session.Music](m.centralManager)
		if err != nil {
			log.Printf("WARNING: Failed to create Gemini client: %v", err)
		} else {
			m.llmClients["gemini"] = geminiClient
			log.Println("Successfully created Gemini client for Music")
		}
	}

	if len(m.llmClients) == 0 {
		log.Printf("WARNING: Could not create any LLM clients after refresh, functionality may be limited")
	}
}

// InitiateSpotifyAuth explicitly starts the Spotify authentication flow
func (m *Music) InitiateSpotifyAuth() error {
	// Use mutex to prevent duplicate auth attempts
	m.mu.Lock()
	// Only lock during the check and goroutine creation, not during the entire auth flow
	defer m.mu.Unlock()

	log.Println("Explicitly initiating Spotify authentication flow")

	// Create a semaphore channel to control concurrent auth attempts
	authSemaphore := make(chan struct{}, 1)

	// Check if semaphore can be acquired (meaning no auth is in progress)
	select {
	case authSemaphore <- struct{}{}: // Successfully acquired semaphore
		// Continue with auth flow
	default:
		// Another auth is already in progress
		log.Println("Spotify authentication already in progress, ignoring duplicate request")
		return nil
	}

	// Move the authentication to a goroutine
	go func() {
		// Release semaphore when done to allow future auth attempts
		defer func() { <-authSemaphore }()

		// Additional safety to catch any panics
		defer func() {
			if r := recover(); r != nil {
				log.Printf("RECOVERED from panic in Spotify auth: %v", r)
				
				// Notify UI of auth failure via event bus
				if eb := eventbus.GetGlobalBus(); eb != nil {
					eb.EmitSafe(eventbus.Event{
						Type: "spotify_auth_status_changed",
						Payload: map[string]interface{}{
							"isAuthenticated": false,
							"error": fmt.Sprintf("Authentication process crashed: %v", r),
						},
					})
				}
			}
		}()

		// Run the auth flow
		err := spotify.RunInitialAuthFlow(context.Background())
		if err != nil {
			log.Printf("ERROR: Failed to run Spotify auth flow: %v", err)
			
			// Notify UI of auth failure via event bus
			if eb := eventbus.GetGlobalBus(); eb != nil {
				eb.EmitSafe(eventbus.Event{
					Type: "spotify_auth_status_changed",
					Payload: map[string]interface{}{
						"isAuthenticated": false,
						"error": err.Error(),
					},
				})
			}
			return
		}

		// Update the Spotify client after authentication
		spotifyClient := spotify.NewClient()
		m.setSpotifyClient(spotifyClient)

		// Verify token to ensure the authentication worked
		_, tokenErr := m.GetValidToken()
		if tokenErr != nil {
			log.Printf("Error getting token after auth: %v", tokenErr)
			
			// Notify UI of token verification failure via event bus
			if eb := eventbus.GetGlobalBus(); eb != nil {
				eb.EmitSafe(eventbus.Event{
					Type: "spotify_auth_status_changed",
					Payload: map[string]interface{}{
						"isAuthenticated": false,
						"error": fmt.Sprintf("Auth succeeded but token verification failed: %v", tokenErr),
					},
				})
			}
			return
		}

		// Get the user profile for the event payload
		userProfile, _ := m.GetCurrentUser()

		// Emit auth success event to notify Flutter UI
		if eb := eventbus.GetGlobalBus(); eb != nil {
			// Create payload - include user profile if available
			payload := map[string]interface{}{
				"isAuthenticated": true,
			}

			// Add user profile if available
			if userProfile != nil {
				payload["userProfile"] = userProfile
			}

			// Emit the event - use EmitSafe for FFI boundary safety
			eb.EmitSafe(eventbus.Event{
				Type:    "spotify_auth_status_changed",
				Payload: payload,
			})

			log.Println("Emitted auth success event to Flutter UI")
		} else {
			log.Println("Warning: Event bus unavailable, UI may not update")
		}
	}()

	// Return immediately, the auth process continues in the background
	return nil
}
