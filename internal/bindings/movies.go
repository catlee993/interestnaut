package bindings

import (
	"context"
	"fmt"
	"interestnaut/internal/directives"
	"interestnaut/internal/llm"
	"interestnaut/internal/openai"
	"interestnaut/internal/session"
	"interestnaut/internal/tmdb"
	"log"
)

// Movie represents a movie with its metadata for the initial list
type Movie struct {
	Title      string `json:"title"`
	Director   string `json:"director"`
	Writer     string `json:"writer"`
	IMDBRating string `json:"imdb_rating"`
}

// MovieWithSavedStatus represents a movie with its saved status
type MovieWithSavedStatus struct {
	ID          int      `json:"id"`
	Title       string   `json:"title"`
	Overview    string   `json:"overview"`
	PosterPath  string   `json:"poster_path"`
	ReleaseDate string   `json:"release_date"`
	VoteAverage float64  `json:"vote_average"`
	VoteCount   int      `json:"vote_count"`
	Genres      []string `json:"genres"`
	IsSaved     bool     `json:"isSaved"`
}

type Movies struct {
	tmdbClient             *tmdb.Client
	llmClient              llm.Client[session.Movie]
	manager                session.Manager[session.Movie]
	baselineFunc, taskFunc func() string
	initialList            map[string]Movie
}

func NewMovieBinder(ctx context.Context, cm session.CentralManager) (*Movies, error) {
	client := tmdb.NewClient()
	llmClient, err := openai.NewClient[session.Movie]()
	if err != nil {
		log.Printf("ERROR: Failed to create OpenAI client: %v", err)
		return nil, err
	}

	m := &Movies{
		tmdbClient:  client,
		llmClient:   llmClient,
		manager:     cm.Movie(),
		initialList: make(map[string]Movie),
	}

	m.baselineFunc = func() string {
		// Convert Movie to session.Movie
		sessionMovies := make(map[string]session.Movie)
		for title, movie := range m.initialList {
			sessionMovies[title] = session.Movie{
				Director:   movie.Director,
				Writer:     movie.Writer,
				IMDBRating: movie.IMDBRating,
			}
		}
		return directives.GetMovieBaseline(ctx, sessionMovies)
	}
	m.taskFunc = func() string {
		return directives.MovieDirective
	}

	return m, nil
}

// SetInitialMovies allows the user to set their initial list of favorite movies
// This should be called before starting recommendations
func (m *Movies) SetInitialMovies(movies map[string]Movie) error {
	if len(movies) == 0 {
		return fmt.Errorf("initial movie list cannot be empty")
	}
	m.initialList = movies

	// Create a new session with the initial list
	_ = m.manager.GetOrCreateSession(context.Background(), m.manager.Key(), m.taskFunc, m.baselineFunc)
	log.Printf("Created new session with %d initial movies", len(movies))

	return nil
}

// GetInitialMovies returns the current list of initial movies
func (m *Movies) GetInitialMovies() map[string]Movie {
	return m.initialList
}

// SearchMovies searches for movies in TMDB
func (m *Movies) SearchMovies(query string) ([]*MovieWithSavedStatus, error) {
	resp, err := m.tmdbClient.SearchMovies(context.Background(), query)
	if err != nil {
		return nil, fmt.Errorf("failed to search movies: %w", err)
	}

	// Convert response to array of movies and enrich with saved status
	movies := make([]*MovieWithSavedStatus, len(resp.Results))
	for i, result := range resp.Results {
		genreNames := make([]string, len(result.Genres))
		for j, g := range result.Genres {
			genreNames[j] = g.Name
		}

		movies[i] = &MovieWithSavedStatus{
			ID:          result.ID,
			Title:       result.Title,
			Overview:    result.Overview,
			PosterPath:  result.PosterPath,
			ReleaseDate: result.ReleaseDate,
			VoteAverage: result.VoteAverage,
			VoteCount:   result.VoteCount,
			Genres:      genreNames,
			IsSaved:     false, // TODO: Implement saved status
		}
	}

	return movies, nil
}

// GetMovieDetails gets detailed information about a specific movie
func (m *Movies) GetMovieDetails(movieID int) (*MovieWithSavedStatus, error) {
	movie, err := m.tmdbClient.GetMovieDetails(context.Background(), movieID)
	if err != nil {
		return nil, fmt.Errorf("failed to get movie details: %w", err)
	}

	genreNames := make([]string, len(movie.Genres))
	for i, g := range movie.Genres {
		genreNames[i] = g.Name
	}

	return &MovieWithSavedStatus{
		ID:          movie.ID,
		Title:       movie.Title,
		Overview:    movie.Overview,
		PosterPath:  movie.PosterPath,
		ReleaseDate: movie.ReleaseDate,
		VoteAverage: movie.VoteAverage,
		VoteCount:   movie.VoteCount,
		Genres:      genreNames,
		IsSaved:     false, // TODO: Implement saved status
	}, nil
}
