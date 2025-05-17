package suggestions

import (
	"context"
	"errors"
	"fmt"
	"interestnaut/internal/app/llm"
	"interestnaut/internal/app/session"

	"interestnaut/internal/app/db"
	"interestnaut/internal/app/wikidata"
	"interestnaut/internal/app/wikipedia"
)

// Suggestion represents a media suggestion
type Suggestion struct {
	MediaID   uint64
	MediaType db.MediaType
	Title     string
	Subtitle  string // Artist, author, developer, etc.
	ImageURL  string
	Reason    string
	Source    string // "wikidata", "wikipedia", "llm", etc.
}

// Service handles generating and retrieving suggestions
type Service struct {
	wikidataClient  *wikidata.Client
	wikipediaClient *wikipedia.Client
	llmMusic        llm.Client[session.Music]
	llmMovie        llm.Client[session.Movie]
	llmShow         llm.Client[session.TVShow]
	llmBook         llm.Client[session.Book]
	llmVideoGame    llm.Client[session.VideoGame]
}

// NewService creates a new suggestion service
func NewService(database db.Database, userAgent string) *Service {
	return &Service{
		wikidataClient:  wikidata.NewClient(userAgent),
		wikipediaClient: wikipedia.NewClient(userAgent),
	}
}

// SetLLMProvider sets the LLM provider for generating suggestions
func (s *Service) SetLLMProvider(
	llmMusic llm.Client[session.Music],
	llmMovie llm.Client[session.Movie],
	llmShow llm.Client[session.TVShow],
	llmBook llm.Client[session.Book],
	llmVideoGame llm.Client[session.VideoGame],
) {
	s.llmBook = llmBook
	s.llmMusic = llmMusic
	s.llmMovie = llmMovie
	s.llmShow = llmShow
	s.llmVideoGame = llmVideoGame
}

// GetLLMClientForMediaType returns the appropriate LLM client for the given media type
// It returns a properly typed LLM client based on the media type
func (s *Service) GetLLMClientForMediaType(mediaType db.MediaType) (interface{}, error) {
	switch mediaType {
	case db.MediaTypeMusic:
		if s.llmMusic == nil {
			return nil, errors.New("music LLM client not configured")
		}
		return s.llmMusic, nil
	case db.MediaTypeMovie:
		if s.llmMovie == nil {
			return nil, errors.New("movie LLM client not configured")
		}
		return s.llmMovie, nil
	case db.MediaTypeShow:
		if s.llmShow == nil {
			return nil, errors.New("TV show LLM client not configured")
		}
		return s.llmShow, nil
	case db.MediaTypeBook:
		if s.llmBook == nil {
			return nil, errors.New("book LLM client not configured")
		}
		return s.llmBook, nil
	case db.MediaTypeVideoGame:
		if s.llmVideoGame == nil {
			return nil, errors.New("video game LLM client not configured")
		}
		return s.llmVideoGame, nil
	default:
		return nil, fmt.Errorf("unsupported media type: %s", mediaType)
	}
}

// GetLLMClientMusic returns the music LLM client
func (s *Service) GetLLMClientMusic() (llm.Client[session.Music], error) {
	if s.llmMusic == nil {
		return nil, errors.New("music LLM client not configured")
	}
	return s.llmMusic, nil
}

// GetLLMClientMovie returns the movie LLM client
func (s *Service) GetLLMClientMovie() (llm.Client[session.Movie], error) {
	if s.llmMovie == nil {
		return nil, errors.New("movie LLM client not configured")
	}
	return s.llmMovie, nil
}

// GetLLMClientShow returns the TV show LLM client
func (s *Service) GetLLMClientShow() (llm.Client[session.TVShow], error) {
	if s.llmShow == nil {
		return nil, errors.New("TV show LLM client not configured")
	}
	return s.llmShow, nil
}

// GetLLMClientBook returns the book LLM client
func (s *Service) GetLLMClientBook() (llm.Client[session.Book], error) {
	if s.llmBook == nil {
		return nil, errors.New("book LLM client not configured")
	}
	return s.llmBook, nil
}

// GetLLMClientVideoGame returns the video game LLM client
func (s *Service) GetLLMClientVideoGame() (llm.Client[session.VideoGame], error) {
	if s.llmVideoGame == nil {
		return nil, errors.New("video game LLM client not configured")
	}
	return s.llmVideoGame, nil
}

// GetSuggestions returns a list of suggestions based on the provided parameters
func (s *Service) GetSuggestions(ctx context.Context, mediaType db.MediaType, basedOnID uint64, limit int) ([]Suggestion, error) {
	// Start with an empty slice of suggestions
	var suggestions []Suggestion

	// Get suggestions from various sources

	// 1. First, try to get suggestions from our database
	dbSuggestions, err := s.getDBSuggestions(ctx, mediaType, basedOnID, limit)
	if err == nil && len(dbSuggestions) > 0 {
		suggestions = append(suggestions, dbSuggestions...)
	}

	// If we already have enough suggestions, return them
	if len(suggestions) >= limit {
		return suggestions[:limit], nil
	}

	// 2. Try to get suggestions from Wikidata
	wikiSuggestions, err := s.getWikidataSuggestions(ctx, mediaType, basedOnID, limit-len(suggestions))
	if err == nil && len(wikiSuggestions) > 0 {
		suggestions = append(suggestions, wikiSuggestions...)
	}

	// If we already have enough suggestions, return them
	if len(suggestions) >= limit {
		return suggestions[:limit], nil
	}

	// 3. Finally, try to get suggestions from LLM
	llmClient, err := s.GetLLMClientForMediaType(mediaType)
	if err == nil && llmClient != nil {
		llmSuggestions, err := s.getLLMSuggestions(ctx, mediaType, basedOnID, limit-len(suggestions), llmClient)
		if err == nil && len(llmSuggestions) > 0 {
			suggestions = append(suggestions, llmSuggestions...)
		}
	}

	// Return whatever suggestions we have, limited to the requested amount
	if len(suggestions) > limit {
		return suggestions[:limit], nil
	}
	return suggestions, nil
}

// getDBSuggestions gets suggestions from our local database based on similar items
func (s *Service) getDBSuggestions(ctx context.Context, mediaType db.MediaType, basedOnID uint64, limit int) ([]Suggestion, error) {
	// If there's no specific item to base suggestions on, return empty
	if basedOnID <= 0 {
		return []Suggestion{}, nil
	}

	// Call the appropriate type-specific method based on media type
	switch mediaType {
	case db.MediaTypeMusic:
		return s.getDBMusicSuggestions(ctx, basedOnID, limit)
	case db.MediaTypeBook:
		return s.getDBBookSuggestions(ctx, basedOnID, limit)
	case db.MediaTypeMovie:
		return s.getDBMovieSuggestions(ctx, basedOnID, limit)
	case db.MediaTypeShow:
		return s.getDBShowSuggestions(ctx, basedOnID, limit)
	case db.MediaTypeVideoGame:
		return s.getDBVideoGameSuggestions(ctx, basedOnID, limit)
	default:
		return []Suggestion{}, fmt.Errorf("unsupported media type: %s", mediaType)
	}
}

// getDBMusicSuggestions gets music suggestions from the database
func (s *Service) getDBMusicSuggestions(ctx context.Context, basedOnID uint64, limit int) ([]Suggestion, error) {
	var suggestions []Suggestion

	// Set up search options with limit
	options := db.DefaultSearchOptions()
	options.Limit = limit

	// First, get the music item to base suggestions on
	music, err := db.DB.GetMusic(basedOnID)
	if err != nil {
		return nil, err
	}

	// Search for music by the same artist
	searchResults, err := db.DB.SearchMusic(music.Artist, options)
	if err != nil {
		return nil, err
	}

	for _, m := range searchResults {
		// Skip the same item
		if m.ID == basedOnID {
			continue
		}

		suggestions = append(suggestions, Suggestion{
			MediaID:   m.ID,
			MediaType: db.MediaTypeMusic,
			Title:     m.Title,
			Subtitle:  m.Artist,
			ImageURL:  m.AlbumArtURL,
			Reason:    fmt.Sprintf("By the same artist: %s", m.Artist),
			Source:    "database",
		})

		if len(suggestions) >= limit {
			break
		}
	}

	return suggestions, nil
}

// getDBBookSuggestions gets book suggestions from the database
func (s *Service) getDBBookSuggestions(ctx context.Context, basedOnID uint64, limit int) ([]Suggestion, error) {
	var suggestions []Suggestion

	// Set up search options with limit
	options := db.DefaultSearchOptions()
	options.Limit = limit

	// First, get the book to base suggestions on
	book, err := db.DB.GetBook(basedOnID)
	if err != nil {
		return nil, err
	}

	// Search for books by the same author
	searchResults, err := db.DB.SearchBooks(book.Author, options)
	if err != nil {
		return nil, err
	}

	for _, b := range searchResults {
		// Skip the same item
		if b.ID == basedOnID {
			continue
		}

		suggestions = append(suggestions, Suggestion{
			MediaID:   b.ID,
			MediaType: db.MediaTypeBook,
			Title:     b.Title,
			Subtitle:  b.Author,
			ImageURL:  b.CoverArtURL,
			Reason:    fmt.Sprintf("By the same author: %s", b.Author),
			Source:    "database",
		})

		if len(suggestions) >= limit {
			break
		}
	}

	return suggestions, nil
}

// getDBMovieSuggestions gets movie suggestions from the database
func (s *Service) getDBMovieSuggestions(ctx context.Context, basedOnID uint64, limit int) ([]Suggestion, error) {
	var suggestions []Suggestion

	// Set up search options with limit
	options := db.DefaultSearchOptions()
	options.Limit = limit

	// First, get the movie to base suggestions on
	movie, err := db.DB.GetMovie(basedOnID)
	if err != nil {
		return nil, err
	}

	// Search for movies by the same director
	searchResults, err := db.DB.SearchMovies(movie.Director, options)
	if err != nil {
		return nil, err
	}

	for _, m := range searchResults {
		// Skip the same item
		if m.ID == basedOnID {
			continue
		}

		suggestions = append(suggestions, Suggestion{
			MediaID:   m.ID,
			MediaType: db.MediaTypeMovie,
			Title:     m.Title,
			Subtitle:  m.Director,
			ImageURL:  m.PosterURL,
			Reason:    fmt.Sprintf("By the same director: %s", m.Director),
			Source:    "database",
		})

		if len(suggestions) >= limit {
			break
		}
	}

	return suggestions, nil
}

// getDBShowSuggestions gets TV show suggestions from the database
func (s *Service) getDBShowSuggestions(ctx context.Context, basedOnID uint64, limit int) ([]Suggestion, error) {
	var suggestions []Suggestion

	// Set up search options with limit
	options := db.DefaultSearchOptions()
	options.Limit = limit

	// First, get the show to base suggestions on
	show, err := db.DB.GetShow(basedOnID)
	if err != nil {
		return nil, err
	}

	// Search for shows by the same director
	searchResults, err := db.DB.SearchShows(show.Director, options)
	if err != nil {
		return nil, err
	}

	for _, sh := range searchResults {
		// Skip the same item
		if sh.ID == basedOnID {
			continue
		}

		suggestions = append(suggestions, Suggestion{
			MediaID:   sh.ID,
			MediaType: db.MediaTypeShow,
			Title:     sh.Title,
			Subtitle:  sh.Director,
			ImageURL:  sh.PosterURL,
			Reason:    fmt.Sprintf("By the same creator: %s", sh.Director),
			Source:    "database",
		})

		if len(suggestions) >= limit {
			break
		}
	}

	return suggestions, nil
}

// getDBVideoGameSuggestions gets video game suggestions from the database
func (s *Service) getDBVideoGameSuggestions(ctx context.Context, basedOnID uint64, limit int) ([]Suggestion, error) {
	var suggestions []Suggestion

	// Set up search options with limit
	options := db.DefaultSearchOptions()
	options.Limit = limit

	// First, get the game to base suggestions on
	game, err := db.DB.GetVideoGame(basedOnID)
	if err != nil {
		return nil, err
	}

	// Search for games by the same developer
	searchResults, err := db.DB.SearchVideoGames(game.Developer, options)
	if err != nil {
		return nil, err
	}

	for _, g := range searchResults {
		// Skip the same item
		if g.ID == basedOnID {
			continue
		}

		suggestions = append(suggestions, Suggestion{
			MediaID:   g.ID,
			MediaType: db.MediaTypeVideoGame,
			Title:     g.Title,
			Subtitle:  g.Developer,
			ImageURL:  g.CoverArtURL,
			Reason:    fmt.Sprintf("By the same developer: %s", g.Developer),
			Source:    "database",
		})

		if len(suggestions) >= limit {
			break
		}
	}

	return suggestions, nil
}

// getWikidataSuggestions gets suggestions from Wikidata based on related items
func (s *Service) getWikidataSuggestions(ctx context.Context, mediaType db.MediaType, basedOnID uint64, limit int) ([]Suggestion, error) {
	// If there's no specific item to base suggestions on, return empty
	if basedOnID <= 0 {
		return []Suggestion{}, nil
	}

	// Call the appropriate type-specific method based on media type
	switch mediaType {
	case db.MediaTypeMusic:
		return s.getWikidataMusicSuggestions(ctx, basedOnID, limit)
	case db.MediaTypeBook:
		return s.getWikidataBookSuggestions(ctx, basedOnID, limit)
	case db.MediaTypeMovie:
		return s.getWikidataMovieSuggestions(ctx, basedOnID, limit)
	case db.MediaTypeShow:
		return s.getWikidataShowSuggestions(ctx, basedOnID, limit)
	case db.MediaTypeVideoGame:
		return s.getWikidataVideoGameSuggestions(ctx, basedOnID, limit)
	default:
		return []Suggestion{}, fmt.Errorf("unsupported media type: %s", mediaType)
	}
}

// getWikidataMusicSuggestions gets music suggestions from Wikidata
func (s *Service) getWikidataMusicSuggestions(ctx context.Context, basedOnID uint64, limit int) ([]Suggestion, error) {
	// Get the base music item
	music, err := db.DB.GetMusic(basedOnID)
	if err != nil {
		return nil, err
	}

	title := music.Title
	creator := music.Artist
	query := fmt.Sprintf("%s %s", title, creator)

	// Convert media type to wikidata's format
	wdMediaType := wikidata.MediaType(string(db.MediaTypeMusic))

	return s.fetchWikidataSuggestions(ctx, query, wdMediaType, db.MediaTypeMusic, title, creator, limit)
}

// getWikidataBookSuggestions gets book suggestions from Wikidata
func (s *Service) getWikidataBookSuggestions(ctx context.Context, basedOnID uint64, limit int) ([]Suggestion, error) {
	// Get the base book item
	book, err := db.DB.GetBook(basedOnID)
	if err != nil {
		return nil, err
	}

	title := book.Title
	creator := book.Author
	query := fmt.Sprintf("%s %s", title, creator)

	// Convert media type to wikidata's format
	wdMediaType := wikidata.MediaType(string(db.MediaTypeBook))

	return s.fetchWikidataSuggestions(ctx, query, wdMediaType, db.MediaTypeBook, title, creator, limit)
}

// getWikidataMovieSuggestions gets movie suggestions from Wikidata
func (s *Service) getWikidataMovieSuggestions(ctx context.Context, basedOnID uint64, limit int) ([]Suggestion, error) {
	// Get the base movie item
	movie, err := db.DB.GetMovie(basedOnID)
	if err != nil {
		return nil, err
	}

	title := movie.Title
	creator := movie.Director
	query := fmt.Sprintf("%s %s", title, creator)

	// Convert media type to wikidata's format
	wdMediaType := wikidata.MediaType(string(db.MediaTypeMovie))

	return s.fetchWikidataSuggestions(ctx, query, wdMediaType, db.MediaTypeMovie, title, creator, limit)
}

// getWikidataShowSuggestions gets TV show suggestions from Wikidata
func (s *Service) getWikidataShowSuggestions(ctx context.Context, basedOnID uint64, limit int) ([]Suggestion, error) {
	// Get the base show item
	show, err := db.DB.GetShow(basedOnID)
	if err != nil {
		return nil, err
	}

	title := show.Title
	creator := show.Director
	query := fmt.Sprintf("%s %s", title, creator)

	// Convert media type to wikidata's format
	wdMediaType := wikidata.MediaType(string(db.MediaTypeShow))

	return s.fetchWikidataSuggestions(ctx, query, wdMediaType, db.MediaTypeShow, title, creator, limit)
}

// getWikidataVideoGameSuggestions gets video game suggestions from Wikidata
func (s *Service) getWikidataVideoGameSuggestions(ctx context.Context, basedOnID uint64, limit int) ([]Suggestion, error) {
	// Get the base video game item
	game, err := db.DB.GetVideoGame(basedOnID)
	if err != nil {
		return nil, err
	}

	title := game.Title
	creator := game.Developer
	query := fmt.Sprintf("%s %s", title, creator)

	// Convert media type to wikidata's format
	wdMediaType := wikidata.MediaType(string(db.MediaTypeVideoGame))

	return s.fetchWikidataSuggestions(ctx, query, wdMediaType, db.MediaTypeVideoGame, title, creator, limit)
}

// fetchWikidataSuggestions is a helper function to avoid code duplication across media types
func (s *Service) fetchWikidataSuggestions(
	ctx context.Context,
	query string,
	wdMediaType wikidata.MediaType,
	appMediaType db.MediaType,
	baseTitle string,
	baseCreator string,
	limit int,
) ([]Suggestion, error) {
	var suggestions []Suggestion

	// Use Wikidata to find similar items
	results, err := s.wikidataClient.SearchEntities(ctx, query, wdMediaType, "en")
	if err != nil {
		return nil, err
	}

	// Convert the first 'limit' results to suggestions
	count := 0
	for _, result := range results {
		// Skip if this appears to be the same item we're basing suggestions on
		if result.Label == baseTitle {
			continue
		}

		// Get detailed info for this item
		info, err := s.wikidataClient.GetMediaInfo(ctx, result.ID, wdMediaType)
		if err != nil {
			continue
		}

		var subtitle string

		// Set subtitle based on media type
		switch appMediaType {
		case db.MediaTypeMusic:
			subtitle = info.Artist
		case db.MediaTypeBook:
			subtitle = info.Author
		case db.MediaTypeMovie, db.MediaTypeShow:
			subtitle = info.Director
		case db.MediaTypeVideoGame:
			subtitle = info.Developer
		}

		// Create a suggestion
		suggestion := Suggestion{
			MediaID:   0, // Not in database yet
			MediaType: appMediaType,
			Title:     info.Title,
			Subtitle:  subtitle,
			ImageURL:  info.ImageURL,
			Reason:    fmt.Sprintf("Similar to %s by %s", baseTitle, baseCreator),
			Source:    "wikidata",
		}

		suggestions = append(suggestions, suggestion)
		count++

		if count >= limit {
			break
		}
	}

	return suggestions, nil
}

// getLLMSuggestions gets suggestions from the configured LLM provider
func (s *Service) getLLMSuggestions(ctx context.Context, mediaType db.MediaType, basedOnID uint64, limit int, llmClient interface{}) ([]Suggestion, error) {
	// If there's no specific item to base suggestions on, return empty
	if basedOnID <= 0 {
		return nil, errors.New("basedOnID is required for LLM suggestions")
	}

	// Use switch to call the appropriate type-specific method
	switch mediaType {
	case db.MediaTypeMusic:
		musicClient, ok := llmClient.(llm.Client[session.Music])
		if !ok {
			return nil, errors.New("invalid music LLM client type")
		}
		return s.getLLMMusicSuggestions(ctx, basedOnID, limit, musicClient)
	case db.MediaTypeMovie:
		movieClient, ok := llmClient.(llm.Client[session.Movie])
		if !ok {
			return nil, errors.New("invalid movie LLM client type")
		}
		return s.getLLMMovieSuggestions(ctx, basedOnID, limit, movieClient)
	case db.MediaTypeShow:
		showClient, ok := llmClient.(llm.Client[session.TVShow])
		if !ok {
			return nil, errors.New("invalid TV show LLM client type")
		}
		return s.getLLMShowSuggestions(ctx, basedOnID, limit, showClient)
	case db.MediaTypeBook:
		bookClient, ok := llmClient.(llm.Client[session.Book])
		if !ok {
			return nil, errors.New("invalid book LLM client type")
		}
		return s.getLLMBookSuggestions(ctx, basedOnID, limit, bookClient)
	case db.MediaTypeVideoGame:
		gameClient, ok := llmClient.(llm.Client[session.VideoGame])
		if !ok {
			return nil, errors.New("invalid video game LLM client type")
		}
		return s.getLLMVideoGameSuggestions(ctx, basedOnID, limit, gameClient)
	default:
		return nil, fmt.Errorf("unsupported media type: %s", mediaType)
	}
}

// getLLMMusicSuggestions gets music suggestions from the LLM provider
func (s *Service) getLLMMusicSuggestions(ctx context.Context, basedOnID uint64, limit int, client llm.Client[session.Music]) ([]Suggestion, error) {
	// Get information about the base music item
	musicInfo, err := db.DB.GetMusic(basedOnID)
	if err != nil {
		return nil, fmt.Errorf("failed to get music information: %w", err)
	}

	// Create session.Music from db.Music
	music := session.Music{
		ID:     musicInfo.ID,
		Title:  musicInfo.Title,
		Artist: musicInfo.Artist,
		Album:  musicInfo.Album,
	}

	// Create content for the LLM
	content := &session.Content[session.Music]{
		PrimeDirective: session.PrimeDirective{
			Task:     fmt.Sprintf("Suggest music similar to '%s' by %s", music.Title, music.Artist),
			Baseline: fmt.Sprintf("The user enjoys '%s' by %s", music.Title, music.Artist),
		},
		Suggestions:     make(map[string]session.Suggestion[session.Music]),
		UserConstraints: []string{},
	}

	// Compose messages for the LLM
	messages, err := client.ComposeMessages(ctx, content)
	if err != nil {
		return nil, fmt.Errorf("failed to compose messages: %w", err)
	}

	// Send messages to the LLM and get a response
	response, err := client.SendMessages(ctx, messages...)
	if err != nil {
		return nil, fmt.Errorf("failed to get LLM response: %w", err)
	}

	// Convert LLM response to suggestions
	var suggestions []Suggestion

	// Add a suggestion based on the response
	suggestion := Suggestion{
		MediaID:   0, // Not in database yet
		MediaType: db.MediaTypeMusic,
		Title:     response.Title,
		Subtitle:  response.Artist,
		ImageURL:  "", // LLM doesn't provide image URLs
		Reason:    response.Reason,
		Source:    "llm",
	}
	suggestions = append(suggestions, suggestion)

	return suggestions, nil
}

// getLLMMovieSuggestions gets movie suggestions from the LLM provider
func (s *Service) getLLMMovieSuggestions(ctx context.Context, basedOnID uint64, limit int, client llm.Client[session.Movie]) ([]Suggestion, error) {
	// Get information about the base movie item
	movieInfo, err := db.DB.GetMovie(basedOnID)
	if err != nil {
		return nil, fmt.Errorf("failed to get movie information: %w", err)
	}

	// Create session.Movie from db.Movie
	movie := session.Movie{
		ID:       movieInfo.ID,
		Title:    movieInfo.Title,
		Director: movieInfo.Director,
		Writer:   movieInfo.Writer,
	}

	// Create content for the LLM
	content := &session.Content[session.Movie]{
		PrimeDirective: session.PrimeDirective{
			Task:     fmt.Sprintf("Suggest movies similar to '%s' directed by %s", movie.Title, movie.Director),
			Baseline: fmt.Sprintf("The user enjoys '%s' directed by %s", movie.Title, movie.Director),
		},
		Suggestions:     make(map[string]session.Suggestion[session.Movie]),
		UserConstraints: []string{},
	}

	// Compose messages for the LLM
	messages, err := client.ComposeMessages(ctx, content)
	if err != nil {
		return nil, fmt.Errorf("failed to compose messages: %w", err)
	}

	// Send messages to the LLM and get a response
	response, err := client.SendMessages(ctx, messages...)
	if err != nil {
		return nil, fmt.Errorf("failed to get LLM response: %w", err)
	}

	// Convert LLM response to suggestions
	var suggestions []Suggestion

	// Add a suggestion based on the response
	suggestion := Suggestion{
		MediaID:   0, // Not in database yet
		MediaType: db.MediaTypeMovie,
		Title:     response.Title,
		Subtitle:  response.Artist, // LLM response uses Artist field for Director
		ImageURL:  "",              // LLM doesn't provide image URLs
		Reason:    response.Reason,
		Source:    "llm",
	}
	suggestions = append(suggestions, suggestion)

	return suggestions, nil
}

// getLLMShowSuggestions gets TV show suggestions from the LLM provider
func (s *Service) getLLMShowSuggestions(ctx context.Context, basedOnID uint64, limit int, client llm.Client[session.TVShow]) ([]Suggestion, error) {
	// Get information about the base show item
	showInfo, err := db.DB.GetShow(basedOnID)
	if err != nil {
		return nil, fmt.Errorf("failed to get TV show information: %w", err)
	}

	// Create session.TVShow from db.Show
	show := session.TVShow{
		ID:       showInfo.ID,
		Title:    showInfo.Title,
		Director: showInfo.Director,
		Writer:   showInfo.Writer,
	}

	// Create content for the LLM
	content := &session.Content[session.TVShow]{
		PrimeDirective: session.PrimeDirective{
			Task:     fmt.Sprintf("Suggest TV shows similar to '%s'", show.Title),
			Baseline: fmt.Sprintf("The user enjoys '%s'", show.Title),
		},
		Suggestions:     make(map[string]session.Suggestion[session.TVShow]),
		UserConstraints: []string{},
	}

	// Compose messages for the LLM
	messages, err := client.ComposeMessages(ctx, content)
	if err != nil {
		return nil, fmt.Errorf("failed to compose messages: %w", err)
	}

	// Send messages to the LLM and get a response
	response, err := client.SendMessages(ctx, messages...)
	if err != nil {
		return nil, fmt.Errorf("failed to get LLM response: %w", err)
	}

	// Convert LLM response to suggestions
	var suggestions []Suggestion

	// Add a suggestion based on the response
	suggestion := Suggestion{
		MediaID:   0, // Not in database yet
		MediaType: db.MediaTypeShow,
		Title:     response.Title,
		Subtitle:  response.Artist, // LLM response uses Artist field for Director/Creator
		ImageURL:  "",              // LLM doesn't provide image URLs
		Reason:    response.Reason,
		Source:    "llm",
	}
	suggestions = append(suggestions, suggestion)

	return suggestions, nil
}

// getLLMBookSuggestions gets book suggestions from the LLM provider
func (s *Service) getLLMBookSuggestions(ctx context.Context, basedOnID uint64, limit int, client llm.Client[session.Book]) ([]Suggestion, error) {
	// Get information about the base book item
	bookInfo, err := db.DB.GetBook(basedOnID)
	if err != nil {
		return nil, fmt.Errorf("failed to get book information: %w", err)
	}

	// Create session.Book from db.Book
	book := session.Book{
		ID:     bookInfo.ID,
		Title:  bookInfo.Title,
		Author: bookInfo.Author,
	}

	// Create content for the LLM
	content := &session.Content[session.Book]{
		PrimeDirective: session.PrimeDirective{
			Task:     fmt.Sprintf("Suggest books similar to '%s' by %s", book.Title, book.Author),
			Baseline: fmt.Sprintf("The user enjoys '%s' by %s", book.Title, book.Author),
		},
		Suggestions:     make(map[string]session.Suggestion[session.Book]),
		UserConstraints: []string{},
	}

	// Compose messages for the LLM
	messages, err := client.ComposeMessages(ctx, content)
	if err != nil {
		return nil, fmt.Errorf("failed to compose messages: %w", err)
	}

	// Send messages to the LLM and get a response
	response, err := client.SendMessages(ctx, messages...)
	if err != nil {
		return nil, fmt.Errorf("failed to get LLM response: %w", err)
	}

	// Convert LLM response to suggestions
	var suggestions []Suggestion

	// Add a suggestion based on the response
	suggestion := Suggestion{
		MediaID:   0, // Not in database yet
		MediaType: db.MediaTypeBook,
		Title:     response.Title,
		Subtitle:  response.Artist, // LLM response uses Artist field for Author
		ImageURL:  "",              // LLM doesn't provide image URLs
		Reason:    response.Reason,
		Source:    "llm",
	}
	suggestions = append(suggestions, suggestion)

	return suggestions, nil
}

// getLLMVideoGameSuggestions gets video game suggestions from the LLM provider
func (s *Service) getLLMVideoGameSuggestions(ctx context.Context, basedOnID uint64, limit int, client llm.Client[session.VideoGame]) ([]Suggestion, error) {
	// Get information about the base video game item
	gameInfo, err := db.DB.GetVideoGame(basedOnID)
	if err != nil {
		return nil, fmt.Errorf("failed to get video game information: %w", err)
	}

	// Create session.VideoGame from db.VideoGame
	game := session.VideoGame{
		ID:        gameInfo.ID,
		Title:     gameInfo.Title,
		Developer: gameInfo.Developer,
		Platforms: gameInfo.Platforms,
	}

	// Create content for the LLM
	content := &session.Content[session.VideoGame]{
		PrimeDirective: session.PrimeDirective{
			Task:     fmt.Sprintf("Suggest video games similar to '%s' by %s", game.Title, game.Developer),
			Baseline: fmt.Sprintf("The user enjoys '%s' by %s", game.Title, game.Developer),
		},
		Suggestions:     make(map[string]session.Suggestion[session.VideoGame]),
		UserConstraints: []string{},
	}

	// Compose messages for the LLM
	messages, err := client.ComposeMessages(ctx, content)
	if err != nil {
		return nil, fmt.Errorf("failed to compose messages: %w", err)
	}

	// Send messages to the LLM and get a response
	response, err := client.SendMessages(ctx, messages...)
	if err != nil {
		return nil, fmt.Errorf("failed to get LLM response: %w", err)
	}

	// Convert LLM response to suggestions
	var suggestions []Suggestion

	// Add a suggestion based on the response
	suggestion := Suggestion{
		MediaID:   0, // Not in database yet
		MediaType: db.MediaTypeVideoGame,
		Title:     response.Title,
		Subtitle:  response.Artist, // LLM response uses Artist field for Developer
		ImageURL:  "",              // LLM doesn't provide image URLs
		Reason:    response.Reason,
		Source:    "llm",
	}
	suggestions = append(suggestions, suggestion)

	return suggestions, nil
}

// SaveSuggestionOutcome records a user's response to a suggestion
func (s *Service) SaveSuggestionOutcome(ctx context.Context, mediaType db.MediaType, mediaID uint64, reason string, outcome db.SuggestionOutcome) error {
	// Call the appropriate type-specific method based on media type
	switch mediaType {
	case db.MediaTypeMusic:
		return s.SaveMusicSuggestionOutcome(ctx, mediaID, reason, outcome)
	case db.MediaTypeBook:
		return s.SaveBookSuggestionOutcome(ctx, mediaID, reason, outcome)
	case db.MediaTypeMovie:
		return s.SaveMovieSuggestionOutcome(ctx, mediaID, reason, outcome)
	case db.MediaTypeShow:
		return s.SaveShowSuggestionOutcome(ctx, mediaID, reason, outcome)
	case db.MediaTypeVideoGame:
		return s.SaveVideoGameSuggestionOutcome(ctx, mediaID, reason, outcome)
	default:
		return fmt.Errorf("unsupported media type: %s", mediaType)
	}
}

// SaveMusicSuggestionOutcome records a user's response to a music suggestion
func (s *Service) SaveMusicSuggestionOutcome(ctx context.Context, mediaID uint64, reason string, outcome db.SuggestionOutcome) error {
	return db.DB.AddSuggestion(mediaID, db.MediaTypeMusic, reason, outcome)
}

// SaveBookSuggestionOutcome records a user's response to a book suggestion
func (s *Service) SaveBookSuggestionOutcome(ctx context.Context, mediaID uint64, reason string, outcome db.SuggestionOutcome) error {
	return db.DB.AddSuggestion(mediaID, db.MediaTypeBook, reason, outcome)
}

// SaveMovieSuggestionOutcome records a user's response to a movie suggestion
func (s *Service) SaveMovieSuggestionOutcome(ctx context.Context, mediaID uint64, reason string, outcome db.SuggestionOutcome) error {
	return db.DB.AddSuggestion(mediaID, db.MediaTypeMovie, reason, outcome)
}

// SaveShowSuggestionOutcome records a user's response to a TV show suggestion
func (s *Service) SaveShowSuggestionOutcome(ctx context.Context, mediaID uint64, reason string, outcome db.SuggestionOutcome) error {
	return db.DB.AddSuggestion(mediaID, db.MediaTypeShow, reason, outcome)
}

// SaveVideoGameSuggestionOutcome records a user's response to a video game suggestion
func (s *Service) SaveVideoGameSuggestionOutcome(ctx context.Context, mediaID uint64, reason string, outcome db.SuggestionOutcome) error {
	return db.DB.AddSuggestion(mediaID, db.MediaTypeVideoGame, reason, outcome)
}

// GetTopSuggestionsForUser returns top suggestions for a user based on their preferences
func (s *Service) GetTopSuggestionsForUser(ctx context.Context, mediaType db.MediaType, limit int) ([]Suggestion, error) {
	// This is a placeholder for a more sophisticated recommendation algorithm
	// In a real implementation, this would take into account user preferences,
	// past interactions, and potentially use an LLM for personalized suggestions

	var suggestions []Suggestion

	// Set up search options for recent items
	options := db.DefaultSearchOptions()
	options.Limit = limit
	options.SortBy = "created_at"
	options.SortOrder = "DESC"

	// Get recent items of the specified type
	switch mediaType {
	case db.MediaTypeMusic:
		results, err := db.DB.SearchMusic("", options)
		if err != nil {
			return nil, err
		}

		for _, m := range results {
			suggestions = append(suggestions, Suggestion{
				MediaID:   m.ID,
				MediaType: mediaType,
				Title:     m.Title,
				Subtitle:  m.Artist,
				ImageURL:  m.AlbumArtURL,
				Reason:    "Recent addition",
				Source:    "database",
			})
		}

	case db.MediaTypeBook:
		results, err := db.DB.SearchBooks("", options)
		if err != nil {
			return nil, err
		}

		for _, b := range results {
			suggestions = append(suggestions, Suggestion{
				MediaID:   b.ID,
				MediaType: mediaType,
				Title:     b.Title,
				Subtitle:  b.Author,
				ImageURL:  b.CoverArtURL,
				Reason:    "Recent addition",
				Source:    "database",
			})
		}

	case db.MediaTypeMovie:
		results, err := db.DB.SearchMovies("", options)
		if err != nil {
			return nil, err
		}

		for _, m := range results {
			suggestions = append(suggestions, Suggestion{
				MediaID:   m.ID,
				MediaType: mediaType,
				Title:     m.Title,
				Subtitle:  m.Director,
				ImageURL:  m.PosterURL,
				Reason:    "Recent addition",
				Source:    "database",
			})
		}

	case db.MediaTypeShow:
		results, err := db.DB.SearchShows("", options)
		if err != nil {
			return nil, err
		}

		for _, sh := range results {
			suggestions = append(suggestions, Suggestion{
				MediaID:   sh.ID,
				MediaType: mediaType,
				Title:     sh.Title,
				Subtitle:  sh.Director,
				ImageURL:  sh.PosterURL,
				Reason:    "Recent addition",
				Source:    "database",
			})
		}

	case db.MediaTypeVideoGame:
		results, err := db.DB.SearchVideoGames("", options)
		if err != nil {
			return nil, err
		}

		for _, g := range results {
			suggestions = append(suggestions, Suggestion{
				MediaID:   g.ID,
				MediaType: mediaType,
				Title:     g.Title,
				Subtitle:  g.Developer,
				ImageURL:  g.CoverArtURL,
				Reason:    "Recent addition",
				Source:    "database",
			})
		}

	default:
		return nil, errors.New("invalid media type")
	}

	return suggestions, nil
}

// SearchForExternalSuggestions searches external sources for suggestions
func (s *Service) SearchForExternalSuggestions(ctx context.Context, query string, mediaType db.MediaType, limit int) ([]Suggestion, error) {
	// Convert media type to wikidata's format
	wdMediaType := wikidata.MediaType(string(mediaType))

	// First try Wikidata
	wdResults, err := s.wikidataClient.SearchEntities(ctx, query, wdMediaType, "en")

	// If Wikidata fails, try Wikipedia
	if err != nil || len(wdResults) == 0 {
		// Enhance query with media type
		enhancedQuery := query
		switch mediaType {
		case db.MediaTypeMusic:
			enhancedQuery += " music OR song OR album"
		case db.MediaTypeBook:
			enhancedQuery += " book OR novel"
		case db.MediaTypeMovie:
			enhancedQuery += " film OR movie"
		case db.MediaTypeShow:
			enhancedQuery += " TV series OR television show"
		case db.MediaTypeVideoGame:
			enhancedQuery += " video game"
		}

		wpResults, err := s.wikipediaClient.Search(ctx, enhancedQuery, limit)
		if err != nil {
			return nil, err
		}

		var suggestions []Suggestion
		for _, result := range wpResults {
			// Get more details from Wikipedia
			pageInfo, err := s.wikipediaClient.GetPageInfo(ctx, result.PageID)
			if err != nil {
				continue
			}

			// Extract creator info based on media type
			var subtitle string
			switch mediaType {
			case db.MediaTypeMusic:
				if artist, ok := pageInfo.InfoboxData["artist"]; ok {
					subtitle = artist
				}
			case db.MediaTypeBook:
				if author, ok := pageInfo.InfoboxData["author"]; ok {
					subtitle = author
				}
			case db.MediaTypeMovie, db.MediaTypeShow:
				if director, ok := pageInfo.InfoboxData["director"]; ok {
					subtitle = director
				}
			case db.MediaTypeVideoGame:
				if developer, ok := pageInfo.InfoboxData["developer"]; ok {
					subtitle = developer
				}
			}

			suggestions = append(suggestions, Suggestion{
				MediaID:   -1, // Not in database yet
				MediaType: mediaType,
				Title:     pageInfo.Title,
				Subtitle:  subtitle,
				ImageURL:  pageInfo.ImageURL,
				Reason:    fmt.Sprintf("Found by searching for: %s", query),
				Source:    "wikipedia",
			})

			if len(suggestions) >= limit {
				break
			}
		}

		return suggestions, nil
	}

	// Process Wikidata results
	var suggestions []Suggestion
	for _, result := range wdResults {
		info, err := s.wikidataClient.GetMediaInfo(ctx, result.ID, wdMediaType)
		if err != nil {
			continue
		}

		var subtitle string
		switch mediaType {
		case db.MediaTypeMusic:
			subtitle = info.Artist
		case db.MediaTypeBook:
			subtitle = info.Author
		case db.MediaTypeMovie, db.MediaTypeShow:
			subtitle = info.Director
		case db.MediaTypeVideoGame:
			subtitle = info.Developer
		}

		suggestions = append(suggestions, Suggestion{
			MediaID:   -1, // Not in database yet
			MediaType: mediaType,
			Title:     info.Title,
			Subtitle:  subtitle,
			ImageURL:  info.ImageURL,
			Reason:    fmt.Sprintf("Found by searching for: %s", query),
			Source:    "wikidata",
		})

		if len(suggestions) >= limit {
			break
		}
	}

	return suggestions, nil
}

// SaveSuggestionToDatabase saves an external suggestion to the local database
func (s *Service) SaveSuggestionToDatabase(ctx context.Context, suggestion Suggestion) (uint64, error) {
	var mediaID uint64

	// Insert into the appropriate table based on media type
	switch suggestion.MediaType {
	case db.MediaTypeMusic:
		music := &db.Music{
			Title:       suggestion.Title,
			Artist:      suggestion.Subtitle,
			AlbumArtURL: suggestion.ImageURL,
			IsWatchlist: true,
		}

		if err := db.DB.AddMusic(music); err != nil {
			return 0, err
		}
		mediaID = music.ID

	case db.MediaTypeBook:
		book := &db.Book{
			Title:       suggestion.Title,
			Author:      suggestion.Subtitle,
			CoverArtURL: suggestion.ImageURL,
			IsWatchlist: true,
		}

		if err := db.DB.AddBook(book); err != nil {
			return 0, err
		}
		mediaID = book.ID

	case db.MediaTypeMovie:
		movie := &db.Movie{
			Title:       suggestion.Title,
			Director:    suggestion.Subtitle,
			PosterURL:   suggestion.ImageURL,
			IsWatchlist: true,
		}

		if err := db.DB.AddMovie(movie); err != nil {
			return 0, err
		}
		mediaID = movie.ID

	case db.MediaTypeShow:
		show := &db.Show{
			Title:       suggestion.Title,
			Director:    suggestion.Subtitle,
			PosterURL:   suggestion.ImageURL,
			IsWatchlist: true,
		}

		if err := db.DB.AddShow(show); err != nil {
			return 0, err
		}
		mediaID = show.ID

	case db.MediaTypeVideoGame:
		game := &db.VideoGame{
			Title:       suggestion.Title,
			Developer:   suggestion.Subtitle,
			CoverArtURL: suggestion.ImageURL,
			IsWatchlist: true,
		}

		if err := db.DB.AddVideoGame(game); err != nil {
			return 0, err
		}
		mediaID = game.ID

	default:
		return 0, errors.New("invalid media type")
	}

	// Also record this as a suggestion with the outcome "added"
	if err := db.DB.AddSuggestion(mediaID, suggestion.MediaType, suggestion.Reason, db.OutcomeAdded); err != nil {
		return 0, err
	}

	return mediaID, nil
}
