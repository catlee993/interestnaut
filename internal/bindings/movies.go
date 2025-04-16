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
	"strings"
	"time"
)

// Movie represents a movie with its metadata for the initial list
type Movie struct {
	Title    string `json:"title"`
	Director string `json:"director"`
	Writer   string `json:"writer"`
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
}

type Movies struct {
	tmdbClient             *tmdb.Client
	llmClient              llm.Client[session.Movie]
	manager                session.Manager[session.Movie]
	baselineFunc, taskFunc func() string
	initialList            map[string]Movie
	lastCredCheck          time.Time
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
				Director: movie.Director,
				Writer:   movie.Writer,
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

// ensureCredentialsChecked checks if credentials need to be refreshed
// We only check at most once every 30 seconds to avoid excessive calls
func (m *Movies) ensureCredentialsChecked() {
	// If we checked recently, don't check again
	if time.Since(m.lastCredCheck) < 30*time.Second {
		return
	}

	// Refresh the credentials
	m.tmdbClient.RefreshCredentials()
	m.lastCredCheck = time.Now()
}

// HasValidCredentials checks if the TMDB client has valid credentials
func (m *Movies) HasValidCredentials() bool {
	m.ensureCredentialsChecked()
	return m.tmdbClient.HasValidCredentials()
}

// RefreshCredentials attempts to refresh the TMDB client's credentials
// Returns true if successful, false otherwise
func (m *Movies) RefreshCredentials() bool {
	success := m.tmdbClient.RefreshCredentials()
	if success {
		m.lastCredCheck = time.Now()
	}
	return success
}

// SearchMovies searches for movies in TMDB
func (m *Movies) SearchMovies(query string) ([]*MovieWithSavedStatus, error) {
	m.ensureCredentialsChecked()

	if !m.tmdbClient.HasValidCredentials() {
		return nil, fmt.Errorf("TMDB credentials not available")
	}

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
		}
	}

	return movies, nil
}

// GetMovieDetails gets detailed information about a specific movie
func (m *Movies) GetMovieDetails(movieID int) (*MovieWithSavedStatus, error) {
	m.ensureCredentialsChecked()

	if !m.tmdbClient.HasValidCredentials() {
		return nil, fmt.Errorf("TMDB credentials not available")
	}

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
	}, nil
}

// GetMovieSuggestion gets a movie suggestion from the LLM
func (m *Movies) GetMovieSuggestion() (map[string]interface{}, error) {
	m.ensureCredentialsChecked()

	if !m.tmdbClient.HasValidCredentials() {
		return nil, fmt.Errorf("TMDB credentials not available")
	}

	// Get or create a session
	sess := m.manager.GetOrCreateSession(context.Background(), m.manager.Key(), m.taskFunc, m.baselineFunc)

	// Compose messages from the session content
	messages, err := m.llmClient.ComposeMessages(context.Background(), &sess.Content)
	if err != nil {
		log.Printf("ERROR: Failed to compose messages for movie suggestion: %v", err)
		return nil, fmt.Errorf("failed to compose messages for movie suggestion: %w", err)
	}

	// Request a suggestion from the LLM
	suggestion, err := m.llmClient.SendMessages(context.Background(), messages...)
	if err != nil {
		log.Printf("ERROR: Failed to get movie suggestion: %v", err)
		return nil, fmt.Errorf("failed to get movie suggestion: %w", err)
	}

	if suggestion == nil {
		return nil, fmt.Errorf("no suggestion available")
	}

	// Try to find more details about the suggested movie from TMDB
	query := suggestion.Title
	resp, err := m.tmdbClient.SearchMovies(context.Background(), query)
	if err != nil {
		log.Printf("WARNING: Failed to search for suggested movie '%s': %v", query, err)
		// Continue anyway, we'll use the basic suggestion data
	}

	var movie *MovieWithSavedStatus
	if err == nil && len(resp.Results) > 0 {
		// Use the first result that matches closely enough
		for _, result := range resp.Results {
			if strings.EqualFold(result.Title, suggestion.Title) {
				genreNames := make([]string, len(result.Genres))
				for j, g := range result.Genres {
					genreNames[j] = g.Name
				}

				movie = &MovieWithSavedStatus{
					ID:          result.ID,
					Title:       result.Title,
					Overview:    result.Overview,
					PosterPath:  result.PosterPath,
					ReleaseDate: result.ReleaseDate,
					VoteAverage: result.VoteAverage,
					VoteCount:   result.VoteCount,
					Genres:      genreNames,
				}
				break
			}
		}

		// If no exact match, use the first result
		if movie == nil && len(resp.Results) > 0 {
			result := resp.Results[0]
			genreNames := make([]string, len(result.Genres))
			for j, g := range result.Genres {
				genreNames[j] = g.Name
			}

			movie = &MovieWithSavedStatus{
				ID:          result.ID,
				Title:       result.Title,
				Overview:    result.Overview,
				PosterPath:  result.PosterPath,
				ReleaseDate: result.ReleaseDate,
				VoteAverage: result.VoteAverage,
				VoteCount:   result.VoteCount,
				Genres:      genreNames,
			}
		}
	}

	// If we didn't find anything in TMDB, create a basic movie object with the suggestion data
	if movie == nil {
		movie = &MovieWithSavedStatus{
			ID:          0, // No TMDB ID
			Title:       suggestion.Title,
			Overview:    fmt.Sprintf("Directed by %s, written by %s. %s", suggestion.Content.Director, suggestion.Content.Writer, suggestion.PrimaryGenre),
			PosterPath:  "", // No poster
			ReleaseDate: "",
			VoteAverage: 0,
			VoteCount:   0,
			Genres:      []string{suggestion.PrimaryGenre},
		}
	}

	// Add the suggestion to the session
	// TODO: We should be using AddSuggestion here, but for now we'll just
	// update the outcome status directly to keep track of pending suggestions.
	key := fmt.Sprintf("%s_%s_%s", movie.Title, suggestion.Content.Director, suggestion.Content.Writer)
	if err := m.manager.UpdateSuggestionOutcome(context.Background(), sess, key, session.Pending); err != nil {
		log.Printf("WARNING: Failed to update suggestion outcome: %v", err)
		// Continue anyway, we don't want to fail the request
	}

	// Return a map that can be easily serialized to JSON
	result := map[string]interface{}{
		"movie":  movie,
		"reason": suggestion.Reason,
	}

	return result, nil
}

// ProvideSuggestionFeedback provides feedback on a suggestion
func (m *Movies) ProvideSuggestionFeedback(outcome session.Outcome, movieID int) error {
	// Get the current session
	sess := m.manager.GetOrCreateSession(context.Background(), m.manager.Key(), m.taskFunc, m.baselineFunc)

	// Get the movie details from TMDB if possible
	var movie *MovieWithSavedStatus
	var err error

	if movieID > 0 && m.tmdbClient.HasValidCredentials() {
		details, err := m.tmdbClient.GetMovieDetails(context.Background(), movieID)
		if err == nil {
			genreNames := make([]string, len(details.Genres))
			for i, g := range details.Genres {
				genreNames[i] = g.Name
			}

			movie = &MovieWithSavedStatus{
				ID:          details.ID,
				Title:       details.Title,
				Overview:    details.Overview,
				PosterPath:  details.PosterPath,
				ReleaseDate: details.ReleaseDate,
				VoteAverage: details.VoteAverage,
				VoteCount:   details.VoteCount,
				Genres:      genreNames,
			}
		}
	}

	// If we couldn't get movie details, create a placeholder
	if movie == nil {
		movie = &MovieWithSavedStatus{
			ID:    movieID,
			Title: fmt.Sprintf("Movie ID %d", movieID),
		}
	}

	// Use the movie title as the key for updating the suggestion outcome
	key := movie.Title

	// Record the outcome
	err = m.manager.UpdateSuggestionOutcome(context.Background(), sess, key, outcome)
	if err != nil {
		return fmt.Errorf("failed to record outcome: %w", err)
	}

	// If the user liked the movie, add it to their library
	if outcome == session.Liked {
		m.initialList[movie.Title] = Movie{
			Title:    movie.Title,
			Director: "",
			Writer:   "",
		}
	}

	return nil
}
