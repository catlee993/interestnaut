package bindings

import (
	"context"
	"errors"
	"fmt"
	"interestnaut/internal/db"
	"interestnaut/internal/directives"
	"interestnaut/internal/gemini"
	"interestnaut/internal/llm"
	"interestnaut/internal/openai"
	"interestnaut/internal/rawg"
	"interestnaut/internal/session"
	"log"
	"strings"
	"time"
)

// Games provides bindings for the RAWG API client
type Games struct {
	client                 rawg.Client
	llmClients             map[string]llm.Client[session.VideoGame]
	manager                session.Manager[session.VideoGame]
	centralManager         session.CentralManager
	baselineFunc, taskFunc func() string
}

// GameWithSavedStatus represents a game with additional saved status flags
type GameWithSavedStatus struct {
	*rawg.Game
	IsSaved       bool `json:"isSaved"`
	IsInWatchlist bool `json:"isInWatchlist"`
}

// NewGames creates a new Games binding
func NewGames(ctx context.Context, cm session.CentralManager) (*Games, error) {
	client := rawg.NewClient()

	// Create a map of LLM clients for both providers
	llmClients := make(map[string]llm.Client[session.VideoGame])

	// Initialize OpenAI client
	openaiClient, err := openai.NewClient[session.VideoGame]()
	if err != nil {
		log.Printf("ERROR: Failed to create OpenAI client: %v", err)
	} else {
		llmClients["openai"] = openaiClient
	}

	// Initialize Gemini client
	geminiClient, err := gemini.NewClient[session.VideoGame](cm)
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

// SearchGames searches for games matching the query
func (g *Games) SearchGames(query string, page, pageSize int) (*rawg.GameSearchResponse, error) {
	return g.client.SearchGames(context.Background(), query, page, pageSize)
}

// GetGames gets a paginated list of games
func (g *Games) GetGames(page, pageSize int) (*rawg.GameSearchResponse, error) {
	return g.client.GetGames(context.Background(), page, pageSize)
}

// GetGameDetails gets detailed information about a game
func (g *Games) GetGameDetails(id int) (*GameWithSavedStatus, error) {
	game, err := g.client.GetGameDetails(context.Background(), id)
	if err != nil {
		return nil, err
	}

	isSaved, err := db.IsGameSaved(id)
	if err != nil {
		log.Printf("Error checking if game is saved: %v", err)
		// Continue anyway, treating as not saved
		isSaved = false
	}

	isInWatchlist, err := db.IsGameInWatchlist(id)
	if err != nil {
		log.Printf("Error checking if game is in watchlist: %v", err)
		// Continue anyway, treating as not in watchlist
		isInWatchlist = false
	}

	return &GameWithSavedStatus{
		Game:          game,
		IsSaved:       isSaved,
		IsInWatchlist: isInWatchlist,
	}, nil
}

// RefreshCredentials updates the client's API key with the latest credentials
func (g *Games) RefreshCredentials() bool {
	return g.client.RefreshCredentials()
}

// HasValidCredentials checks if the client has valid credentials
func (g *Games) HasValidCredentials() bool {
	return g.client.HasValidCredentials()
}

// ToSimpleGame converts a Game to a SimpleGame
func (g *Games) ToSimpleGame(game *rawg.Game) *rawg.SimpleGame {
	if game == nil {
		return nil
	}

	// Extract genre names
	genres := make([]string, 0, len(game.Genres))
	for _, genre := range game.Genres {
		genres = append(genres, genre.Name)
	}

	return &rawg.SimpleGame{
		ID:              game.ID,
		Name:            game.Name,
		Released:        game.Released,
		BackgroundImage: game.BackgroundImage,
		Rating:          game.Rating,
		RatingsCount:    game.RatingsCount,
		Genres:          genres,
	}
}

// ConvertToSimpleGames converts a slice of Games to SimpleGames
func (g *Games) ConvertToSimpleGames(games []rawg.Game) []*rawg.SimpleGame {
	simpleGames := make([]*rawg.SimpleGame, 0, len(games))
	for _, game := range games {
		gameCopy := game // Create a copy to avoid issues with the loop variable
		simpleGames = append(simpleGames, g.ToSimpleGame(&gameCopy))
	}
	return simpleGames
}

// GetSavedGames retrieves all games saved as favorites
func (g *Games) GetSavedGames() ([]*GameWithSavedStatus, error) {
	savedGames, err := db.GetSavedGames()
	if err != nil {
		return nil, fmt.Errorf("failed to get saved games: %w", err)
	}

	result := make([]*GameWithSavedStatus, 0, len(savedGames))
	for _, savedGame := range savedGames {
		game := &rawg.Game{
			ID:              savedGame.ID,
			Name:            savedGame.Name,
			Released:        savedGame.Released,
			BackgroundImage: savedGame.BackgroundImage,
			Rating:          savedGame.Rating,
			RatingsCount:    savedGame.RatingsCount,
		}

		isInWatchlist, _ := db.IsGameInWatchlist(savedGame.ID)

		result = append(result, &GameWithSavedStatus{
			Game:          game,
			IsSaved:       true,
			IsInWatchlist: isInWatchlist,
		})
	}

	return result, nil
}

// SaveGame saves a game as a favorite
func (g *Games) SaveGame(id int) error {
	// First check if already saved
	isSaved, err := db.IsGameSaved(id)
	if err != nil {
		return fmt.Errorf("failed to check if game is saved: %w", err)
	}

	if isSaved {
		return nil // Already saved, nothing to do
	}

	// Get game details
	game, err := g.client.GetGameDetails(context.Background(), id)
	if err != nil {
		return fmt.Errorf("failed to get game details: %w", err)
	}

	// Extract genre names
	genres := make([]string, 0, len(game.Genres))
	for _, genre := range game.Genres {
		genres = append(genres, genre.Name)
	}

	// Save to database
	gameData := db.GameData{
		ID:              game.ID,
		Name:            game.Name,
		BackgroundImage: game.BackgroundImage,
		Rating:          game.Rating,
		RatingsCount:    game.RatingsCount,
		Released:        game.Released,
		Genres:          genres,
	}

	timestamp := time.Now().Format(time.RFC3339)
	return db.SaveGameToFavorites(gameData, timestamp)
}

// UnsaveGame removes a game from favorites
func (g *Games) UnsaveGame(id int) error {
	return db.RemoveGameFromFavorites(id)
}

// GetWatchlistGames retrieves all games in the watchlist
func (g *Games) GetWatchlistGames() ([]*GameWithSavedStatus, error) {
	watchlistGames, err := db.GetWatchlistGames()
	if err != nil {
		return nil, fmt.Errorf("failed to get watchlist games: %w", err)
	}

	result := make([]*GameWithSavedStatus, 0, len(watchlistGames))
	for _, watchlistGame := range watchlistGames {
		game := &rawg.Game{
			ID:              watchlistGame.ID,
			Name:            watchlistGame.Name,
			Released:        watchlistGame.Released,
			BackgroundImage: watchlistGame.BackgroundImage,
			Rating:          watchlistGame.Rating,
			RatingsCount:    watchlistGame.RatingsCount,
		}

		isSaved, _ := db.IsGameSaved(watchlistGame.ID)

		result = append(result, &GameWithSavedStatus{
			Game:          game,
			IsSaved:       isSaved,
			IsInWatchlist: true,
		})
	}

	return result, nil
}

// AddGameToWatchlist adds a game to the watchlist
func (g *Games) AddGameToWatchlist(id int) error {
	// First check if already in watchlist
	isInWatchlist, err := db.IsGameInWatchlist(id)
	if err != nil {
		return fmt.Errorf("failed to check if game is in watchlist: %w", err)
	}

	if isInWatchlist {
		return nil // Already in watchlist, nothing to do
	}

	// Get game details
	game, err := g.client.GetGameDetails(context.Background(), id)
	if err != nil {
		return fmt.Errorf("failed to get game details: %w", err)
	}

	// Extract genre names
	genres := make([]string, 0, len(game.Genres))
	for _, genre := range game.Genres {
		genres = append(genres, genre.Name)
	}

	// Save to database
	gameData := db.GameData{
		ID:              game.ID,
		Name:            game.Name,
		BackgroundImage: game.BackgroundImage,
		Rating:          game.Rating,
		RatingsCount:    game.RatingsCount,
		Released:        game.Released,
		Genres:          genres,
	}

	timestamp := time.Now().Format(time.RFC3339)
	return db.AddGameToWatchlist(gameData, timestamp)
}

// RemoveGameFromWatchlist removes a game from the watchlist
func (g *Games) RemoveGameFromWatchlist(id int) error {
	return db.RemoveGameFromWatchlist(id)
}

// IsGameSaved checks if a game is in the user's favorites
func (g *Games) IsGameSaved(id int) (bool, error) {
	return db.IsGameSaved(id)
}

// IsGameInWatchlist checks if a game is in the user's watchlist
func (g *Games) IsGameInWatchlist(id int) (bool, error) {
	return db.IsGameInWatchlist(id)
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
			return nil, errors.New("no LLM clients available")
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
	if err == nil && len(resp.Results) > 0 {
		// Use the first result that matches closely enough
		for _, result := range resp.Results {
			if strings.EqualFold(result.Name, suggestion.Title) {
				// Create a copy of the result
				gameCopy := result

				// Check if this game is saved in favorites
				isSaved, _ := g.IsGameSaved(result.ID)
				isInWatchlist, _ := g.IsGameInWatchlist(result.ID)

				game = &GameWithSavedStatus{
					Game:          &gameCopy,
					IsSaved:       isSaved,
					IsInWatchlist: isInWatchlist,
				}
				break
			}
		}

		// If no exact match, use the first result
		if game == nil && len(resp.Results) > 0 {
			result := resp.Results[0]

			// Create a copy of the result
			gameCopy := result

			// Check if this game is saved in favorites
			isSaved, _ := g.IsGameSaved(result.ID)
			isInWatchlist, _ := g.IsGameInWatchlist(result.ID)

			game = &GameWithSavedStatus{
				Game:          &gameCopy,
				IsSaved:       isSaved,
				IsInWatchlist: isInWatchlist,
			}
		}
	}

	// If we didn't find anything in RAWG, create a basic game object with the suggestion data
	if game == nil {
		// Create a basic game with the suggestion data
		game = &GameWithSavedStatus{
			Game: &rawg.Game{
				ID:          0, // No RAWG ID
				Name:        suggestion.Title,
				Description: fmt.Sprintf("Developed by %s, published by %s. %s", suggestion.Content.Developer, suggestion.Content.Publisher, suggestion.PrimaryGenre),
				Genres:      []rawg.Genre{{Name: suggestion.PrimaryGenre}},
			},
			IsSaved:       false,
			IsInWatchlist: false,
		}
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
	var game *rawg.Game
	var err error

	if gameID > 0 {
		details, err := g.client.GetGameDetails(context.Background(), gameID)
		if err == nil {
			game = details
		}
	}

	// If we couldn't get game details, create a placeholder
	if game == nil {
		game = &rawg.Game{
			ID:   gameID,
			Name: fmt.Sprintf("Game ID %d", gameID),
		}
	}

	// Try to get the developer and publisher
	developer := ""
	publisher := ""
	for _, dev := range game.Developers {
		if developer == "" {
			developer = dev.Name
		}
	}
	for _, pub := range game.Publishers {
		if publisher == "" {
			publisher = pub.Name
		}
	}

	// Use the game name, developer, and publisher as the key for updating the suggestion outcome
	key := session.KeyerVideoGameInfo(game.Name, developer, publisher)

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
			Title:     game.Name,
			Developer: developer,
			Publisher: publisher,
			CoverPath: game.BackgroundImage,
		}

		// Add to favorites using the central manager
		if err := g.centralManager.Favorites().AddVideoGame(favoriteGame); err != nil {
			return fmt.Errorf("failed to add to favorites: %w", err)
		}
		log.Printf("Added game '%s' to favorites", game.Name)
	}

	return nil
}
