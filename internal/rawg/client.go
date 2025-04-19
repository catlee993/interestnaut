package rawg

import (
	"context"
	"fmt"
	"interestnaut/internal/creds"
	"net/http"
	"sync"
	"time"

	request "github.com/catlee993/go-request"
)

// Constants for the RAWG API
const (
	defaultPageSize = 20
)

var (
	apiKeyMutex  sync.RWMutex
	cachedAPIKey string
)

// ErrNoCredentials is returned when RAWG API key is not available
var ErrNoCredentials = fmt.Errorf("RAWG API key not available")

// Client interface for RAWG API
type Client interface {
	GetGame(ctx context.Context, id int) (*Game, error)
	SearchGames(ctx context.Context, query string, page, pageSize int) (*GameSearchResponse, error)
	GetGames(ctx context.Context, page, pageSize int) (*GameSearchResponse, error)
	GetGameDetails(ctx context.Context, id int) (*Game, error)
	RefreshCredentials() bool
	HasValidCredentials() bool
}

// client implements the Client interface
type client struct {
	httpClient *http.Client
	apiKey     string
	mu         sync.RWMutex
}

// Game represents a game from the RAWG API
type Game struct {
	ID               int          `json:"id"`
	Name             string       `json:"name"`
	Slug             string       `json:"slug"`
	Released         string       `json:"released,omitempty"`
	BackgroundImage  string       `json:"background_image,omitempty"`
	Rating           float64      `json:"rating"`
	RatingsCount     int          `json:"ratings_count"`
	Playtime         int          `json:"playtime"`
	Description      string       `json:"description,omitempty"`
	ShortScreenshots []Screenshot `json:"short_screenshots,omitempty"`
	Platforms        []Platform   `json:"platforms,omitempty"`
	Genres           []Genre      `json:"genres,omitempty"`
	Developers       []Developer  `json:"developers,omitempty"`
	Publishers       []Publisher  `json:"publishers,omitempty"`
}

// Screenshot represents a game screenshot
type Screenshot struct {
	ID    int    `json:"id"`
	Image string `json:"image"`
}

// Platform represents a gaming platform
type Platform struct {
	ID       int             `json:"id,omitempty"`
	Name     string          `json:"name"`
	Slug     string          `json:"slug,omitempty"`
	Platform PlatformDetails `json:"platform,omitempty"`
}

// PlatformDetails contains detailed platform information
type PlatformDetails struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
	Slug string `json:"slug"`
}

// Genre represents a game genre
type Genre struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
	Slug string `json:"slug,omitempty"`
}

// Developer represents a game developer
type Developer struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
	Slug string `json:"slug,omitempty"`
}

// Publisher represents a game publisher
type Publisher struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
	Slug string `json:"slug,omitempty"`
}

// GameSearchResponse represents the response from the RAWG API search endpoint
type GameSearchResponse struct {
	Count    int    `json:"count"`
	Next     string `json:"next"`
	Previous string `json:"previous"`
	Results  []Game `json:"results"`
}

// SimpleGame is a simplified version of Game used for frontend displays
type SimpleGame struct {
	ID              int      `json:"id"`
	Name            string   `json:"name"`
	Released        string   `json:"released,omitempty"`
	BackgroundImage string   `json:"background_image,omitempty"`
	Rating          float64  `json:"rating"`
	RatingsCount    int      `json:"ratings_count"`
	Genres          []string `json:"genres,omitempty"`
}

// NewClient creates a new RAWG API client
func NewClient() Client {
	return &client{
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// getAPIKey gets the RAWG API key from credentials
func getAPIKey() (string, error) {
	apiKeyMutex.RLock()
	if cachedAPIKey != "" {
		key := cachedAPIKey
		apiKeyMutex.RUnlock()
		return key, nil
	}
	apiKeyMutex.RUnlock()

	apiKeyMutex.Lock()
	defer apiKeyMutex.Unlock()

	// Double-check the cached key after acquiring the write lock
	if cachedAPIKey != "" {
		return cachedAPIKey, nil
	}

	key, err := creds.GetRAWGAPIKey()
	if err != nil {
		return "", fmt.Errorf("failed to get RAWG API key: %w", err)
	}

	cachedAPIKey = key
	return key, nil
}

// RefreshCredentials updates the client's API key with the latest credentials
func (c *client) RefreshCredentials() bool {
	apiKeyMutex.Lock()
	defer apiKeyMutex.Unlock()

	cachedAPIKey = "" // Clear the cached key

	key, err := creds.GetRAWGAPIKey()
	if err != nil || key == "" {
		return false
	}

	cachedAPIKey = key
	return true
}

// HasValidCredentials returns true if the client has valid credentials
func (c *client) HasValidCredentials() bool {
	apiKey, err := getAPIKey()
	return err == nil && apiKey != ""
}

// SearchGames searches for games matching the query
func (c *client) SearchGames(ctx context.Context, query string, page, pageSize int) (*GameSearchResponse, error) {
	apiKey, err := getAPIKey()
	if err != nil {
		return nil, ErrNoCredentials
	}

	if pageSize <= 0 {
		pageSize = defaultPageSize
	}

	if page <= 0 {
		page = 1
	}

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Get),
		request.WithHost("api.rawg.io"),
		request.WithPath("api", "games"),
		request.WithQueryArgs(map[string][]string{
			"key":       {apiKey},
			"search":    {query},
			"page":      {fmt.Sprintf("%d", page)},
			"page_size": {fmt.Sprintf("%d", pageSize)},
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	var result GameSearchResponse
	_, err = req.Make(ctx, &result)
	if err != nil {
		return nil, fmt.Errorf("failed to search games: %w", err)
	}

	return &result, nil
}

// GetGames gets a paginated list of games
func (c *client) GetGames(ctx context.Context, page, pageSize int) (*GameSearchResponse, error) {
	apiKey, err := getAPIKey()
	if err != nil {
		return nil, ErrNoCredentials
	}

	if pageSize <= 0 {
		pageSize = defaultPageSize
	}

	if page <= 0 {
		page = 1
	}

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Get),
		request.WithHost("api.rawg.io"),
		request.WithPath("api", "games"),
		request.WithQueryArgs(map[string][]string{
			"key":       {apiKey},
			"page":      {fmt.Sprintf("%d", page)},
			"page_size": {fmt.Sprintf("%d", pageSize)},
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	var result GameSearchResponse
	_, err = req.Make(ctx, &result)
	if err != nil {
		return nil, fmt.Errorf("failed to get games: %w", err)
	}

	return &result, nil
}

// GetGame gets a game by ID
func (c *client) GetGame(ctx context.Context, id int) (*Game, error) {
	return c.GetGameDetails(ctx, id)
}

// GetGameDetails gets detailed information about a game
func (c *client) GetGameDetails(ctx context.Context, id int) (*Game, error) {
	apiKey, err := getAPIKey()
	if err != nil {
		return nil, ErrNoCredentials
	}

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Get),
		request.WithHost("api.rawg.io"),
		request.WithPath("api", "games", fmt.Sprintf("%d", id)),
		request.WithQueryArgs(map[string][]string{
			"key": {apiKey},
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	var game Game
	_, err = req.Make(ctx, &game)
	if err != nil {
		return nil, fmt.Errorf("failed to get game details: %w", err)
	}

	return &game, nil
}
