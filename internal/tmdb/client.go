package tmdb

import (
	"context"
	"fmt"
	"os"

	request "github.com/catlee993/go-request"
)

const (
	baseURL          = "https://api.themoviedb.org/3"
	imageBaseURL     = "https://image.tmdb.org/t/p"
	posterSizeW500   = "w500"
	backdropSizeW780 = "w780"
)

type Client struct {
	apiKey string
}

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

func NewClient() *Client {
	return &Client{
		apiKey: os.Getenv("TMDB_API_KEY"),
	}
}

func (c *Client) SearchMovies(ctx context.Context, query string) (*SearchResponse, error) {
	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Get),
		request.WithHost("api.themoviedb.org"),
		request.WithPath("3", "search", "movie"),
		request.WithQueryArgs(map[string][]string{
			"api_key":       {c.apiKey},
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
	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Get),
		request.WithHost("api.themoviedb.org"),
		request.WithPath("3", "movie", fmt.Sprintf("%d", movieID)),
		request.WithQueryArgs(map[string][]string{
			"api_key": {c.apiKey},
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
