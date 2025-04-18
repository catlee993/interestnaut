package tmdb

import (
	"context"
	"errors"
	"fmt"
	"interestnaut/internal/creds"
	"sync"

	request "github.com/catlee993/go-request"
)

const (
	baseURL          = "https://api.themoviedb.org/3"
	imageBaseURL     = "https://image.tmdb.org/t/p"
	posterSizeW500   = "w500"
	backdropSizeW780 = "w780"
)

// ErrNoCredentials is returned when TMDB credentials are not available
var ErrNoCredentials = errors.New("TMDB credentials not available")

type Client struct {
	apiKey string
	mu     sync.RWMutex
}

// Movie struct representing a movie from TMDB API
type Movie struct {
	ID          int     `json:"id"`
	Title       string  `json:"title"`
	Overview    string  `json:"overview"`
	PosterPath  string  `json:"poster_path"`
	ReleaseDate string  `json:"release_date"`
	VoteAverage float64 `json:"vote_average"`
	VoteCount   int     `json:"vote_count"`
	Genres      []Genre `json:"genres"`
}

type Genre struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

type SearchResponse struct {
	Page         int     `json:"page"`
	TotalResults int     `json:"total_results"`
	TotalPages   int     `json:"total_pages"`
	Results      []Movie `json:"results"`
}

// TVShow struct representing a TV show from TMDB API
type TVShow struct {
	ID           int     `json:"id"`
	Name         string  `json:"name"`
	Overview     string  `json:"overview"`
	PosterPath   string  `json:"poster_path"`
	FirstAirDate string  `json:"first_air_date"`
	VoteAverage  float64 `json:"vote_average"`
	VoteCount    int     `json:"vote_count"`
	Genres       []Genre `json:"genres"`
	CreatedBy    []struct {
		ID   int    `json:"id"`
		Name string `json:"name"`
	} `json:"created_by"`
}

type TVSearchResponse struct {
	Page         int      `json:"page"`
	TotalResults int      `json:"total_results"`
	TotalPages   int      `json:"total_pages"`
	Results      []TVShow `json:"results"`
}

// NewClient creates a new TMDB client
func NewClient() *Client {
	c := &Client{}
	// Initialize with current credentials
	c.RefreshCredentials()
	return c
}

// RefreshCredentials updates the client's API key with the latest credentials
func (c *Client) RefreshCredentials() bool {
	c.mu.Lock()
	defer c.mu.Unlock()

	token, err := creds.GetTMDBAccessToken()
	if err != nil || token == "" {
		c.apiKey = ""
		return false
	}

	c.apiKey = token
	return true
}

// HasValidCredentials returns true if the client has valid credentials
func (c *Client) HasValidCredentials() bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.apiKey != ""
}

func (c *Client) SearchMovies(ctx context.Context, query string) (*SearchResponse, error) {
	c.mu.RLock()
	apiKey := c.apiKey
	c.mu.RUnlock()

	if apiKey == "" {
		return nil, ErrNoCredentials
	}

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Get),
		request.WithHost("api.themoviedb.org"),
		request.WithPath("3", "search", "movie"),
		request.WithQueryArgs(map[string][]string{
			"api_key":       {apiKey},
			"query":         {query},
			"include_adult": {"false"},
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	var result SearchResponse
	_, err = req.Make(ctx, &result)
	if err != nil {
		return nil, fmt.Errorf("failed to search movies: %w", err)
	}

	return &result, nil
}

func (c *Client) GetMovieDetails(ctx context.Context, movieID int) (*Movie, error) {
	c.mu.RLock()
	apiKey := c.apiKey
	c.mu.RUnlock()

	if apiKey == "" {
		return nil, ErrNoCredentials
	}

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Get),
		request.WithHost("api.themoviedb.org"),
		request.WithPath("3", "movie", fmt.Sprintf("%d", movieID)),
		request.WithQueryArgs(map[string][]string{
			"api_key": {apiKey},
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	var movie Movie
	_, err = req.Make(ctx, &movie)
	if err != nil {
		return nil, fmt.Errorf("failed to get movie details: %w", err)
	}

	return &movie, nil
}

func GetPosterURL(path string) string {
	if path == "" {
		return ""
	}
	return fmt.Sprintf("%s/%s%s", imageBaseURL, posterSizeW500, path)
}

func GetBackdropURL(path string) string {
	if path == "" {
		return ""
	}
	return fmt.Sprintf("%s/%s%s", imageBaseURL, backdropSizeW780, path)
}

func (c *Client) SearchTVShows(ctx context.Context, query string) (*TVSearchResponse, error) {
	c.mu.RLock()
	apiKey := c.apiKey
	c.mu.RUnlock()

	if apiKey == "" {
		return nil, ErrNoCredentials
	}

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Get),
		request.WithHost("api.themoviedb.org"),
		request.WithPath("3", "search", "tv"),
		request.WithQueryArgs(map[string][]string{
			"api_key":       {apiKey},
			"query":         {query},
			"include_adult": {"false"},
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	var result TVSearchResponse
	_, err = req.Make(ctx, &result)
	if err != nil {
		return nil, fmt.Errorf("failed to search TV shows: %w", err)
	}

	return &result, nil
}

func (c *Client) GetTVShowDetails(ctx context.Context, showID int) (*TVShow, error) {
	c.mu.RLock()
	apiKey := c.apiKey
	c.mu.RUnlock()

	if apiKey == "" {
		return nil, ErrNoCredentials
	}

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Get),
		request.WithHost("api.themoviedb.org"),
		request.WithPath("3", "tv", fmt.Sprintf("%d", showID)),
		request.WithQueryArgs(map[string][]string{
			"api_key": {apiKey},
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	var tvShow TVShow
	_, err = req.Make(ctx, &tvShow)
	if err != nil {
		return nil, fmt.Errorf("failed to get TV show details: %w", err)
	}

	return &tvShow, nil
}
