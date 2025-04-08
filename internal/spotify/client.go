package spotify

import (
	"context"
	"fmt"
	"net/http"

	request "github.com/catlee993/go-request"
)

// Client interface for Spotify API
type Client interface {
	GetCurrentUser(ctx context.Context) (*UserProfile, error)
	GetSavedTracks(ctx context.Context, limit, offset int) (*SavedTracks, error)
	SearchTracks(ctx context.Context, query string, limit int) ([]*SimpleTrack, error)
	SaveTrack(ctx context.Context, trackID string) error
	RemoveTrack(ctx context.Context, trackID string) error
}

// client represents a Spotify API client.
type client struct {
	cli        *http.Client
	authConfig *AuthConfig
}

// NewClient creates a new Spotify API client with default settings.
// Primarily used before auth config is fully available.
func NewClient() Client {
	return &client{
		cli: http.DefaultClient,
	}
}

// NewClientWithAuth creates a new Spotify API client using the provided auth config.
func NewClientWithAuth(authConfig *AuthConfig) Client {
	return &client{
		cli:        http.DefaultClient,
		authConfig: authConfig,
	}
}

func (c *client) GetSavedTracks(ctx context.Context, limit, offset int) (*SavedTracks, error) {
	token, err := GetValidToken(ctx)
	if err != nil {
		return nil, err
	}

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Get),
		request.WithHost("api.spotify.com"),
		request.WithPath("v1", "me", "tracks"),
		request.WithQueryArgs(map[string][]string{
			"limit":  {fmt.Sprintf("%d", limit)},
			"offset": {fmt.Sprintf("%d", offset)},
		}),
		request.WithHeaders(map[string][]string{
			"Authorization": {"Bearer " + token},
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create requester: %w", err)
	}

	var tracks SavedTracks
	_, rErr := req.Make(ctx, &tracks)
	if rErr != nil {
		return nil, fmt.Errorf("request failed: %w", rErr)
	}

	return &tracks, nil
}

func (c *client) SearchTracks(ctx context.Context, query string, limit int) ([]*SimpleTrack, error) {
	token, err := GetValidToken(ctx)
	if err != nil {
		return nil, err
	}

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Get),
		request.WithHost("api.spotify.com"),
		request.WithPath("v1", "search"),
		request.WithQueryArgs(map[string][]string{
			"q":     {query},
			"type":  {"track"},
			"limit": {fmt.Sprintf("%d", limit)},
		}),
		request.WithHeaders(map[string][]string{
			"Authorization": {"Bearer " + token},
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create requester: %w", err)
	}

	var results SearchResults
	_, rErr := req.Make(ctx, &results)
	if rErr != nil {
		return nil, fmt.Errorf("request failed: %w", rErr)
	}

	// Convert to SimpleTrack array
	simpleTracks := make([]*SimpleTrack, 0, len(results.Tracks.Items))
	for _, track := range results.Tracks.Items {
		simpleTrack := &SimpleTrack{
			ID:         track.ID,
			Name:       track.Name,
			PreviewUrl: track.PreviewUrl,
			URI:        track.URI,
		}
		if len(track.Artists) > 0 {
			simpleTrack.Artist = track.Artists[0].Name
			simpleTrack.ArtistID = track.Artists[0].ID
		}
		if len(track.Album.Images) > 0 {
			simpleTrack.AlbumArtUrl = track.Album.Images[0].URL
		}
		simpleTrack.Album = track.Album.Name
		simpleTrack.AlbumID = track.Album.ID

		simpleTracks = append(simpleTracks, simpleTrack)
	}

	return simpleTracks, nil
}

func (c *client) SaveTrack(ctx context.Context, trackID string) error {
	token, err := GetValidToken(ctx)
	if err != nil {
		return err
	}

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Put),
		request.WithHost("api.spotify.com"),
		request.WithPath("v1", "me", "tracks"),
		request.WithQueryArgs(map[string][]string{
			"ids": {trackID},
		}),
		request.WithHeaders(map[string][]string{
			"Authorization": {"Bearer " + token},
		}),
	)
	if err != nil {
		return fmt.Errorf("failed to create requester: %w", err)
	}

	if _, err := req.Make(ctx, nil); err != nil {
		return fmt.Errorf("failed to save track: %w", err)
	}

	return nil
}

func (c *client) RemoveTrack(ctx context.Context, trackID string) error {
	token, err := GetValidToken(ctx)
	if err != nil {
		return err
	}

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Delete),
		request.WithHost("api.spotify.com"),
		request.WithPath("v1", "me", "tracks"),
		request.WithQueryArgs(map[string][]string{
			"ids": {trackID},
		}),
		request.WithHeaders(map[string][]string{
			"Authorization": {"Bearer " + token},
		}),
	)
	if err != nil {
		return fmt.Errorf("failed to create requester: %w", err)
	}

	if _, err := req.Make(ctx, nil); err != nil {
		return fmt.Errorf("failed to remove track: %w", err)
	}

	return nil
}

func (c *client) GetCurrentUser(ctx context.Context) (*UserProfile, error) {
	token, err := GetValidToken(ctx)
	if err != nil {
		return nil, err
	}

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Get),
		request.WithHost("api.spotify.com"),
		request.WithPath("v1", "me"),
		request.WithHeaders(map[string][]string{
			"Authorization": {"Bearer " + token},
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create requester: %w", err)
	}

	var profile UserProfile
	_, rErr := req.Make(ctx, &profile)
	if rErr != nil {
		return nil, fmt.Errorf("request failed: %w", rErr)
	}

	return &profile, nil
}
