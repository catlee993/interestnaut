package bindings

import (
	"context"
	"errors"
	"fmt"
	"interestnaut/internal/directives"
	"interestnaut/internal/gemini"
	"interestnaut/internal/llm"
	"interestnaut/internal/openai"
	"interestnaut/internal/session"
	"interestnaut/internal/tmdb"
	"log"
	"strings"
)

// TVShowWithSavedStatus represents a TV show with its saved status
type TVShowWithSavedStatus struct {
	ID           int      `json:"id"`
	Name         string   `json:"name"`
	Overview     string   `json:"overview"`
	Director     string   `json:"director"`
	Writer       string   `json:"writer"`
	PosterPath   string   `json:"poster_path"`
	FirstAirDate string   `json:"first_air_date"`
	VoteAverage  float64  `json:"vote_average"`
	VoteCount    int      `json:"vote_count"`
	Genres       []string `json:"genres"`
	IsSaved      bool     `json:"isSaved,omitempty"`
}

type TVShows struct {
	tmdbClient             *tmdb.Client
	llmClients             map[string]llm.Client[session.TVShow]
	manager                session.Manager[session.TVShow]
	centralManager         session.CentralManager
	baselineFunc, taskFunc func() string
}

func NewTVShowBinder(ctx context.Context, cm session.CentralManager) (*TVShows, error) {
	client := tmdb.NewClient()

	// Create a map of LLM clients for both providers
	llmClients := make(map[string]llm.Client[session.TVShow])

	// Initialize OpenAI client
	openaiClient, err := openai.NewClient[session.TVShow]()
	if err != nil {
		log.Printf("ERROR: Failed to create OpenAI client: %v", err)
	} else {
		llmClients["openai"] = openaiClient
	}

	// Initialize Gemini client
	geminiClient, err := gemini.NewClient[session.TVShow](cm)
	if err != nil {
		log.Printf("ERROR: Failed to create Gemini client: %v", err)
	} else {
		llmClients["gemini"] = geminiClient
	}

	// If no clients were successfully created, return nil
	if len(llmClients) == 0 {
		log.Printf("ERROR: Failed to create any LLM clients")
		return nil, errors.New("failed to create any LLM clients")
	}

	manager := cm.TVShow()

	t := &TVShows{
		tmdbClient:     client,
		llmClients:     llmClients,
		manager:        manager,
		centralManager: cm,
	}

	t.taskFunc = func() string {
		return directives.TVDirective
	}

	t.baselineFunc = func() string {
		// Get favorites directly from the central manager
		favorites := cm.Favorites().GetTVShows()
		return directives.GetTVBaseline(ctx, favorites)
	}

	return t, nil
}

// SetFavoriteTVShows allows the user to set their initial list of favorite TV shows
// This should be called before starting recommendations
func (t *TVShows) SetFavoriteTVShows(shows []session.TVShow) error {
	// Simply replace all TV show favorites with the provided list
	// Get current favorites
	currentFavorites := t.centralManager.Favorites().GetTVShows()

	// Remove all current favorites
	for _, show := range currentFavorites {
		if err := t.centralManager.Favorites().RemoveTVShow(show); err != nil {
			log.Printf("WARNING: Failed to remove TV show favorite %s: %v", show.Title, err)
		}
	}

	// Add all new favorites
	for _, show := range shows {
		if err := t.centralManager.Favorites().AddTVShow(show); err != nil {
			log.Printf("WARNING: Failed to add TV show favorite %s: %v", show.Title, err)
		}
	}

	log.Printf("Updated favorites with %d TV shows", len(shows))
	return nil
}

// GetFavoriteTVShows returns the current list of favorite TV shows
func (t *TVShows) GetFavoriteTVShows() ([]session.TVShow, error) {
	favorites := t.centralManager.Favorites().GetTVShows()

	// If no favorites, return empty slice instead of nil
	if favorites == nil {
		return []session.TVShow{}, nil
	}

	return favorites, nil
}

// AddToWatchlist adds a TV show to the user's watchlist
func (t *TVShows) AddToWatchlist(show session.TVShow) error {
	// Check if show already exists in watchlist
	watchlist := t.centralManager.Queue().GetTVShows()
	for _, ws := range watchlist {
		if ws.Title == show.Title {
			// TV show already in watchlist
			return nil
		}
	}

	// Add TV show to watchlist
	if err := t.centralManager.Queue().AddTVShow(show); err != nil {
		return fmt.Errorf("failed to add TV show to watchlist: %w", err)
	}

	log.Printf("Added '%s' to watchlist", show.Title)
	return nil
}

// RemoveFromWatchlist removes a TV show from the user's watchlist
func (t *TVShows) RemoveFromWatchlist(title string) error {
	// Get current watchlist
	watchlist := t.centralManager.Queue().GetTVShows()

	// Find the TV show by title
	found := false
	var showToRemove session.TVShow

	for _, show := range watchlist {
		if show.Title == title {
			found = true
			showToRemove = show
			break
		}
	}

	if !found {
		return fmt.Errorf("TV show '%s' not found in watchlist", title)
	}

	// Remove from the watchlist
	if err := t.centralManager.Queue().RemoveTVShow(showToRemove); err != nil {
		return fmt.Errorf("failed to remove TV show from watchlist: %w", err)
	}

	log.Printf("Removed '%s' from watchlist", title)
	return nil
}

// GetWatchlist returns the current watchlist
func (t *TVShows) GetWatchlist() ([]session.TVShow, error) {
	return t.centralManager.Queue().GetTVShows(), nil
}

// HasValidCredentials checks if the TMDB client has valid credentials
func (t *TVShows) HasValidCredentials() bool {
	return t.tmdbClient.HasValidCredentials()
}

// RefreshCredentials attempts to refresh the TMDB client's credentials
// Returns true if successful, false otherwise
func (t *TVShows) RefreshCredentials() bool {
	return t.tmdbClient.RefreshCredentials()
}

// SearchTVShows searches for TV shows in TMDB
func (t *TVShows) SearchTVShows(query string) ([]*TVShowWithSavedStatus, error) {
	if !t.tmdbClient.HasValidCredentials() {
		return nil, fmt.Errorf("TMDB credentials not available")
	}

	resp, err := t.tmdbClient.SearchTVShows(context.Background(), query)
	if err != nil {
		return nil, fmt.Errorf("failed to search TV shows: %w", err)
	}

	// Get favorites for comparison
	favorites := t.centralManager.Favorites().GetTVShows()

	// Convert response to array of TV shows and enrich with saved status
	shows := make([]*TVShowWithSavedStatus, len(resp.Results))
	for i, result := range resp.Results {
		genreNames := make([]string, len(result.Genres))
		for j, g := range result.Genres {
			genreNames[j] = g.Name
		}

		// Check if this show is saved in favorites
		isSaved := false
		for _, fav := range favorites {
			if strings.EqualFold(fav.Title, result.Name) {
				isSaved = true
				break
			}
		}

		shows[i] = &TVShowWithSavedStatus{
			ID:           result.ID,
			Name:         result.Name,
			Overview:     result.Overview,
			PosterPath:   result.PosterPath,
			FirstAirDate: result.FirstAirDate,
			VoteAverage:  result.VoteAverage,
			VoteCount:    result.VoteCount,
			Genres:       genreNames,
			IsSaved:      isSaved,
		}
	}

	return shows, nil
}

// GetTVShowDetails gets detailed information about a specific TV show
func (t *TVShows) GetTVShowDetails(showID int) (*TVShowWithSavedStatus, error) {
	if !t.tmdbClient.HasValidCredentials() {
		return nil, fmt.Errorf("TMDB credentials not available")
	}

	show, err := t.tmdbClient.GetTVShowDetails(context.Background(), showID)
	if err != nil {
		return nil, fmt.Errorf("failed to get TV show details: %w", err)
	}

	genreNames := make([]string, len(show.Genres))
	for i, g := range show.Genres {
		genreNames[i] = g.Name
	}

	// Check if this show is saved in favorites
	favorites := t.centralManager.Favorites().GetTVShows()
	isSaved := false
	for _, fav := range favorites {
		if strings.EqualFold(fav.Title, show.Name) {
			isSaved = true
			break
		}
	}

	return &TVShowWithSavedStatus{
		ID:           show.ID,
		Name:         show.Name,
		Overview:     show.Overview,
		PosterPath:   show.PosterPath,
		FirstAirDate: show.FirstAirDate,
		VoteAverage:  show.VoteAverage,
		VoteCount:    show.VoteCount,
		Genres:       genreNames,
		IsSaved:      isSaved,
	}, nil
}

// GetTVShowSuggestion gets a TV show suggestion from the LLM
func (t *TVShows) GetTVShowSuggestion() (map[string]interface{}, error) {
	ctx := context.Background()

	if !t.tmdbClient.HasValidCredentials() {
		return nil, fmt.Errorf("TMDB credentials not available")
	}

	// Get or create a session
	sess := t.manager.GetOrCreateSession(ctx, t.manager.Key(), t.taskFunc, t.baselineFunc)

	// Get current LLM provider from settings
	provider := t.centralManager.Settings().GetLLMProvider()

	// Get the appropriate client
	llmClient, ok := t.llmClients[provider]
	if !ok {
		// Fall back to openai if the requested provider is not available
		log.Printf("WARNING: Requested LLM provider '%s' not available, falling back to openai", provider)
		llmClient, ok = t.llmClients["openai"]
		if !ok {
			return nil, errors.New("no LLM clients available")
		}
	}

	// Compose messages from the session content
	messages, err := llmClient.ComposeMessages(ctx, &sess.Content)
	if err != nil {
		log.Printf("ERROR: Failed to compose messages for TV show suggestion: %v", err)
		return nil, fmt.Errorf("failed to compose messages for TV show suggestion: %w", err)
	}

	// Request a suggestion from the LLM
	suggestion, err := llmClient.SendMessages(ctx, messages...)
	if err != nil {
		log.Printf("ERROR: Failed to get TV show suggestion: %v", err)
		return nil, fmt.Errorf("failed to get TV show suggestion: %w", err)
	}

	if suggestion == nil {
		return nil, fmt.Errorf("no suggestion available")
	}

	// Try to find more details about the suggested TV show from TMDB
	query := suggestion.Title
	resp, err := t.tmdbClient.SearchTVShows(ctx, query)
	if err != nil {
		log.Printf("WARNING: Failed to search for suggested TV show '%s': %v", query, err)
	}

	var show *TVShowWithSavedStatus
	if err == nil && len(resp.Results) > 0 {
		// Use the first result that matches closely enough
		for _, result := range resp.Results {
			if strings.EqualFold(result.Name, suggestion.Title) {
				genreNames := make([]string, len(result.Genres))
				for j, g := range result.Genres {
					genreNames[j] = g.Name
				}

				// Check if this show is saved in favorites
				favorites := t.centralManager.Favorites().GetTVShows()
				isSaved := false
				for _, fav := range favorites {
					if strings.EqualFold(fav.Title, result.Name) {
						isSaved = true
						break
					}
				}

				show = &TVShowWithSavedStatus{
					ID:           result.ID,
					Name:         result.Name,
					Overview:     result.Overview,
					PosterPath:   result.PosterPath,
					FirstAirDate: result.FirstAirDate,
					VoteAverage:  result.VoteAverage,
					VoteCount:    result.VoteCount,
					Genres:       genreNames,
					IsSaved:      isSaved,
				}
				break
			}
		}

		// If no exact match, use the first result
		if show == nil && len(resp.Results) > 0 {
			result := resp.Results[0]
			genreNames := make([]string, len(result.Genres))
			for j, g := range result.Genres {
				genreNames[j] = g.Name
			}

			// Check if this show is saved in favorites
			favorites := t.centralManager.Favorites().GetTVShows()
			isSaved := false
			for _, fav := range favorites {
				if strings.EqualFold(fav.Title, result.Name) {
					isSaved = true
					break
				}
			}

			show = &TVShowWithSavedStatus{
				ID:           result.ID,
				Name:         result.Name,
				Overview:     result.Overview,
				PosterPath:   result.PosterPath,
				FirstAirDate: result.FirstAirDate,
				VoteAverage:  result.VoteAverage,
				VoteCount:    result.VoteCount,
				Genres:       genreNames,
				IsSaved:      isSaved,
			}
		}
	}

	// If we didn't find anything in TMDB, create a basic TV show object with the suggestion data
	if show == nil {
		// Check if this show is saved in favorites
		favorites := t.centralManager.Favorites().GetTVShows()
		isSaved := false
		for _, fav := range favorites {
			if strings.EqualFold(fav.Title, suggestion.Title) {
				isSaved = true
				break
			}
		}

		show = &TVShowWithSavedStatus{
			ID:         0, // No TMDB ID
			Name:       suggestion.Title,
			Overview:   fmt.Sprintf("Directed by %s, written by %s. %s", suggestion.Content.Director, suggestion.Content.Writer, suggestion.PrimaryGenre),
			PosterPath: "", // No poster
			Genres:     []string{suggestion.PrimaryGenre},
			IsSaved:    isSaved,
		}
	}

	sessionSuggestion := session.Suggestion[session.TVShow]{
		PrimaryGenre: suggestion.PrimaryGenre,
		UserOutcome:  session.Pending,
		Reasoning:    suggestion.Reason,
		Content: session.TVShow{
			Title:      show.Name, // Note: Converting from Name to Title
			Director:   show.Director,
			Writer:     show.Writer,
			PosterPath: show.PosterPath,
		},
	}

	if sErr := t.manager.AddSuggestion(ctx, sess, sessionSuggestion); sErr != nil {
		log.Printf("ERROR: Failed to add suggestion: %v", sErr)
		return nil, fmt.Errorf("failed to add suggestion: %w", sErr)
	}

	// Return a map that can be easily serialized to JSON
	result := map[string]interface{}{
		"show":   show,
		"reason": suggestion.Reason,
	}

	return result, nil
}

// ProvideSuggestionFeedback provides feedback on a suggestion
func (t *TVShows) ProvideSuggestionFeedback(outcome session.Outcome, showID int) error {
	// Get the current session
	sess := t.manager.GetOrCreateSession(context.Background(), t.manager.Key(), t.taskFunc, t.baselineFunc)

	// Get the TV show details from TMDB if possible
	var show *TVShowWithSavedStatus
	var err error

	if showID > 0 && t.tmdbClient.HasValidCredentials() {
		details, err := t.tmdbClient.GetTVShowDetails(context.Background(), showID)
		if err == nil {
			genreNames := make([]string, len(details.Genres))
			for i, g := range details.Genres {
				genreNames[i] = g.Name
			}

			show = &TVShowWithSavedStatus{
				ID:           details.ID,
				Name:         details.Name,
				Overview:     details.Overview,
				PosterPath:   details.PosterPath,
				FirstAirDate: details.FirstAirDate,
				VoteAverage:  details.VoteAverage,
				VoteCount:    details.VoteCount,
				Genres:       genreNames,
			}
		}
	}

	// If we couldn't get TV show details, create a placeholder
	if show == nil {
		show = &TVShowWithSavedStatus{
			ID:   showID,
			Name: fmt.Sprintf("TV Show ID %d", showID),
		}
	}

	// Use the TV show title as the key for updating the suggestion outcome
	key := session.KeyerTVShowInfo(show.Name, show.Director, show.Writer)

	// Try to record the outcome, but don't fail if the suggestion isn't found
	err = t.manager.UpdateSuggestionOutcome(context.Background(), sess, key, outcome)
	if err != nil {
		log.Printf("WARNING: Failed to record outcome for TV show '%s': %v", key, err)
	} else {
		log.Printf("Successfully recorded outcome %s for TV show '%s'", outcome, key)
	}

	if outcome == session.Added {
		// Convert to session.TVShow using proper field names to match JSON tags
		favoriteTVShow := session.TVShow{
			Title:      show.Name,
			Director:   show.Director,
			Writer:     show.Writer,
			PosterPath: show.PosterPath,
		}

		// Add to favorites using the central manager
		if err := t.centralManager.Favorites().AddTVShow(favoriteTVShow); err != nil {
			return fmt.Errorf("failed to add to favorites: %w", err)
		}
		log.Printf("Added TV show '%s' to favorites", show.Name)
	}

	return nil
}
