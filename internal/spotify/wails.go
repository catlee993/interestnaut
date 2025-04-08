package spotify

import (
	"context"
	"sync"
	"time"
)

// WailsClient represents a Spotify client for Wails.
type WailsClient struct {
	client Client
	mu     sync.RWMutex
}

// NewWailsClient creates a new Spotify client for Wails.
func NewWailsClient() *WailsClient {
	return &WailsClient{
		client: NewClient(),
	}
}

// SetSpotifyClient sets the Spotify client.
func (w *WailsClient) SetSpotifyClient(client Client) {
	w.mu.Lock()
	defer w.mu.Unlock()
	w.client = client
}

// GetSavedTracks retrieves the user's saved tracks.
func (w *WailsClient) GetSavedTracks(limit, offset int) (*SavedTracks, error) {
	w.mu.RLock()
	client := w.client
	w.mu.RUnlock()

	if client == nil {
		return nil, ErrNotAuthenticated
	}

	// Create a context with a timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	return client.GetSavedTracks(ctx, limit, offset)
}

// SearchTracks searches for tracks matching the query.
func (w *WailsClient) SearchTracks(query string, limit int) ([]*SimpleTrack, error) {
	w.mu.RLock()
	client := w.client
	w.mu.RUnlock()

	if client == nil {
		return nil, ErrNotAuthenticated
	}

	// Create a context with a timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	return client.SearchTracks(ctx, query, limit)
}

// SaveTrack saves a track to the user's library.
func (w *WailsClient) SaveTrack(trackID string) error {
	w.mu.RLock()
	client := w.client
	w.mu.RUnlock()

	if client == nil {
		return ErrNotAuthenticated
	}

	// Create a context with a timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	return client.SaveTrack(ctx, trackID)
}

// RemoveTrack removes a track from the user's library.
func (w *WailsClient) RemoveTrack(trackID string) error {
	w.mu.RLock()
	client := w.client
	w.mu.RUnlock()

	if client == nil {
		return ErrNotAuthenticated
	}

	// Create a context with a timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	return client.RemoveTrack(ctx, trackID)
}

// GetCurrentUser retrieves the current user's profile.
func (w *WailsClient) GetCurrentUser() (*UserProfile, error) {
	w.mu.RLock()
	client := w.client
	w.mu.RUnlock()

	if client == nil {
		return nil, ErrNotAuthenticated
	}

	// Create a context with a timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	return client.GetCurrentUser(ctx)
}
