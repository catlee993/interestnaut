package bindings

import (
	"context"
	"fmt"
	"html"
	"interestnaut/internal/directives"
	"interestnaut/internal/gemini"
	"interestnaut/internal/llm"
	"interestnaut/internal/openai"
	"interestnaut/internal/rawg"
	"interestnaut/internal/session"
	"log"
	"regexp"
	"strings"
	"sync"
)

type Screenshot struct {
	ID    int    `json:"id"`
	Image string `json:"image"`
}

type PlatformDetails struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
	Slug string `json:"slug"`
}

type Platform struct {
	ID       int             `json:"id,omitempty"`
	Name     string          `json:"name"`
	Slug     string          `json:"slug,omitempty"`
	Platform PlatformDetails `json:"platform,omitempty"`
}

type Genre struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
	Slug string `json:"slug,omitempty"`
}

type Developer struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
	Slug string `json:"slug,omitempty"`
}

type Publisher struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
	Slug string `json:"slug,omitempty"`
}

// Games provides bindings for the RAWG API client
type Games struct {
	client                 rawg.Client
	llmClients             map[string]llm.Client[session.VideoGame]
	manager                session.Manager[session.VideoGame]
	centralManager         session.CentralManager
	baselineFunc, taskFunc func() string
	mu                     sync.Mutex
}

// GameWithSavedStatus represents a game with additional saved status flags
type GameWithSavedStatus struct {
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
	IsSaved          bool         `json:"isSaved"`
	IsInWatchlist    bool         `json:"isInWatchlist"`
}

// Helper function to convert rawg.Game to our GameWithSavedStatus
func rawgGameToGameWithSavedStatus(game *rawg.Game, isSaved bool, isInWatchlist bool) *GameWithSavedStatus {
	if game == nil {
		return nil
	}

	result := &GameWithSavedStatus{
		ID:              game.ID,
		Name:            game.Name,
		Slug:            game.Slug,
		Released:        game.Released,
		BackgroundImage: game.BackgroundImage,
		Rating:          game.Rating,
		RatingsCount:    game.RatingsCount,
		Playtime:        game.Playtime,
		Description:     sanitizeHTMLDescription(game.Description),
		IsSaved:         isSaved,
		IsInWatchlist:   isInWatchlist,
	}

	// Convert Screenshots
	if game.ShortScreenshots != nil {
		result.ShortScreenshots = make([]Screenshot, len(game.ShortScreenshots))
		for i, s := range game.ShortScreenshots {
			result.ShortScreenshots[i] = Screenshot{
				ID:    s.ID,
				Image: s.Image,
			}
		}
	}

	// Convert Platforms
	if game.Platforms != nil {
		result.Platforms = make([]Platform, len(game.Platforms))
		for i, p := range game.Platforms {
			result.Platforms[i] = Platform{
				ID:   p.ID,
				Name: p.Name,
				Slug: p.Slug,
				Platform: PlatformDetails{
					ID:   p.Platform.ID,
					Name: p.Platform.Name,
					Slug: p.Platform.Slug,
				},
			}
		}
	}

	// Convert Genres
	if game.Genres != nil {
		result.Genres = make([]Genre, len(game.Genres))
		for i, g := range game.Genres {
			result.Genres[i] = Genre{
				ID:   g.ID,
				Name: g.Name,
				Slug: g.Slug,
			}
		}
	}

	// Convert Developers
	if game.Developers != nil {
		result.Developers = make([]Developer, len(game.Developers))
		for i, d := range game.Developers {
			result.Developers[i] = Developer{
				ID:   d.ID,
				Name: d.Name,
				Slug: d.Slug,
			}
		}
	}

	// Convert Publishers
	if game.Publishers != nil {
		result.Publishers = make([]Publisher, len(game.Publishers))
		for i, p := range game.Publishers {
			result.Publishers[i] = Publisher{
				ID:   p.ID,
				Name: p.Name,
				Slug: p.Slug,
			}
		}
	}

	return result
}

// Helper function to create a basic game with minimal info
func createBasicGame(title string, description string, primaryGenre string) *GameWithSavedStatus {
	return &GameWithSavedStatus{
		ID:          0,
		Name:        title,
		Description: sanitizeHTMLDescription(description),
		Genres: []Genre{
			{
				Name: primaryGenre,
			},
		},
		IsSaved:       false,
		IsInWatchlist: false,
	}
}

// NewGames creates a new Games binding
func NewGames(ctx context.Context, cm session.CentralManager) (*Games, error) {
	client := rawg.NewClient()

	// Create a map of LLM clients for both providers
	llmClients := make(map[string]llm.Client[session.VideoGame])

	// Initialize OpenAI client
	openaiClient, err := openai.NewClient[session.VideoGame](cm)
	if err != nil {
		log.Printf("WARNING: Failed to create OpenAI client: %v", err)
	} else {
		llmClients["openai"] = openaiClient
	}

	// Initialize Gemini client
	geminiClient, err := gemini.NewClient[session.VideoGame](cm)
	if err != nil {
		log.Printf("WARNING: Failed to create Gemini client: %v", err)
	} else {
		llmClients["gemini"] = geminiClient
	}

	// Log warning if no clients were successfully created, but continue
	if len(llmClients) == 0 {
		log.Printf("WARNING: No LLM clients available, functionality may be limited")
	}

	manager := cm.VideoGame()

	g := &Games{
		client:         client,
		llmClients:     llmClients,
		manager:        manager,
		centralManager: cm,
	}

	g.taskFunc = func() string {
		return directives.GameDirective
	}

	g.baselineFunc = func() string {
		// Get favorites directly from the central manager
		favorites := cm.Favorites().GetVideoGames()
		return directives.GetGameBaseline(ctx, favorites)
	}

	return g, nil
}

// SetFavoriteGames allows the user to set their initial list of favorite games
// This should be called before starting recommendations
func (g *Games) SetFavoriteGames(games []session.VideoGame) error {
	// Simply replace all game favorites with the provided list
	// Get current favorites
	currentFavorites := g.centralManager.Favorites().GetVideoGames()

	// Remove all current favorites
	for _, game := range currentFavorites {
		if err := g.centralManager.Favorites().RemoveVideoGame(game); err != nil {
			log.Printf("WARNING: Failed to remove game favorite %s: %v", game.Title, err)
		}
	}

	// Add all new favorites
	for _, game := range games {
		if err := g.centralManager.Favorites().AddVideoGame(game); err != nil {
			log.Printf("WARNING: Failed to add game favorite %s: %v", game.Title, err)
		}
	}

	log.Printf("Updated favorites with %d games", len(games))
	return nil
}

// GetFavoriteGames returns the current list of favorite games
func (g *Games) GetFavoriteGames() ([]session.VideoGame, error) {
	favorites := g.centralManager.Favorites().GetVideoGames()

	// If no favorites, return empty slice instead of nil
	if favorites == nil {
		return []session.VideoGame{}, nil
	}

	return favorites, nil
}

// AddToWatchlist adds a game to the watchlist
func (g *Games) AddToWatchlist(game session.VideoGame) error {
	// Check if game already exists in watchlist
	watchlist := g.centralManager.Queue().GetVideoGames()
	for _, wg := range watchlist {
		if wg.Title == game.Title {
			// Game already in watchlist
			return nil
		}
	}

	// Add game to watchlist
	if err := g.centralManager.Queue().AddVideoGame(game); err != nil {
		return fmt.Errorf("failed to add game to watchlist: %w", err)
	}

	log.Printf("Added '%s' to watchlist", game.Title)
	return nil
}

// RemoveFromWatchlist removes a game from the watchlist
func (g *Games) RemoveFromWatchlist(title string) error {
	// Get current watchlist
	watchlist := g.centralManager.Queue().GetVideoGames()

	// Find the game by title
	found := false
	var gameToRemove session.VideoGame

	for _, game := range watchlist {
		if game.Title == title {
			found = true
			gameToRemove = game
			break
		}
	}

	if !found {
		return fmt.Errorf("game '%s' not found in watchlist", title)
	}

	// Remove from the watchlist
	if err := g.centralManager.Queue().RemoveVideoGame(gameToRemove); err != nil {
		return fmt.Errorf("failed to remove game from watchlist: %w", err)
	}

	log.Printf("Removed '%s' from watchlist", title)
	return nil
}

// GetWatchlist returns the current watchlist
func (g *Games) GetWatchlist() ([]session.VideoGame, error) {
	return g.centralManager.Queue().GetVideoGames(), nil
}

// HasValidCredentials checks if the client has valid credentials
func (g *Games) HasValidCredentials() bool {
	return g.client.HasValidCredentials()
}

// RefreshCredentials updates the client's API key with the latest credentials
func (g *Games) RefreshCredentials() bool {
	return g.client.RefreshCredentials()
}

// SearchGames searches for games matching the query
func (g *Games) SearchGames(query string) ([]*GameWithSavedStatus, error) {
	if !g.client.HasValidCredentials() {
		return nil, fmt.Errorf("RAWG credentials not available")
	}

	resp, err := g.client.SearchGames(context.Background(), query, 1, 20)
	if err != nil {
		return nil, fmt.Errorf("failed to search games: %w", err)
	}

	// Convert response to array of games and enrich with saved status
	games := make([]*GameWithSavedStatus, len(resp.Results))
	for i, result := range resp.Results {
		// Check if in favorites
		favorites := g.centralManager.Favorites().GetVideoGames()
		isSaved := false
		for _, favorite := range favorites {
			if strings.EqualFold(favorite.Title, result.Name) {
				isSaved = true
				break
			}
		}

		// Check if in watchlist
		watchlist := g.centralManager.Queue().GetVideoGames()
		isInWatchlist := false
		for _, item := range watchlist {
			if strings.EqualFold(item.Title, result.Name) {
				isInWatchlist = true
				break
			}
		}

		// Sanitize the description before creating the GameWithSavedStatus
		if result.Description != "" {
			result.Description = sanitizeHTMLDescription(result.Description)
		}

		// Create a GameWithSavedStatus from the search result
		games[i] = rawgGameToGameWithSavedStatus(&result, isSaved, isInWatchlist)

		// Fetch detailed game information for each result to get the description
		// This might slow down the search, but will provide descriptions
		if games[i].ID > 0 {
			detailedGame, detailErr := g.client.GetGameDetails(context.Background(), games[i].ID)
			if detailErr == nil && detailedGame != nil {
				// Sanitize any HTML in the description
				games[i].Description = sanitizeHTMLDescription(detailedGame.Description)
			}
		}
	}

	return games, nil
}

// GetGameDetails gets detailed information about a game
func (g *Games) GetGameDetails(id int) (*GameWithSavedStatus, error) {
	if !g.client.HasValidCredentials() {
		return nil, fmt.Errorf("RAWG credentials not available")
	}

	game, err := g.client.GetGameDetails(context.Background(), id)
	if err != nil {
		return nil, err
	}

	// Sanitize HTML from description before creating GameWithSavedStatus
	if game.Description != "" {
		game.Description = sanitizeHTMLDescription(game.Description)
	}

	// Check if this game is in favorites
	favorites := g.centralManager.Favorites().GetVideoGames()
	isSaved := false
	for _, favorite := range favorites {
		if strings.EqualFold(favorite.Title, game.Name) {
			isSaved = true
			break
		}
	}

	// Check if this game is in the watchlist
	watchlist := g.centralManager.Queue().GetVideoGames()
	isInWatchlist := false
	for _, item := range watchlist {
		if strings.EqualFold(item.Title, game.Name) {
			isInWatchlist = true
			break
		}
	}

	return rawgGameToGameWithSavedStatus(game, isSaved, isInWatchlist), nil
}

// RefreshLLMClients attempts to recreate LLM clients that may have failed to initialize
func (g *Games) RefreshLLMClients() {
	g.mu.Lock()
	defer g.mu.Unlock()

	log.Println("Refreshing Games LLM clients")

	// Check if OpenAI client is missing
	if _, ok := g.llmClients["openai"]; !ok {
		openaiClient, err := openai.NewClient[session.VideoGame](g.centralManager)
		if err != nil {
			log.Printf("WARNING: Failed to create OpenAI client: %v", err)
		} else {
			g.llmClients["openai"] = openaiClient
			log.Println("Successfully created OpenAI client for Games")
		}
	}

	// Check if Gemini client is missing
	if _, ok := g.llmClients["gemini"]; !ok {
		geminiClient, err := gemini.NewClient[session.VideoGame](g.centralManager)
		if err != nil {
			log.Printf("WARNING: Failed to create Gemini client: %v", err)
		} else {
			g.llmClients["gemini"] = geminiClient
			log.Println("Successfully created Gemini client for Games")
		}
	}

	// Log warning if still no clients instead of returning error
	if len(g.llmClients) == 0 {
		log.Printf("WARNING: Could not create any LLM clients after refresh, functionality may be limited")
	}
}

// GetGameSuggestion gets a game suggestion from the LLM
func (g *Games) GetGameSuggestion() (map[string]interface{}, error) {
	ctx := context.Background()

	if !g.client.HasValidCredentials() {
		return nil, fmt.Errorf("RAWG credentials not available")
	}

	// Get or create a session
	sess := g.manager.GetOrCreateSession(ctx, g.manager.Key(), g.taskFunc, g.baselineFunc)

	// Get current LLM provider from settings
	provider := g.centralManager.Settings().GetLLMProvider()

	// Get the appropriate client
	llmClient, ok := g.llmClients[provider]
	if !ok {
		// Fall back to openai if the requested provider is not available
		log.Printf("WARNING: Requested LLM provider '%s' not available, falling back to openai", provider)
		llmClient, ok = g.llmClients["openai"]
		if !ok {
			log.Printf("WARNING: No LLM clients available, providing a default suggestion")
			// Create a fallback game suggestion
			game := createBasicGame("LLM Suggestion Unavailable", "LLM services are currently unavailable. Please ensure your API keys are correctly configured.", "Not Available")

			result := map[string]interface{}{
				"game":   game,
				"reason": "No LLM clients are available. Please check your API keys in settings.",
			}
			return result, nil
		}
	}

	// Compose messages from the session content
	messages, err := llmClient.ComposeMessages(ctx, &sess.Content)
	if err != nil {
		log.Printf("ERROR: Failed to compose messages for game suggestion: %v", err)
		return nil, fmt.Errorf("failed to compose messages for game suggestion: %w", err)
	}

	// Request a suggestion from the LLM
	suggestion, err := llmClient.SendMessages(ctx, messages...)
	if err != nil {
		log.Printf("ERROR: Failed to get game suggestion: %v", err)
		return nil, fmt.Errorf("failed to get game suggestion: %w", err)
	}

	if suggestion == nil {
		return nil, fmt.Errorf("no suggestion available")
	}

	// Try to find more details about the suggested game from RAWG
	query := suggestion.Title
	resp, err := g.client.SearchGames(ctx, query, 1, 10)
	if err != nil {
		log.Printf("WARNING: Failed to search for suggested game '%s': %v", query, err)
	}

	var game *GameWithSavedStatus
	var foundExactMatch bool
	var detailedGame *rawg.Game

	if err == nil && len(resp.Results) > 0 {
		// Use the first result that matches closely enough
		for _, result := range resp.Results {
			if strings.EqualFold(result.Name, suggestion.Title) {
				// We found an exact match, now get the detailed game info
				foundExactMatch = true
				detailedGame, err = g.client.GetGameDetails(ctx, result.ID)
				if err != nil {
					log.Printf("WARNING: Failed to get detailed info for game '%s' (ID: %d): %v", result.Name, result.ID, err)
					// Fall back to using search result
					detailedGame = &result
				}
				break
			}
		}

		// If no exact match, use the first result and get details
		if !foundExactMatch && len(resp.Results) > 0 {
			detailedGame, err = g.client.GetGameDetails(ctx, resp.Results[0].ID)
			if err != nil {
				log.Printf("WARNING: Failed to get detailed info for game '%s' (ID: %d): %v", resp.Results[0].Name, resp.Results[0].ID, err)
				// Fall back to using search result
				detailedGame = &resp.Results[0]
			}
		}

		if detailedGame != nil {
			// Check if this game is saved in favorites
			favorites := g.centralManager.Favorites().GetVideoGames()
			isSaved := false
			for _, favorite := range favorites {
				if strings.EqualFold(favorite.Title, detailedGame.Name) {
					isSaved = true
					break
				}
			}

			// Check if in watchlist
			watchlist := g.centralManager.Queue().GetVideoGames()
			isInWatchlist := false
			for _, item := range watchlist {
				if strings.EqualFold(item.Title, detailedGame.Name) {
					isInWatchlist = true
					break
				}
			}

			game = rawgGameToGameWithSavedStatus(detailedGame, isSaved, isInWatchlist)
		}
	}

	// If we didn't find anything in RAWG, create a basic game object with the suggestion data
	if game == nil {
		// Create a basic game with the suggestion data
		description := fmt.Sprintf("Developed by %s, published by %s. %s",
			suggestion.Content.Developer,
			suggestion.Content.Publisher,
			suggestion.PrimaryGenre)

		game = createBasicGame(suggestion.Title, description, suggestion.PrimaryGenre)
	}

	// Create a session suggestion to record it
	sessionSuggestion := session.Suggestion[session.VideoGame]{
		PrimaryGenre: suggestion.PrimaryGenre,
		UserOutcome:  session.Pending,
		Reasoning:    suggestion.Reason,
		Content: session.VideoGame{
			Title:     game.Name,
			Developer: suggestion.Content.Developer,
			Publisher: suggestion.Content.Publisher,
			// Use CoverPath instead of PosterPath for games
			CoverPath: game.BackgroundImage,
		},
	}

	if sErr := g.manager.AddSuggestion(ctx, sess, sessionSuggestion); sErr != nil {
		log.Printf("ERROR: Failed to add suggestion: %v", sErr)
		return nil, fmt.Errorf("failed to add suggestion: %w", sErr)
	}

	// Return a map that can be easily serialized to JSON
	result := map[string]interface{}{
		"game":   game,
		"reason": suggestion.Reason,
	}

	return result, nil
}

// ProvideSuggestionFeedback provides feedback on a suggestion
func (g *Games) ProvideSuggestionFeedback(outcome session.Outcome, gameID int) error {
	// Get the current session
	sess := g.manager.GetOrCreateSession(context.Background(), g.manager.Key(), g.taskFunc, g.baselineFunc)

	// Get the game details from RAWG if possible
	var rawgGame *rawg.Game
	var err error

	if gameID > 0 {
		rawgGame, err = g.client.GetGameDetails(context.Background(), gameID)
		if err != nil {
			log.Printf("WARNING: Failed to get game details for ID %d: %v", gameID, err)
			rawgGame = nil
		}
	}

	// Extract name, developer, and publisher
	var name, developer, publisher string

	if rawgGame != nil {
		name = rawgGame.Name

		// Try to get the developer and publisher
		for _, dev := range rawgGame.Developers {
			if developer == "" {
				developer = dev.Name
			}
		}
		for _, pub := range rawgGame.Publishers {
			if publisher == "" {
				publisher = pub.Name
			}
		}
	} else {
		// If we couldn't get game details, create a placeholder
		name = fmt.Sprintf("Game ID %d", gameID)
	}

	// Use the game name, developer, and publisher as the key for updating the suggestion outcome
	key := session.KeyerVideoGameInfo(name, developer, publisher)

	// Try to record the outcome, but don't fail if the suggestion isn't found
	err = g.manager.UpdateSuggestionOutcome(context.Background(), sess, key, outcome)
	if err != nil {
		log.Printf("WARNING: Failed to record outcome for game '%s': %v", key, err)
	} else {
		log.Printf("Successfully recorded outcome %s for game '%s'", outcome, key)
	}

	if outcome == session.Added {
		// Convert to session.VideoGame
		favoriteGame := session.VideoGame{
			Title:     name,
			Developer: developer,
			Publisher: publisher,
		}

		// Add background image if available
		if rawgGame != nil && rawgGame.BackgroundImage != "" {
			favoriteGame.CoverPath = rawgGame.BackgroundImage
		}

		// Add to favorites using the central manager
		if err := g.centralManager.Favorites().AddVideoGame(favoriteGame); err != nil {
			return fmt.Errorf("failed to add to favorites: %w", err)
		}
		log.Printf("Added game '%s' to favorites", name)
	}

	return nil
}

// Helper function to sanitize HTML content from descriptions
func sanitizeHTMLDescription(description string) string {
	// Skip processing if empty
	if description == "" {
		return description
	}

	// Remove HTML tags
	re := regexp.MustCompile("<[^>]*>")
	cleanText := re.ReplaceAllString(description, " ")

	// Replace multiple spaces with single space
	cleanText = regexp.MustCompile(`\s+`).ReplaceAllString(cleanText, " ")

	// Decode HTML entities
	cleanText = html.UnescapeString(cleanText)

	// Trim leading/trailing whitespace
	cleanText = strings.TrimSpace(cleanText)

	return cleanText
}
