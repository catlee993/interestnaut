package spotify

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/pkg/errors"

	"interestnaut/internal/creds"

	request "github.com/catlee993/go-request"
)

// Client interface for Spotify API
type Client interface {
	GetCurrentUser(ctx context.Context) (*UserProfile, error)
	GetSavedTracks(ctx context.Context, limit, offset int) (*SavedTracks, error)
	SearchTracks(ctx context.Context, query string, limit int) ([]*SimpleTrack, error)
	SaveTrack(ctx context.Context, trackID string) error
	RemoveTrack(ctx context.Context, trackID string) error
	GetTrackDetails(ctx context.Context, trackID string, market string) (*Track, error)
	PlayTrackOnDevice(ctx context.Context, deviceID string, trackURI string) error
	PausePlaybackOnDevice(ctx context.Context, deviceID string) error
	GetAllLikedTracks(ctx context.Context) ([]SavedTrackItem, error)
}

// client represents a Spotify API client.
type client struct {
	cli        *http.Client
	authConfig *AuthConfig
}

const authRedirectURI = "http://localhost:8080/callback"
const spotifyClientID = "3bb48a30577342869a9ffcb176dee7d2"

// NewClient creates a new Spotify API client with default settings.
// Primarily used before auth config is fully available.
func NewClient() Client {
	authConfig := &AuthConfig{
		ClientID:    spotifyClientID,
		RedirectURI: authRedirectURI,
	}
	return &client{
		cli:        http.DefaultClient,
		authConfig: authConfig,
	}
}

// GetSavedTracks retrieves the user's saved tracks.
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

// SearchTracks searches for tracks matching the query.
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

// SaveTrack saves a track to the user's library.
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

// RemoveTrack removes a track from the user's library.
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

// GetCurrentUser retrieves the current user's profile.
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

// GetTrackDetails retrieves detailed information using go-request.
func (c *client) GetTrackDetails(ctx context.Context, trackID string, market string) (*Track, error) {
	token, err := GetValidToken(ctx)
	if err != nil {
		log.Printf("ERROR: GetValidToken failed in GetTrackDetails: %v", err)
		return nil, err
	}

	queryArgs := map[string][]string{}
	if market != "" {
		queryArgs["market"] = []string{market}
	}

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Get),
		request.WithHost("api.spotify.com"),
		request.WithPath("v1", "tracks", trackID),
		request.WithQueryArgs(queryArgs),
		request.WithHeaders(map[string][]string{
			"Authorization": {"Bearer " + token},
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create track details requester: %w", err)
	}

	var track Track
	_, rErr := req.Make(ctx, &track)
	if rErr != nil {
		log.Printf("ERROR: GetTrackDetails (go-request) request failed for track %s. Error: %v", trackID, rErr)
		return nil, fmt.Errorf("track details request failed: %w", rErr)
	}

	return &track, nil
}

// PlayTrackOnDevice Methods Implementation
func (c *client) PlayTrackOnDevice(ctx context.Context, deviceID string, trackURI string) error {
	token, err := GetValidToken(ctx)
	if err != nil {
		return err
	}

	body := map[string]interface{}{
		"uris": []string{trackURI},
	}
	bodyBytes, err := json.Marshal(body)
	if err != nil {
		return fmt.Errorf("failed to marshal play request body: %w", err)
	}

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Put),
		request.WithHost("api.spotify.com"),
		request.WithPath("v1", "me", "player", "play"),
		request.WithQueryArgs(map[string][]string{
			"device_id": {deviceID},
		}),
		request.WithBody(bodyBytes),
		request.WithHeaders(map[string][]string{
			"Authorization": {"Bearer " + token},
			"Content-Type":  {"application/json"},
		}),
	)
	if err != nil {
		return fmt.Errorf("failed to create play request: %w", err)
	}

	resp, err := req.Make(ctx, nil)
	if err != nil {
		// Check if the error is due to an expired token
		if strings.Contains(err.Error(), "401") {
			// Clear the current token to force a refresh
			tokenMutex.Lock()
			accessToken = ""
			tokenExpiry = time.Time{}
			tokenMutex.Unlock()

			// Get a fresh token
			newToken, tokenErr := GetValidToken(ctx)
			if tokenErr != nil {
				return fmt.Errorf("failed to refresh token: %w", tokenErr)
			}

			// Retry the request with the new token
			req, err = request.NewRequester(
				request.WithScheme(request.HTTPS),
				request.WithMethod(request.Put),
				request.WithHost("api.spotify.com"),
				request.WithPath("v1", "me", "player", "play"),
				request.WithQueryArgs(map[string][]string{
					"device_id": {deviceID},
				}),
				request.WithBody(bodyBytes),
				request.WithHeaders(map[string][]string{
					"Authorization": {"Bearer " + newToken},
					"Content-Type":  {"application/json"},
				}),
			)
			if err != nil {
				return fmt.Errorf("failed to create retry play request: %w", err)
			}

			resp, err = req.Make(ctx, nil)
			if err != nil {
				return fmt.Errorf("retry play request failed: %w", err)
			}
		} else {
			log.Printf("ERROR: Play request req.Make failed: %v", err)
			return fmt.Errorf("play request failed during Make: %w", err)
		}
	}
	defer func() {
		_ = resp.Body.Close()
	}()

	if resp.StatusCode != http.StatusNoContent {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("ERROR: Play request returned unexpected status %d. Body: %s", resp.StatusCode, string(bodyBytes))
		return fmt.Errorf("play request failed with status %d", resp.StatusCode)
	}

	return nil
}

func (c *client) PausePlaybackOnDevice(ctx context.Context, deviceID string) error {
	token, err := GetValidToken(ctx)
	if err != nil {
		return err
	}

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Put),
		request.WithHost("api.spotify.com"),
		request.WithPath("v1", "me", "player", "pause"),
		request.WithQueryArgs(map[string][]string{
			"device_id": {deviceID},
		}),
		request.WithHeaders(map[string][]string{
			"Authorization": {"Bearer " + token},
		}),
	)
	if err != nil {
		return fmt.Errorf("failed to create pause request: %w", err)
	}

	resp, err := req.Make(ctx, nil)
	if err != nil {
		log.Printf("ERROR: Pause request req.Make failed: %v", err)
		return fmt.Errorf("pause request failed during Make: %w", err)
	}
	defer func() {
		_ = resp.Body.Close()
	}()

	if resp.StatusCode != http.StatusNoContent && resp.StatusCode != http.StatusOK {
		bodyBytes, _ := io.ReadAll(resp.Body)
		log.Printf("ERROR: Pause request returned unexpected status %d. Body: %s", resp.StatusCode, string(bodyBytes))
		return fmt.Errorf("pause request failed with status %d", resp.StatusCode)
	}

	return nil
}

func (c *client) GetAllLikedTracks(ctx context.Context) ([]SavedTrackItem, error) {
	var allTracks []SavedTrackItem
	limit := 50 // Max allowed by Spotify API
	offset := 0

	for {
		pageCtx, cancel := context.WithTimeout(ctx, 15*time.Second)
		page, err := c.GetSavedTracks(pageCtx, limit, offset)
		cancel() // Release context resources promptly

		if err != nil {
			// Consider retries for transient errors?
			return nil, errors.Wrapf(err, "failed to get saved tracks page (offset %d)", offset)
		}

		if page == nil || len(page.Items) == 0 {
			break // No more tracks
		}

		allTracks = append(allTracks, page.Items...)

		if len(allTracks) >= page.Total {
			break // We have fetched all expected tracks
		}

		offset += limit

		// small delay to avoid hitting rate limits aggressively
		time.Sleep(100 * time.Millisecond)
	}

	log.Printf("Fetched %d total saved tracks.", len(allTracks))
	return allTracks, nil
}

// SaveOpenAICreds saves the OpenAI API key to the OS keychain.
func SaveOpenAICreds(ctx context.Context, apiKey string) error {
	if err := creds.SaveOpenAIKey(apiKey); err != nil {
		return fmt.Errorf("failed to save OpenAI API key: %w", err)
	}
	return nil
}

// GetOpenAICreds retrieves the OpenAI API key from the OS keychain.
func GetOpenAICreds(ctx context.Context) (string, error) {
	apiKey, err := creds.GetOpenAIKey()
	if err != nil {
		return "", fmt.Errorf("failed to get OpenAI API key: %w", err)
	}
	return apiKey, nil
}

// ClearOpenAICreds removes the OpenAI API key from the OS keychain.
func ClearOpenAICreds(ctx context.Context) error {
	if err := creds.ClearOpenAIKey(); err != nil {
		return fmt.Errorf("failed to clear OpenAI API key: %w", err)
	}
	return nil
}
