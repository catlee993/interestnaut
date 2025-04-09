package main

import (
	"context"
	"errors"
	"interestnaut/internal/openai"
	"interestnaut/internal/spotify"
	"log"
	"os"
	"sync"
)

// App represents the Spotify application.
type App struct {
	ctx           context.Context
	spotifyClient *spotify.WailsClient
	openaiClient  *openai.WailsClient
	userID        string
	preferences   string
	mu            sync.RWMutex
}

// NewApp creates a new Spotify application.
func NewApp() *App {
	return &App{}
}

// startup is called when the app starts. The context is saved
// so we can call the runtime methods
func (a *App) startup(ctx context.Context) {
	// Set up logging to file
	logFile, err := os.OpenFile("/tmp/interestnaut.log", os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		log.Printf("Failed to open log file: %v", err)
	} else {
		log.SetOutput(logFile)
	}
	log.Println("Starting application...")

	a.ctx = ctx

	// Initialize Spotify client
	spotifyClient := spotify.NewWailsClient()
	a.spotifyClient = spotifyClient

	// Initialize OpenAI client
	openaiClient, err := openai.NewWailsClient()
	if err != nil {
		log.Printf("Failed to initialize OpenAI client: %v", err)
		return
	}
	a.openaiClient = openaiClient

	// Get current user
	user, err := a.spotifyClient.GetCurrentUser()
	if err != nil {
		log.Printf("Failed to get current user: %v", err)
		return
	}

	a.userID = user.ID
	log.Printf("Got Spotify user ID: %s", a.userID)

	// Set the user ID in the OpenAI client
	a.openaiClient.SetUserID(a.userID)
	log.Printf("Set user ID in OpenAI WailsClient: %s", a.userID)

	// Also set the user ID in the underlying Client
	if client, ok := a.openaiClient.GetClient(); ok {
		client.SetUserID(a.userID)
		log.Printf("Set user ID in OpenAI Client: %s", a.userID)
	} else {
		log.Printf("Warning: Could not access underlying OpenAI Client")
	}

	// Only analyze preferences if we haven't done it before
	if !a.openaiClient.HasAnalyzedLibrary(a.userID) {
		log.Println("First time startup: analyzing music preferences...")
		a.analyzePreferences()
	} else {
		log.Println("Library already analyzed, skipping initial analysis")
	}
}

// analyzePreferences analyzes the user's saved tracks to understand their music preferences
func (a *App) analyzePreferences() {
	// Get saved tracks
	tracks, err := a.spotifyClient.GetSavedTracks(50, 0)
	if err != nil {
		log.Printf("Failed to get saved tracks: %v", err)
		return
	}

	// Convert tracks to a format suitable for analysis
	var trackData []map[string]interface{}
	for _, item := range tracks.Items {
		track := item.Track
		trackData = append(trackData, map[string]interface{}{
			"name":   track.Name,
			"artist": track.Artists[0].Name,
			"album":  track.Album.Name,
		})
	}

	// Analyze preferences using OpenAI
	preferences, err := a.openaiClient.AnalyzeMusicPreferences(a.ctx, a.userID, trackData)
	if err != nil {
		log.Printf("Failed to analyze preferences: %v", err)
		return
	}

	a.preferences = preferences
	log.Printf("Music preferences analyzed: %s", preferences)
}

// GetMusicPreferences returns the analyzed music preferences
func (a *App) GetMusicPreferences() string {
	return a.preferences
}

// GetSongSuggestion gets a song suggestion from OpenAI based on the user's preferences
func (a *App) GetSongSuggestion() (string, error) {
	suggestion, err := a.openaiClient.GetSongSuggestion(a.ctx, a.userID)
	if err != nil {
		return "", err
	}

	return suggestion, nil
}

// SearchAndPlaySuggestion searches for a suggested song on Spotify and returns track data
func (a *App) SearchAndPlaySuggestion(suggestion string) ([]*spotify.SimpleTrack, error) {
	// Search for the song on Spotify
	tracks, err := a.spotifyClient.SearchTracks(suggestion, 5)
	if err != nil {
		return nil, err
	}

	return tracks, nil
}

// ProvideFeedback provides feedback about a suggested song
func (a *App) ProvideFeedback(songName string, liked bool) error {
	return a.openaiClient.ProvideFeedback(a.ctx, a.userID, songName, liked)
}

// GetAuthStatus returns the current authentication status
func (a *App) GetAuthStatus() map[string]interface{} {
	a.mu.RLock()
	defer a.mu.RUnlock()

	isAuthenticated := a.spotifyClient != nil

	return map[string]interface{}{
		"isAuthenticated": isAuthenticated,
	}
}

// GetSavedTracks retrieves the user's saved tracks.
func (a *App) GetSavedTracks(limit, offset int) (*spotify.SavedTracks, error) {
	if a.spotifyClient == nil {
		return nil, errors.New("not authenticated")
	}
	return a.spotifyClient.GetSavedTracks(limit, offset)
}

// SearchTracks searches for tracks matching the query.
func (a *App) SearchTracks(query string, limit int) ([]*spotify.SimpleTrack, error) {
	if a.spotifyClient == nil {
		return nil, errors.New("not authenticated")
	}
	return a.spotifyClient.SearchTracks(query, limit)
}

// SaveTrack saves a track to the user's library.
func (a *App) SaveTrack(trackID string) error {
	if a.spotifyClient == nil {
		return errors.New("not authenticated")
	}
	return a.spotifyClient.SaveTrack(trackID)
}

// RemoveTrack removes a track from the user's library.
func (a *App) RemoveTrack(trackID string) error {
	if a.spotifyClient == nil {
		return errors.New("not authenticated")
	}
	return a.spotifyClient.RemoveTrack(trackID)
}

// GetCurrentUser retrieves the current user's profile.
func (a *App) GetCurrentUser() (*spotify.UserProfile, error) {
	if a.spotifyClient == nil {
		return nil, errors.New("not authenticated")
	}
	return a.spotifyClient.GetCurrentUser()
}
