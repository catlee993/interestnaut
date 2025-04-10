package spotify

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strings"
	"sync"
	"time"

	"interestnaut/internal/openai"

	"github.com/joho/godotenv"
	"github.com/pkg/errors"
)

// WailsClient represents a Spotify client for Wails.
type WailsClient struct {
	app *App // Changed from Client to App
	mu  sync.RWMutex
}

// NewWailsClient creates a new Spotify client for Wails.
func NewWailsClient() *WailsClient {
	// Load environment variables for auth config
	if err := godotenv.Load(); err != nil {
		// Non-fatal, might be set in the environment already
		log.Printf("Warning: Error loading .env file for WailsClient: %v", err)
	}

	// Create AuthConfig from environment variables
	authCfg := &AuthConfig{
		ClientID:    os.Getenv("SPOTIFY_CLIENT_ID"),   // Use actual env var names
		RedirectURI: "http://localhost:8080/callback", // Ensure this matches Spotify dev console and auth.go
	}

	// Validate required AuthConfig fields
	if authCfg.ClientID == "" {
		log.Printf("ERROR: SPOTIFY_CLIENT_ID or SPOTIFY_CLIENT_SECRET environment variables not set.")
		// Return a non-functional client with nil app
		return &WailsClient{app: nil}
	}

	// Instantiate App with the loaded AuthConfig
	app, err := NewApp(authCfg)
	if err != nil {
		log.Printf("ERROR: Failed to initialize core App in WailsClient: %v", err)
		// Return a non-functional client with nil app
		return &WailsClient{app: nil}
	}

	return &WailsClient{
		app: app,
	}
}

// SetSpotifyClient updates the underlying Spotify client within the App.
// This should be called after successful authentication.
func (w *WailsClient) SetSpotifyClient(client Client) {
	w.mu.Lock()
	defer w.mu.Unlock()
	if w.app != nil {
		w.app.SetClient(client) // Call the new setter on App
		log.Println("WailsClient: Spotify client updated within App.")
	} else {
		log.Println("WailsClient ERROR: Attempted to set client, but App is nil.")
	}
}

// GetSpotifyApp returns the underlying Spotify App instance (use with caution)
func (w *WailsClient) GetSpotifyApp() *App {
	w.mu.RLock()
	defer w.mu.RUnlock()
	return w.app
}

// GetSavedTracks retrieves the user's saved tracks.
func (w *WailsClient) GetSavedTracks(limit, offset int) (*SavedTracks, error) {
	w.mu.RLock()
	app := w.app
	w.mu.RUnlock()

	if app == nil || app.client == nil { // Check if app or its internal client is nil
		return nil, ErrNotAuthenticated
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	return app.GetSavedTracks(ctx, limit, offset) // Call method on App
}

// SearchTracks searches for tracks matching the query.
func (w *WailsClient) SearchTracks(query string, limit int) ([]*SimpleTrack, error) {
	w.mu.RLock()
	app := w.app
	w.mu.RUnlock()

	if app == nil || app.client == nil {
		return nil, ErrNotAuthenticated
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	return app.SearchTracks(ctx, query, limit) // Call method on App
}

// SaveTrack saves a track to the user's library.
func (w *WailsClient) SaveTrack(trackID string) error {
	w.mu.RLock()
	app := w.app
	w.mu.RUnlock()

	if app == nil || app.client == nil {
		return ErrNotAuthenticated
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	return app.SaveTrack(ctx, trackID) // Call method on App
}

// RemoveTrack removes a track from the user's library.
func (w *WailsClient) RemoveTrack(trackID string) error {
	w.mu.RLock()
	app := w.app
	w.mu.RUnlock()

	if app == nil || app.client == nil {
		return ErrNotAuthenticated
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	return app.RemoveTrack(ctx, trackID) // Call method on App
}

// GetCurrentUser retrieves the current user's profile.
func (w *WailsClient) GetCurrentUser() (*UserProfile, error) {
	w.mu.RLock()
	app := w.app
	w.mu.RUnlock()

	if app == nil || app.client == nil {
		return nil, ErrNotAuthenticated
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	return app.GetCurrentUser(ctx) // Call method on App
}

// SetUserID sets the current user ID in the App.
func (w *WailsClient) SetUserID(userID string) error {
	w.mu.Lock()
	defer w.mu.Unlock()

	if w.app == nil {
		return errors.New("Internal error: App not initialized")
	}
	if w.app.openaiClient == nil {
		return errors.New("Internal error: OpenAI client not initialized")
	}

	w.app.userID = userID
	w.app.openaiClient.SetUserID(userID)
	return nil
}

// --- New Methods for Suggestions ---

// GetInitialSuggestionState determines if initial library processing is needed.
func (w *WailsClient) GetInitialSuggestionState() (needsProcessing bool, err error) {
	w.mu.RLock()
	app := w.app
	w.mu.RUnlock()

	if app == nil {
		return false, errors.New("Internal error: App not initialized")
	}

	app.mu.RLock()
	hasAnalyzed := app.hasAnalyzedLibrary
	app.mu.RUnlock()

	return !hasAnalyzed, nil
}

// ProcessLibraryAndGetFirstSuggestion fetches tracks, gets suggestion, searches, and returns details.
func (w *WailsClient) ProcessLibraryAndGetFirstSuggestion() (*SuggestedTrackInfo, error) {
	w.mu.RLock()
	app := w.app
	w.mu.RUnlock()

	if app == nil {
		return nil, errors.New("Internal error: App not initialized")
	}
	if app.openaiClient == nil {
		return nil, errors.New("Internal error: OpenAI client not initialized")
	}
	if app.client == nil {
		return nil, ErrNotAuthenticated
	}

	log.Println("Processing library for first suggestion...")
	allTracks, err := app.GetAllSavedTracks(context.Background())
	if err != nil {
		return nil, errors.Wrap(err, "failed to fetch all saved tracks")
	}

	// Get the current user ID
	userID := app.GetCurrentUserID()
	if userID == "" {
		return nil, errors.New("no user ID available")
	}

	// Check if we've already analyzed the library by checking the session
	hasAnalyzed := app.openaiClient.HasAnalyzedLibrary(userID)

	// Only add the track list to the session if we haven't analyzed the library yet
	if !hasAnalyzed {
		prompt := FormatTracksForInitialPrompt(allTracks)

		// Send the initial prompt to OpenAI
		suggestionContent, err := app.openaiClient.SendMessage(context.Background(), userID, prompt)
		if err != nil {
			return nil, errors.Wrap(err, "failed to get suggestion from OpenAI")
		}

		return processAISuggestion(app, suggestionContent)
	} else {
		// If we've already analyzed the library, just request a new suggestion
		suggestionContent, err := app.openaiClient.SendMessage(
			context.Background(),
			userID,
			"Please suggest another song based on my library and our conversation so far.",
		)
		if err != nil {
			return nil, errors.Wrap(err, "failed to get suggestion from OpenAI")
		}

		return processAISuggestion(app, suggestionContent)
	}
}

// RequestNewSuggestion gets a new suggestion based on the chat history.
func (w *WailsClient) RequestNewSuggestion() (*SuggestedTrackInfo, error) {
	w.mu.RLock()
	app := w.app
	w.mu.RUnlock()

	if app == nil {
		return nil, errors.New("Internal error: App not initialized")
	}
	if app.openaiClient == nil {
		return nil, errors.New("Internal error: OpenAI client not initialized")
	}
	if app.client == nil {
		return nil, ErrNotAuthenticated
	}

	// Get the current user ID
	userID := app.GetCurrentUserID()
	if userID == "" {
		return nil, errors.New("no user ID available")
	}

	// Request a new suggestion
	suggestionContent, err := app.openaiClient.SendMessage(
		context.Background(),
		userID,
		"Please suggest another song based on my library and our conversation so far.",
	)
	if err != nil {
		return nil, errors.Wrap(err, "failed to get suggestion from OpenAI")
	}

	return processAISuggestion(app, suggestionContent)
}

// Helper function to process AI suggestion response
func processAISuggestion(app *App, content string) (*SuggestedTrackInfo, error) {
	// Parse name, artist, album, reason, optional ID
	var suggestion struct {
		Name   string `json:"name"`
		Artist string `json:"artist"`
		Album  string `json:"album"`
		Reason string `json:"reason"`
		ID     string `json:"id"`
	}
	if err := json.Unmarshal([]byte(content), &suggestion); err != nil {
		log.Printf("ERROR: Failed to parse JSON: %v. Content: %s", err, content)
		return nil, errors.Wrap(err, "failed to parse suggestion JSON from AI")
	}
	if suggestion.Name == "" || suggestion.Artist == "" {
		log.Printf("ERROR: AI suggestion missing name or artist. Content: %s", content)
		return nil, errors.New("AI suggestion response was missing name or artist")
	}

	// Check if this song has been suggested before
	if app.openaiClient != nil && app.openaiClient.HasSuggested(suggestion.Name, suggestion.Artist) {
		log.Printf("WARNING: AI suggested a duplicate song: %s by %s. Requesting another suggestion.", suggestion.Name, suggestion.Artist)
		// Add a message to remind the AI not to suggest duplicates
		app.chatHistory = append(app.chatHistory, openai.Message{
			Role:    "user",
			Content: fmt.Sprintf("You suggested '%s' by '%s' again, but this has already been suggested before. Please suggest a different song.", suggestion.Name, suggestion.Artist),
		})
		// Request another suggestion recursively
		return processAISuggestion(app, content)
	}

	log.Printf("Parsed suggestion - Name: %s, Artist: %s, Album: %s, Reason: %s, ID: %s",
		suggestion.Name, suggestion.Artist, suggestion.Album, suggestion.Reason, suggestion.ID)

	// Search Spotify using Name, Artist, Album (limit 5 for disambiguation)
	var searchResults []*SimpleTrack
	searchLimit := 5

	// Check if the track name already includes the artist (e.g., "Artist - Song")
	var trackName, artistName string
	if strings.Contains(suggestion.Name, " - ") {
		parts := strings.Split(suggestion.Name, " - ")
		artistName = parts[0]
		trackName = parts[1]
	} else {
		trackName = suggestion.Name
		artistName = suggestion.Artist
	}

	// Primary search (with album)
	searchQuery := fmt.Sprintf("track:\"%s\" artist:\"%s\"", trackName, artistName)
	if suggestion.Album != "" {
		searchQuery += fmt.Sprintf(" album:\"%s\"", suggestion.Album)
	}
	log.Printf("Searching Spotify with query: %s (Limit: %d)", searchQuery, searchLimit)

	searchCtx, searchCancel := context.WithTimeout(context.Background(), 10*time.Second)
	searchResults, err := app.SearchTracks(searchCtx, searchQuery, searchLimit)
	searchCancel()

	if err != nil {
		return nil, errors.Wrap(err, fmt.Sprintf("failed to search for suggested track '%s' by '%s'", suggestion.Name, suggestion.Artist))
	}

	if len(searchResults) == 0 {
		return nil, fmt.Errorf("Could not find '%s' by '%s' on Spotify", suggestion.Name, suggestion.Artist)
	}

	// Try to find exact match if ID was provided
	var selectedTrack *SimpleTrack
	if suggestion.ID != "" {
		for _, track := range searchResults {
			if track.ID == suggestion.ID {
				selectedTrack = track
				break
			}
		}
	}

	if selectedTrack == nil {
		selectedTrack = searchResults[0]
		log.Printf("Using top search result (ID: %s) as no matching ID was provided or found.", selectedTrack.ID)
	}

	// Record this suggestion in the session using the Spotify track's name and artist
	if app.openaiClient != nil {
		if err := app.openaiClient.AddSuggestion(
			selectedTrack.Name,   // Use Spotify's track name
			selectedTrack.Artist, // Use Spotify's artist name
			selectedTrack.Album,
			selectedTrack.ID,
			suggestion.Reason,
		); err != nil {
			log.Printf("WARNING: Failed to record suggestion in session: %v", err)
		}
	}

	// Construct result from the selected SimpleTrack
	result := &SuggestedTrackInfo{
		ID:          selectedTrack.ID,
		Name:        selectedTrack.Name,
		Artist:      selectedTrack.Artist,
		PreviewURL:  selectedTrack.PreviewUrl,
		AlbumArtURL: selectedTrack.AlbumArtUrl,
	}
	return result, nil
}

// ProvideSuggestionFeedback sends user feedback to OpenAI and records the outcome.
func (w *WailsClient) ProvideSuggestionFeedback(feedback string) error {
	w.mu.RLock()
	app := w.app
	w.mu.RUnlock()

	if app == nil {
		return errors.New("Internal error: App not initialized")
	}
	if app.openaiClient == nil {
		return errors.New("Internal error: OpenAI client not initialized")
	}

	// Extract song name and artist from feedback message
	// Example formats:
	// "I liked the suggestion: Song Name by Artist Name"
	// "I disliked the suggestion: Song Name by Artist Name"
	// "I liked the suggestion Song Name by Artist Name so much I added it to my library!"
	var songName, artistName string
	var outcome openai.SuggestionOutcome

	// More precise string matching to avoid false positives
	if strings.Contains(feedback, "disliked the suggestion") {
		outcome = openai.OutcomeDisliked
	} else if strings.Contains(feedback, "skipped the suggestion") {
		outcome = openai.OutcomeSkipped
	} else if strings.Contains(feedback, "added it to my library") {
		outcome = openai.OutcomeAdded
	} else if strings.Contains(feedback, "liked the suggestion") {
		outcome = openai.OutcomeLiked
	} else {
		log.Printf("WARNING: Could not determine outcome from feedback: %s", feedback)
	}

	// Extract song name and artist from feedback
	// First try the format with colon
	parts := strings.Split(feedback, ": ")
	if len(parts) == 2 {
		nameAndArtist := strings.Split(parts[1], " by ")
		if len(nameAndArtist) == 2 {
			songName = strings.TrimSpace(nameAndArtist[0])
			artistName = strings.TrimSuffix(strings.TrimSpace(nameAndArtist[1]), ".")
			artistName = strings.TrimSuffix(artistName, " so much I added it to my library!")
		}
	} else {
		// Try alternative format without colon
		parts = strings.Split(feedback, " the suggestion ")
		if len(parts) == 2 {
			nameAndArtist := strings.Split(parts[1], " by ")
			if len(nameAndArtist) == 2 {
				songName = strings.TrimSpace(nameAndArtist[0])
				artistName = strings.TrimSuffix(strings.TrimSpace(nameAndArtist[1]), ".")
				artistName = strings.TrimSuffix(artistName, " so much I added it to my library!")
			}
		}
	}

	// Update the suggestion outcome if we could parse the song details
	if songName != "" && artistName != "" {
		// Ensure we have a valid userID
		userID := app.GetCurrentUserID()
		if userID == "" {
			return errors.New("no user ID available")
		}

		// Ensure the OpenAI client has the correct userID
		app.openaiClient.SetUserID(userID)

		log.Printf("Updating suggestion outcome for '%s' by '%s' to %s (userID: %s)", songName, artistName, outcome, userID)
		if err := app.openaiClient.UpdateSuggestionOutcome(songName, artistName, outcome); err != nil {
			log.Printf("WARNING: Failed to update suggestion outcome: %v", err)
		}
	} else {
		log.Printf("WARNING: Could not parse song name and artist from feedback: %s", feedback)
	}

	// Add the feedback to the chat history
	app.mu.Lock()
	app.chatHistory = append(app.chatHistory, openai.Message{
		Role:    "user",
		Content: feedback,
	})
	app.mu.Unlock()

	return nil
}

// GetValidToken exposes the function to get a valid access token for the frontend SDK.
func (w *WailsClient) GetValidToken() (string, error) {
	// Directly call the package-level function with a background context
	return GetValidToken(context.Background())
}

// GetAuthStatus exposes the App's GetAuthStatus method.
func (w *WailsClient) GetAuthStatus() map[string]interface{} {
	w.mu.RLock()
	app := w.app
	w.mu.RUnlock()
	if app == nil {
		// Return not authenticated if app isn't ready
		return map[string]interface{}{
			"isAuthenticated": false,
		}
	}
	return app.GetAuthStatus()
}

// WailsInit performs startup actions if needed.
func (w *WailsClient) WailsInit() {
	log.Println("Wails Spotify Client Initialized")
}

// --- Add Playback Methods ---

// PlayTrackOnDevice calls the App method to start playback.
func (w *WailsClient) PlayTrackOnDevice(deviceID string, trackURI string) error {
	w.mu.RLock()
	app := w.app
	w.mu.RUnlock()
	if app == nil {
		return errors.New("Internal error: App not initialized")
	}
	// Create a background context to pass to the underlying app method
	return app.PlayTrackOnDevice(context.Background(), deviceID, trackURI)
}

// PausePlaybackOnDevice calls the App method to pause playback.
func (w *WailsClient) PausePlaybackOnDevice(deviceID string) error {
	w.mu.RLock()
	app := w.app
	w.mu.RUnlock()
	if app == nil {
		return errors.New("Internal error: App not initialized")
	}
	// Create a background context to pass to the underlying app method
	return app.PausePlaybackOnDevice(context.Background(), deviceID)
}

// ClearSpotifyCredentials clears stored Spotify tokens.
func (w *WailsClient) ClearSpotifyCredentials() error {
	w.mu.RLock()
	app := w.app
	w.mu.RUnlock()
	if app == nil {
		return errors.New("Internal error: App not initialized")
	}
	return app.ClearSpotifyCredentials()
}

// WailsShutdown performs cleanup actions if needed.
func (w *WailsClient) WailsShutdown() {
	log.Println("Wails Spotify Client Shutting Down")
}
