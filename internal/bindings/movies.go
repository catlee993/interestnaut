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
)

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
	centralManager         session.CentralManager
	baselineFunc, taskFunc func() string
}

func NewMovieBinder(ctx context.Context, cm session.CentralManager) (*Movies, error) {
	client := tmdb.NewClient()
	llmClient, err := openai.NewClient[session.Movie]()
	if err != nil {
		log.Printf("ERROR: Failed to create OpenAI client: %v", err)
		return nil, err
	}

	manager := cm.Movie()

	m := &Movies{
		tmdbClient:     client,
		llmClient:      llmClient,
		manager:        manager,
		centralManager: cm,
	}

	m.taskFunc = func() string {
		return directives.MovieDirective
	}

	m.baselineFunc = func() string {
		// Get favorites directly from the central manager
		favorites := cm.Favorites().GetMovies()
		return directives.GetMovieBaseline(ctx, favorites)
	}

	return m, nil
}

// SetFavoriteMovies allows the user to set their initial list of favorite movies
// This should be called before starting recommendations
func (m *Movies) SetFavoriteMovies(movies []session.Movie) error {
	// Simply replace all movie favorites with the provided list
	// Get current favorites
	currentFavorites := m.centralManager.Favorites().GetMovies()

	// Remove all current favorites
	for _, movie := range currentFavorites {
		if err := m.centralManager.Favorites().RemoveMovie(movie); err != nil {
			log.Printf("WARNING: Failed to remove movie favorite %s: %v", movie.Title, err)
		}
	}

	// Add all new favorites
	for _, movie := range movies {
		if err := m.centralManager.Favorites().AddMovie(movie); err != nil {
			log.Printf("WARNING: Failed to add movie favorite %s: %v", movie.Title, err)
		}
	}

	log.Printf("Updated favorites with %d movies", len(movies))
	return nil
}

// GetFavoriteMovies returns the current list of favorite movies
func (m *Movies) GetFavoriteMovies() ([]session.Movie, error) {
	favorites := m.centralManager.Favorites().GetMovies()

	// If no favorites, return empty slice instead of nil
	if favorites == nil {
		return []session.Movie{}, nil
	}

	return favorites, nil
}

// AddToWatchlist adds a movie to the user's watchlist
func (m *Movies) AddToWatchlist(movie session.Movie) error {
	// Check if movie already exists in watchlist
	watchlist := m.centralManager.Queue().GetMovies()
	for _, wm := range watchlist {
		if wm.Title == movie.Title {
			// Movie already in watchlist
			return nil
		}
	}

	// Add movie to watchlist
	if err := m.centralManager.Queue().AddMovie(movie); err != nil {
		return fmt.Errorf("failed to add movie to watchlist: %w", err)
	}

	log.Printf("Added '%s' to watchlist", movie.Title)
	return nil
}

// RemoveFromWatchlist removes a movie from the user's watchlist
func (m *Movies) RemoveFromWatchlist(title string) error {
	// Get current watchlist
	watchlist := m.centralManager.Queue().GetMovies()

	// Find the movie by title
	found := false
	var movieToRemove session.Movie

	for _, movie := range watchlist {
		if movie.Title == title {
			found = true
			movieToRemove = movie
			break
		}
	}

	if !found {
		return fmt.Errorf("movie '%s' not found in watchlist", title)
	}

	// Remove from the watchlist
	if err := m.centralManager.Queue().RemoveMovie(movieToRemove); err != nil {
		return fmt.Errorf("failed to remove movie from watchlist: %w", err)
	}

	log.Printf("Removed '%s' from watchlist", title)
	return nil
}

// GetWatchlist returns the current watchlist
func (m *Movies) GetWatchlist() ([]session.Movie, error) {
	return m.centralManager.Queue().GetMovies(), nil
}

// HasValidCredentials checks if the TMDB client has valid credentials
func (m *Movies) HasValidCredentials() bool {
	return m.tmdbClient.HasValidCredentials()
}

// RefreshCredentials attempts to refresh the TMDB client's credentials
// Returns true if successful, false otherwise
func (m *Movies) RefreshCredentials() bool {
	return m.tmdbClient.RefreshCredentials()
}

// SearchMovies searches for movies in TMDB
func (m *Movies) SearchMovies(query string) ([]*MovieWithSavedStatus, error) {
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
	key := session.KeyerMovieInfo(movie.Title, movie.Director, movie.Writer)

	// Try to record the outcome, but don't fail if the suggestion isn't found
	err = m.manager.UpdateSuggestionOutcome(context.Background(), sess, key, outcome)
	if err != nil {
		log.Printf("WARNING: Failed to record outcome for movie '%s': %v", key, err)
	} else {
		log.Printf("Successfully recorded outcome %s for movie '%s'", outcome, key)
	}

	if outcome == session.Added {
		// Convert to session.Movie using proper field names to match JSON tags
		favoriteMovie := session.Movie{
			Title:      movie.Title,
			Director:   movie.Director,
			Writer:     movie.Writer,
			PosterPath: movie.PosterPath,
		}

		// Add to favorites using the central manager
		if err := m.centralManager.Favorites().AddMovie(favoriteMovie); err != nil {
			return fmt.Errorf("failed to add to favorites: %w", err)
		}
		log.Printf("Added movie '%s' to favorites", movie.Title)
	}

	return nil
}
