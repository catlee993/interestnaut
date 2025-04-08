package spotify

import (
	"context"
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

// ProcessLibraryAndGetFirstSuggestion fetches all tracks and gets the first suggestion.
// This could take a while.
func (w *WailsClient) ProcessLibraryAndGetFirstSuggestion() (*openai.Message, error) {
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
	// Fetch all saved tracks (potentially long operation)
	allTracks, err := app.GetAllSavedTracks(context.Background()) // Use appropriate context
	if err != nil {
		return nil, errors.Wrap(err, "failed to fetch all saved tracks")
	}

	// Format tracks into a prompt for OpenAI
	prompt := FormatTracksForInitialPrompt(allTracks)

	// Send to OpenAI
	// Define the system message instructing OpenAI on the desired output format
	systemMessage := openai.Message{
		Role:    "system",
		Content: `You are a helpful music suggestion assistant. Based on the user's saved tracks, suggest a single song they might like. Provide the response ONLY as a valid JSON object with keys "name" (string), "artist" (string), and "id" (string, the Spotify track ID). Example: {"name": "Song Title", "artist": "Artist Name", "id": "track_id"}`,
	}
	userPromptMessage := openai.Message{Role: "user", Content: prompt}

	app.mu.Lock()
	app.chatHistory = []openai.Message{systemMessage, userPromptMessage} // Start history
	historyForAPI := append([]openai.Message{}, app.chatHistory...)      // Copy history for the API call
	app.mu.Unlock()

	log.Println("Sending initial prompt to OpenAI...")
	suggestion, err := app.openaiClient.SendMessage(historyForAPI)
	if err != nil {
		// Clear history if the first call fails?
		app.mu.Lock()
		app.chatHistory = []openai.Message{}
		app.mu.Unlock()
		return nil, errors.Wrap(err, "failed to get first suggestion from OpenAI")
	}
	log.Println("Received suggestion from OpenAI.")

	// TODO: Validate the suggestion format (is it valid JSON with the expected keys?)
	// For now, assume the format is correct.

	// Add AI response to history
	app.mu.Lock()
	app.chatHistory = append(app.chatHistory, suggestion)
	app.mu.Unlock()

	return &suggestion, nil
}

// RequestNewSuggestion asks OpenAI for another suggestion based on history.
func (w *WailsClient) RequestNewSuggestion() (*openai.Message, error) {
	w.mu.RLock()
	app := w.app
	w.mu.RUnlock()

	if app == nil {
		return nil, errors.New("Internal error: App not initialized")
	}
	if app.openaiClient == nil {
		return nil, errors.New("Internal error: OpenAI client not initialized")
	}

	app.mu.Lock()
	// Add user request to history
	app.chatHistory = append(app.chatHistory, openai.Message{Role: "user", Content: "Suggest another song."})
	history := append([]openai.Message{}, app.chatHistory...) // Copy history
	app.mu.Unlock()

	suggestion, err := app.openaiClient.SendMessage(history)
	if err != nil {
		// Revert history change on error?
		app.mu.Lock()
		app.chatHistory = app.chatHistory[:len(app.chatHistory)-1] // Remove user request
		app.mu.Unlock()
		return nil, errors.Wrap(err, "failed to get new suggestion from OpenAI")
	}

	// Add AI response to history
	app.mu.Lock()
	app.chatHistory = append(app.chatHistory, suggestion)
	app.mu.Unlock()

	return &suggestion, nil
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
	// Add user feedback to history
	app.chatHistory = append(app.chatHistory, openai.Message{Role: "user", Content: feedback})
	// history := append([]openai.Message{}, app.chatHistory...) // Removed unused variable copy
	app.mu.Unlock()

	// We might not need an immediate response from OpenAI here, just record the feedback.
	// Or we could ask for confirmation/acknowledgement if desired.
	// _, err := app.openaiClient.SendMessage(history) // Optional: Send to OpenAI
	// if err != nil {
	//  return errors.Wrap(err, "failed to send feedback to OpenAI")
	// }

	log.Printf("Feedback received: %s (Added to history)", feedback)
	return nil
}
