package spotify

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
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
		ClientID:     os.Getenv("SPOTIFY_CLIENT_ID"),     // Use actual env var names
		ClientSecret: os.Getenv("SPOTIFY_CLIENT_SECRET"), // Use actual env var names
		RedirectURI:  "http://localhost:8080/callback",   // Ensure this matches Spotify dev console and auth.go
	}

	// Validate required AuthConfig fields
	if authCfg.ClientID == "" || authCfg.ClientSecret == "" {
		log.Printf("ERROR: SPOTIFY_CLIENT_ID or SPOTIFY_CLIENT_SECRET environment variables not set.")
		// Return a non-functional client if essential auth details are missing
		return &WailsClient{}
	}

	// Instantiate App with the loaded AuthConfig
	app, err := NewApp(authCfg)
	if err != nil {
		log.Printf("ERROR: Failed to initialize core App in WailsClient: %v", err)
		return &WailsClient{}
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

// --- New Methods for Suggestions ---

// GetInitialSuggestionState determines if initial library processing is needed.
func (w *WailsClient) GetInitialSuggestionState() (needsProcessing bool, err error) {
	w.mu.RLock()
	app := w.app
	w.mu.RUnlock()

	if app == nil {
		return false, errors.New("Internal error: App not initialized")
	}
	// Basic check: If chat history is empty, assume first time.
	// TODO: Need a more robust check, potentially persistent storage.
	needsProcessing = len(app.chatHistory) == 0
	return needsProcessing, nil
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

	prompt := FormatTracksForInitialPrompt(allTracks)
	// Prompt asking for name, artist, album, optional ID
	systemMessage := openai.Message{
		Role:    "system",
		Content: `You are a helpful music suggestion assistant. Based on the user's saved tracks, suggest a single song they might like. Provide the response ONLY as a valid JSON object with keys "name" (string, the track name), "artist" (string, the primary artist name), "album" (string, the album name), and optionally "id" (string, the Spotify track ID if you are confident). Example: {"name": "Song Title", "artist": "Artist Name", "album": "Album Name", "id": "track_id_if_known"} or {"name": "Another Song", "artist": "Another Artist", "album": "Another Album"}`,
	}
	userPromptMessage := openai.Message{Role: "user", Content: prompt}

	app.mu.Lock()
	app.chatHistory = []openai.Message{systemMessage, userPromptMessage}
	historyForAPI := append([]openai.Message{}, app.chatHistory...)
	app.mu.Unlock()

	log.Println("Sending prompt to OpenAI...")
	suggestionMsg, err := app.openaiClient.SendMessage(historyForAPI)
	if err != nil {
		log.Printf("ERROR: OpenAI call failed: %v", err)
		app.mu.Lock()
		app.chatHistory = []openai.Message{} // Clear history on failure
		app.mu.Unlock()
		return nil, errors.Wrap(err, "failed to get suggestion from OpenAI")
	}
	log.Println("Received suggestion message from OpenAI:", suggestionMsg.Content)

	app.mu.Lock()
	app.chatHistory = append(app.chatHistory, suggestionMsg)
	app.mu.Unlock()

	// Parse name, artist, album, optional ID
	var basicSuggestion struct {
		Name   string `json:"name"`
		Artist string `json:"artist"`
		Album  string `json:"album"`
		ID     string `json:"id"`
	}
	if err := json.Unmarshal([]byte(suggestionMsg.Content), &basicSuggestion); err != nil {
		log.Printf("ERROR: Failed to parse JSON: %v. Content: %s", err, suggestionMsg.Content)
		return nil, errors.Wrap(err, "failed to parse suggestion JSON from AI")
	}
	if basicSuggestion.Name == "" || basicSuggestion.Artist == "" {
		log.Printf("ERROR: AI suggestion missing name or artist. Content: %s", suggestionMsg.Content)
		return nil, errors.New("AI suggestion response was missing name or artist")
	}
	log.Printf("Parsed suggestion - Name: %s, Artist: %s, Album: %s, ID: %s", basicSuggestion.Name, basicSuggestion.Artist, basicSuggestion.Album, basicSuggestion.ID)

	// --- Search Spotify using Name, Artist, Album (limit 5 for disambiguation) ---
	var searchResults []*SimpleTrack
	searchLimit := 5

	// Primary search (with album)
	searchQuery := fmt.Sprintf("track:\"%s\" artist:\"%s\"", basicSuggestion.Name, basicSuggestion.Artist)
	if basicSuggestion.Album != "" {
		searchQuery += fmt.Sprintf(" album:\"%s\"", basicSuggestion.Album)
	}
	log.Printf("Searching Spotify with query: %s (Limit: %d)", searchQuery, searchLimit)
	searchCtx, searchCancel := context.WithTimeout(context.Background(), 10*time.Second)
	searchResults, err = app.SearchTracks(searchCtx, searchQuery, searchLimit)
	searchCancel() // Cancel context

	// Fallback search (without album) if needed
	if err != nil || len(searchResults) == 0 {
		if err != nil {
			log.Printf("WARN: Spotify search (with album) failed for query '%s': %v. Trying without album...", searchQuery, err)
		} else {
			log.Printf("WARN: Spotify search (with album) returned no results for query '%s'. Trying without album...", searchQuery)
		}
		searchQueryMinimal := fmt.Sprintf("track:\"%s\" artist:\"%s\"", basicSuggestion.Name, basicSuggestion.Artist)
		log.Printf("Searching Spotify with query: %s (Limit: %d)", searchQueryMinimal, searchLimit)
		searchCtx2, searchCancel2 := context.WithTimeout(context.Background(), 10*time.Second)
		searchResults, err = app.SearchTracks(searchCtx2, searchQueryMinimal, searchLimit)
		searchCancel2() // Cancel context
		if err != nil {
			log.Printf("ERROR: Spotify search (without album) also failed for query '%s': %v", searchQueryMinimal, err)
			return nil, errors.Wrapf(err, "Spotify search failed for suggestion '%s' by '%s'", basicSuggestion.Name, basicSuggestion.Artist)
		}
		if len(searchResults) == 0 {
			log.Printf("ERROR: Spotify search (without album) also returned no results for query '%s'", searchQueryMinimal)
			return nil, errors.Errorf("Could not find '%s' by '%s' on Spotify", basicSuggestion.Name, basicSuggestion.Artist)
		}
	}

	// --- Select the best match from results ---
	var selectedTrack *SimpleTrack = nil

	if basicSuggestion.ID != "" {
		log.Printf("Attempting to match provided ID '%s' within %d search results...", basicSuggestion.ID, len(searchResults))
		for _, track := range searchResults {
			if track.ID == basicSuggestion.ID {
				log.Printf("Found match for ID %s in search results!", basicSuggestion.ID)
				selectedTrack = track
				break
			}
		}
		if selectedTrack == nil {
			log.Printf("Provided ID '%s' not found in search results. Defaulting to top result.", basicSuggestion.ID)
		}
	}

	// Default to the first result if no ID was provided or if the ID didn't match
	if selectedTrack == nil {
		selectedTrack = searchResults[0]
		log.Printf("Using top search result (ID: %s) as no matching ID was provided or found.", selectedTrack.ID)
	}

	log.Printf("Selected track - ID: %s, Name: %s, Artist: %s", selectedTrack.ID, selectedTrack.Name, selectedTrack.Artist)

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

// RequestNewSuggestion uses the same search logic with ID disambiguation.
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

	log.Println("Processing library for first suggestion...")
	allTracks, err := app.GetAllSavedTracks(context.Background())
	if err != nil {
		return nil, errors.Wrap(err, "failed to fetch all saved tracks")
	}

	prompt := FormatTracksForInitialPrompt(allTracks)
	// Prompt asking for name, artist, album, optional ID
	systemMessage := openai.Message{
		Role:    "system",
		Content: `You are a helpful music suggestion assistant. Based on the user's saved tracks, suggest a single song they might like. Provide the response ONLY as a valid JSON object with keys "name" (string, the track name), "artist" (string, the primary artist name), "album" (string, the album name), and optionally "id" (string, the Spotify track ID if you are confident). Example: {"name": "Song Title", "artist": "Artist Name", "album": "Album Name", "id": "track_id_if_known"} or {"name": "Another Song", "artist": "Another Artist", "album": "Another Album"}`,
	}
	userPromptMessage := openai.Message{Role: "user", Content: prompt}

	app.mu.Lock()
	app.chatHistory = []openai.Message{systemMessage, userPromptMessage}
	historyForAPI := append([]openai.Message{}, app.chatHistory...)
	app.mu.Unlock()

	log.Println("Sending prompt to OpenAI...")
	suggestionMsg, err := app.openaiClient.SendMessage(historyForAPI)
	if err != nil {
		log.Printf("ERROR: OpenAI call failed: %v", err)
		app.mu.Lock()
		app.chatHistory = []openai.Message{} // Clear history on failure
		app.mu.Unlock()
		return nil, errors.Wrap(err, "failed to get suggestion from OpenAI")
	}
	log.Println("Received suggestion message from OpenAI:", suggestionMsg.Content)

	app.mu.Lock()
	app.chatHistory = append(app.chatHistory, suggestionMsg)
	app.mu.Unlock()

	// Parse name, artist, album, optional ID
	var basicSuggestion struct {
		Name   string `json:"name"`
		Artist string `json:"artist"`
		Album  string `json:"album"`
		ID     string `json:"id"`
	}
	if err := json.Unmarshal([]byte(suggestionMsg.Content), &basicSuggestion); err != nil {
		log.Printf("ERROR: Failed to parse JSON: %v. Content: %s", err, suggestionMsg.Content)
		return nil, errors.Wrap(err, "failed to parse suggestion JSON from AI")
	}
	if basicSuggestion.Name == "" || basicSuggestion.Artist == "" {
		log.Printf("ERROR: AI suggestion missing name or artist. Content: %s", suggestionMsg.Content)
		return nil, errors.New("AI suggestion response was missing name or artist")
	}
	log.Printf("Parsed suggestion - Name: %s, Artist: %s, Album: %s, ID: %s", basicSuggestion.Name, basicSuggestion.Artist, basicSuggestion.Album, basicSuggestion.ID)

	// --- Search Spotify using Name, Artist, Album (limit 5) ---
	var searchResults []*SimpleTrack
	searchLimit := 5
	// Primary search (with album)
	searchQuery := fmt.Sprintf("track:\"%s\" artist:\"%s\"", basicSuggestion.Name, basicSuggestion.Artist)
	if basicSuggestion.Album != "" {
		searchQuery += fmt.Sprintf(" album:\"%s\"", basicSuggestion.Album)
	}
	log.Printf("Searching Spotify with query: %s (Limit: %d)", searchQuery, searchLimit)
	searchCtx, searchCancel := context.WithTimeout(context.Background(), 10*time.Second)
	searchResults, err = app.SearchTracks(searchCtx, searchQuery, searchLimit)
	searchCancel()

	// Fallback search (without album) if needed
	if err != nil || len(searchResults) == 0 {
		if err != nil {
			log.Printf("WARN: Spotify search (with album) failed for query '%s': %v. Trying without album...", searchQuery, err)
		} else {
			log.Printf("WARN: Spotify search (with album) returned no results for query '%s'. Trying without album...", searchQuery)
		}
		searchQueryMinimal := fmt.Sprintf("track:\"%s\" artist:\"%s\"", basicSuggestion.Name, basicSuggestion.Artist)
		log.Printf("Searching Spotify with query: %s (Limit: %d)", searchQueryMinimal, searchLimit)
		searchCtx2, searchCancel2 := context.WithTimeout(context.Background(), 10*time.Second)
		searchResults, err = app.SearchTracks(searchCtx2, searchQueryMinimal, searchLimit)
		searchCancel2()
		if err != nil {
			log.Printf("ERROR: Spotify search (without album) also failed for query '%s': %v", searchQueryMinimal, err)
			return nil, errors.Wrapf(err, "Spotify search failed for suggestion '%s' by '%s'", basicSuggestion.Name, basicSuggestion.Artist)
		}
		if len(searchResults) == 0 {
			log.Printf("ERROR: Spotify search (without album) also returned no results for query '%s'", searchQueryMinimal)
			return nil, errors.Errorf("Could not find '%s' by '%s' on Spotify", basicSuggestion.Name, basicSuggestion.Artist)
		}
	}

	// --- Select the best match from results ---
	var selectedTrack *SimpleTrack = nil
	if basicSuggestion.ID != "" {
		log.Printf("Attempting to match provided ID '%s' within %d search results...", basicSuggestion.ID, len(searchResults))
		for _, track := range searchResults {
			if track.ID == basicSuggestion.ID {
				log.Printf("Found match for ID %s in search results!", basicSuggestion.ID)
				selectedTrack = track
				break
			}
		}
		if selectedTrack == nil {
			log.Printf("Provided ID '%s' not found in search results. Defaulting to top result.", basicSuggestion.ID)
		}
	}
	if selectedTrack == nil {
		selectedTrack = searchResults[0]
		log.Printf("Using top search result (ID: %s) as no matching ID was provided or found.", selectedTrack.ID)
	}

	log.Printf("Selected track - ID: %s, Name: %s, Artist: %s", selectedTrack.ID, selectedTrack.Name, selectedTrack.Artist)

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

// ProvideSuggestionFeedback sends user feedback to OpenAI.
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

	app.mu.Lock()
	app.chatHistory = append(app.chatHistory, openai.Message{Role: "user", Content: feedback})
	app.mu.Unlock()

	log.Printf("Feedback received: %s (Added to history)", feedback)
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
