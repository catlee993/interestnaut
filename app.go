package main

import (
	"context"
	"errors"
	"interestnaut/internal/spotify"
	"sync"
)

// App represents the Spotify application.
type App struct {
	ctx        context.Context
	client     spotify.Client
	authConfig *spotify.AuthConfig
	mu         sync.RWMutex
}

// NewApp creates a new Spotify application.
func NewApp(authConfig *spotify.AuthConfig) *App {
	return &App{
		authConfig: authConfig,
		client:     spotify.NewClient(),
	}
}

// startup is called when the app starts. The context is saved
// so we can call the runtime methods
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
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
func (a *App) GetSavedTracks(limit, offset int) (*spotify.SavedTracks, error) {
	if a.client == nil {
		return nil, errors.New("not authenticated")
	}
	return a.client.GetSavedTracks(a.ctx, limit, offset)
}

// SearchTracks searches for tracks matching the query.
func (a *App) SearchTracks(query string, limit int) ([]*spotify.SimpleTrack, error) {
	if a.client == nil {
		return nil, errors.New("not authenticated")
	}
	return a.client.SearchTracks(a.ctx, query, limit)
}

// SaveTrack saves a track to the user's library.
func (a *App) SaveTrack(trackID string) error {
	if a.client == nil {
		return errors.New("not authenticated")
	}
	return a.client.SaveTrack(a.ctx, trackID)
}

// RemoveTrack removes a track from the user's library.
func (a *App) RemoveTrack(trackID string) error {
	if a.client == nil {
		return errors.New("not authenticated")
	}
	return a.client.RemoveTrack(a.ctx, trackID)
}

// GetCurrentUser retrieves the current user's profile.
func (a *App) GetCurrentUser() (*spotify.UserProfile, error) {
	if a.client == nil {
		return nil, errors.New("not authenticated")
	}
	return a.client.GetCurrentUser(a.ctx)
}
