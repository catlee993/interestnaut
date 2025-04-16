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

// Removed local Movie type definition; using session.Movie instead.

// MovieWithSavedStatus represents a movie with its saved status
type MovieWithSavedStatus struct {
	ID          int      `json:"id"`
	Title       string   `json:"title"`
	Overview    string   `json:"overview"`
	Director    string   `json:"director"`
	Writer      string   `json:"writer"`
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
		tmdbClient: client,
		llmClient:  llmClient,
		manager:    cm.Movie(),
	}

	m.taskFunc = func() string {
		return directives.MovieDirective
	}

	m.baselineFunc = func() string {
		sess, err := cm.Movie().GetSession(ctx, m.manager.Key())
		if err != nil {
			log.Printf("ERROR: Failed to get session: %v", err)
			return ""
		}

		return directives.GetMovieBaseline(ctx, sess.Favorites)
	}

	_ = m.manager.GetOrCreateSession(ctx, m.manager.Key(), m.taskFunc, m.baselineFunc) // ensure session is created

	return m, nil
}

// SetFavoriteMovies allows the user to set their initial list of favorite movies
// This should be called before starting recommendations
func (m *Movies) SetFavoriteMovies(movies []session.Movie) error {
	ctx := context.Background()
	sess := m.manager.GetOrCreateSession(ctx, m.manager.Key(), m.taskFunc, m.baselineFunc)
	if err := m.manager.SetFavorites(ctx, sess, movies); err != nil {
		return fmt.Errorf("failed to set favorite movies: %w", err)
	}

	log.Printf("Created new session with %d initial movies", len(movies))

	return nil
}

// GetFavoriteMovies returns the current list of initial movies
func (m *Movies) GetFavoriteMovies() ([]session.Movie, error) {
	sess := m.manager.GetOrCreateSession(context.Background(), m.manager.Key(), m.taskFunc, m.baselineFunc)
	favorites, err := m.manager.GetFavorites(context.Background(), sess)
	if err != nil {
		log.Printf("ERROR: Failed to get favorite movies: %v", err)
		return []session.Movie{}, err // Return empty slice instead of nil
	}

	// If no favorites, return empty slice instead of nil
	if favorites == nil {
		return []session.Movie{}, nil
	}

	return favorites, nil
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
	ctx := context.Background()
	m.ensureCredentialsChecked()

	if !m.tmdbClient.HasValidCredentials() {
		return nil, fmt.Errorf("TMDB credentials not available")
	}

	// Get or create a session
	sess := m.manager.GetOrCreateSession(ctx, m.manager.Key(), m.taskFunc, m.baselineFunc)

	// Compose messages from the session content
	messages, err := m.llmClient.ComposeMessages(ctx, &sess.Content)
	if err != nil {
		log.Printf("ERROR: Failed to compose messages for movie suggestion: %v", err)
		return nil, fmt.Errorf("failed to compose messages for movie suggestion: %w", err)
	}

	// Request a suggestion from the LLM
	suggestion, err := m.llmClient.SendMessages(ctx, messages...)
	if err != nil {
		log.Printf("ERROR: Failed to get movie suggestion: %v", err)
		return nil, fmt.Errorf("failed to get movie suggestion: %w", err)
	}

	if suggestion == nil {
		return nil, fmt.Errorf("no suggestion available")
	}

	// Try to find more details about the suggested movie from TMDB
	query := suggestion.Title
	resp, err := m.tmdbClient.SearchMovies(ctx, query)
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

	sessionSuggestion := session.Suggestion[session.Movie]{
		PrimaryGenre: suggestion.PrimaryGenre,
		UserOutcome:  session.Pending,
		Reasoning:    suggestion.Reason,
		Content: session.Movie{
			Title:      movie.Title,
			Director:   movie.Director,
			Writer:     movie.Writer,
			PosterPath: movie.PosterPath,
		},
	}

	if sErr := m.manager.AddSuggestion(ctx, sess, sessionSuggestion); sErr != nil {
		log.Printf("ERROR: Failed to add suggestion: %v", sErr)
		return nil, fmt.Errorf("failed to add suggestion: %w", sErr)
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

	// Try to record the outcome, but don't fail if the suggestion isn't found
	err = m.manager.UpdateSuggestionOutcome(context.Background(), sess, key, outcome)
	if err != nil {
		log.Printf("WARNING: Failed to record outcome for movie '%s': %v", key, err)
		// Continue anyway - we can still add to favorites if needed
	}

	// If the user liked the movie, add it to their favorites
	if outcome == session.Liked || outcome == session.Added {
		// Convert to session.Movie using proper field names to match JSON tags
		favoriteMovie := session.Movie{
			Title:      movie.Title,      // maps to "title" in JSON
			Director:   movie.Director,   // maps to "director" in JSON
			Writer:     movie.Writer,     // maps to "writer" in JSON
			PosterPath: movie.PosterPath, // maps to "poster_path" in JSON
		}

		// Get current favorites
		favorites, err := m.manager.GetFavorites(context.Background(), sess)
		if err != nil {
			return fmt.Errorf("failed to get favorites: %w", err)
		}

		// If favorites is nil, initialize it
		if favorites == nil {
			favorites = []session.Movie{}
		}

		// Check if the movie already exists in favorites to avoid duplicates
		alreadyExists := false
		for _, fav := range favorites {
			if fav.Title == favoriteMovie.Title {
				alreadyExists = true
				break
			}
		}

		// Only add if not already in favorites
		if !alreadyExists {
			favorites = append(favorites, favoriteMovie)
			if err := m.manager.SetFavorites(context.Background(), sess, favorites); err != nil {
				return fmt.Errorf("failed to update favorites: %w", err)
			}
			log.Printf("Added movie '%s' to favorites", movie.Title)
		}
	}

	return nil
}
