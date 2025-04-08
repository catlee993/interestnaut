package spotify

import (
	"context"
	"sync"

	"github.com/pkg/errors"
)

// App represents the Spotify application.
type App struct {
	client     Client
	authConfig *AuthConfig
	mu         sync.RWMutex
}

// AuthConfig represents the Spotify OAuth configuration.
type AuthConfig struct {
	ClientID     string
	ClientSecret string
	RedirectURI  string
}

// NewApp creates a new Spotify application.
func NewApp(authConfig *AuthConfig) *App {
	return &App{
		authConfig: authConfig,
		client:     NewClient(),
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

// GetCurrentUser retrieves the current user's profile.
func (a *App) GetCurrentUser(ctx context.Context) (*UserProfile, error) {
	if a.client == nil {
		return nil, errors.New("not authenticated")
	}
	return a.client.GetCurrentUser(ctx)
}
