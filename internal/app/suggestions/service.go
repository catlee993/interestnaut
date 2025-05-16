package suggestions

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"interestnaut/internal/app/db"
	"interestnaut/internal/app/wikidata"
	"interestnaut/internal/app/wikipedia"
)

// Suggestion represents a media suggestion
type Suggestion struct {
	MediaID   int64
	MediaType db.MediaType
	Title     string
	Subtitle  string // Artist, author, developer, etc.
	ImageURL  string
	Reason    string
	Source    string // "wikidata", "wikipedia", "llm", etc.
}

// Service provides media suggestions from multiple sources
type Service struct {
	db              *sql.DB
	wikidataClient  *wikidata.Client
	wikipediaClient *wikipedia.Client
	llmProvider     LLMProvider // Will be set later
	userAgent       string
}

// NewService creates a new suggestion service
func NewService(db *sql.DB, userAgent string) *Service {
	if userAgent == "" {
		userAgent = "Interestnaut Media Tracker/1.0"
	}

	return &Service{
		db:              db,
		wikidataClient:  wikidata.NewClient(userAgent),
		wikipediaClient: wikipedia.NewClient(userAgent),
		userAgent:       userAgent,
	}
}

// SetLLMProvider sets the LLM provider for generating suggestions
func (s *Service) SetLLMProvider(provider LLMProvider) {
	s.llmProvider = provider
}

// GetSuggestions returns a list of suggestions based on the provided parameters
func (s *Service) GetSuggestions(ctx context.Context, mediaType db.MediaType, basedOnID int64, limit int) ([]Suggestion, error) {
	// Start with an empty slice of suggestions
	var suggestions []Suggestion

	// Try to get suggestions from different sources
	// First, try to get suggestions from our database based on past user preferences
	dbSuggestions, err := s.getDBSuggestions(ctx, mediaType, basedOnID, limit)
	if err == nil && len(dbSuggestions) > 0 {
		suggestions = append(suggestions, dbSuggestions...)
	}

	// If we don't have enough suggestions, try Wikidata
	if len(suggestions) < limit {
		wdSuggestions, err := s.getWikidataSuggestions(ctx, mediaType, basedOnID, limit-len(suggestions))
		if err == nil && len(wdSuggestions) > 0 {
			suggestions = append(suggestions, wdSuggestions...)
		}
	}

	// If we still don't have enough suggestions, try an LLM (to be implemented)
	// This is a placeholder for future LLM integration
	if len(suggestions) < limit && s.llmProvider != nil {
		llmSuggestions, err := s.getLLMSuggestions(ctx, mediaType, basedOnID, limit-len(suggestions))
		if err == nil && len(llmSuggestions) > 0 {
			suggestions = append(suggestions, llmSuggestions...)
		}
	}

	return suggestions, nil
}

// getDBSuggestions gets suggestions from our local database based on similar items
func (s *Service) getDBSuggestions(ctx context.Context, mediaType db.MediaType, basedOnID int64, limit int) ([]Suggestion, error) {
	var suggestions []Suggestion

	// If there's no specific item to base suggestions on, return empty
	if basedOnID <= 0 {
		return suggestions, nil
	}

	// Set up search options with limit
	options := db.DefaultSearchOptions()
	options.Limit = limit

	// Depending on the media type, get similar items
	switch mediaType {
	case db.MediaTypeMusic:
		// First, get the music item to base suggestions on
		music, err := db.GetMusic(s.db, basedOnID)
		if err != nil {
			return nil, err
		}

		// Search for music by the same artist
		searchResults, err := db.SearchMusic(s.db, music.Artist, options)
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
				MediaType: mediaType,
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

	case db.MediaTypeBook:
		// First, get the book to base suggestions on
		book, err := db.GetBook(s.db, basedOnID)
		if err != nil {
			return nil, err
		}

		// Search for books by the same author
		searchResults, err := db.SearchBooks(s.db, book.Author, options)
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
				MediaType: mediaType,
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

	case db.MediaTypeMovie:
		// First, get the movie to base suggestions on
		movie, err := db.GetMovie(s.db, basedOnID)
		if err != nil {
			return nil, err
		}

		// Search for movies by the same director
		searchResults, err := db.SearchMovies(s.db, movie.Director, options)
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
				MediaType: mediaType,
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

	case db.MediaTypeShow:
		// First, get the show to base suggestions on
		show, err := db.GetShow(s.db, basedOnID)
		if err != nil {
			return nil, err
		}

		// Search for shows by the same director
		searchResults, err := db.SearchShows(s.db, show.Director, options)
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
				MediaType: mediaType,
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

	case db.MediaTypeVideoGame:
		// First, get the game to base suggestions on
		game, err := db.GetVideoGame(s.db, basedOnID)
		if err != nil {
			return nil, err
		}

		// Search for games by the same developer
		searchResults, err := db.SearchVideoGames(s.db, game.Developer, options)
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
				MediaType: mediaType,
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
	}

	return suggestions, nil
}

// getWikidataSuggestions gets suggestions from Wikidata based on related items
func (s *Service) getWikidataSuggestions(ctx context.Context, mediaType db.MediaType, basedOnID int64, limit int) ([]Suggestion, error) {
	var suggestions []Suggestion

	// If there's no specific item to base suggestions on, use a generic search
	if basedOnID <= 0 {
		return suggestions, nil
	}

	// First, we need to get the item's title and creator to use in our search
	var title, creator string
	var query string

	switch mediaType {
	case db.MediaTypeMusic:
		music, err := db.GetMusic(s.db, basedOnID)
		if err != nil {
			return nil, err
		}
		title = music.Title
		creator = music.Artist
		query = fmt.Sprintf("%s %s", title, creator)

	case db.MediaTypeBook:
		book, err := db.GetBook(s.db, basedOnID)
		if err != nil {
			return nil, err
		}
		title = book.Title
		creator = book.Author
		query = fmt.Sprintf("%s %s", title, creator)

	case db.MediaTypeMovie:
		movie, err := db.GetMovie(s.db, basedOnID)
		if err != nil {
			return nil, err
		}
		title = movie.Title
		creator = movie.Director
		query = fmt.Sprintf("%s %s", title, creator)

	case db.MediaTypeShow:
		show, err := db.GetShow(s.db, basedOnID)
		if err != nil {
			return nil, err
		}
		title = show.Title
		creator = show.Director
		query = fmt.Sprintf("%s %s", title, creator)

	case db.MediaTypeVideoGame:
		game, err := db.GetVideoGame(s.db, basedOnID)
		if err != nil {
			return nil, err
		}
		title = game.Title
		creator = game.Developer
		query = fmt.Sprintf("%s %s", title, creator)
	}

	// Convert media type to wikidata's format
	wdMediaType := wikidata.MediaType(string(mediaType))

	// Use Wikidata to find similar items
	results, err := s.wikidataClient.SearchEntities(ctx, query, wdMediaType, "en")
	if err != nil {
		return nil, err
	}

	// Convert the first 'limit' results to suggestions
	count := 0
	for _, result := range results {
		// Skip if this appears to be the same item we're basing suggestions on
		if result.Label == title {
			continue
		}

		// Get detailed info for this item
		info, err := s.wikidataClient.GetMediaInfo(ctx, result.ID, wdMediaType)
		if err != nil {
			continue
		}

		var subtitle string
		var reason string

		switch mediaType {
		case db.MediaTypeMusic:
			subtitle = info.Artist
			reason = fmt.Sprintf("Similar to %s by %s", title, creator)
		case db.MediaTypeBook:
			subtitle = info.Author
			reason = fmt.Sprintf("Similar to %s by %s", title, creator)
		case db.MediaTypeMovie:
			subtitle = info.Director
			reason = fmt.Sprintf("Similar to %s by %s", title, creator)
		case db.MediaTypeShow:
			subtitle = info.Director
			reason = fmt.Sprintf("Similar to %s by %s", title, creator)
		case db.MediaTypeVideoGame:
			subtitle = info.Developer
			reason = fmt.Sprintf("Similar to %s by %s", title, creator)
		}

		// Create a suggestion
		suggestion := Suggestion{
			MediaID:   -1, // Not in database yet
			MediaType: mediaType,
			Title:     info.Title,
			Subtitle:  subtitle,
			ImageURL:  info.ImageURL,
			Reason:    reason,
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
func (s *Service) getLLMSuggestions(ctx context.Context, mediaType db.MediaType, basedOnID int64, limit int) ([]Suggestion, error) {
	// If no LLM provider is configured, return empty
	if s.llmProvider == nil {
		return nil, errors.New("no LLM provider configured")
	}

	// If there's no specific item to base suggestions on, return empty
	if basedOnID <= 0 {
		return nil, errors.New("basedOnID is required for LLM suggestions")
	}

	// Gather information about the item to base suggestions on
	basedOnInfo := make(map[string]string)

	// Query the database for information about the base item
	switch mediaType {
	case db.MediaTypeMusic:
		music, err := db.GetMusic(s.db, basedOnID)
		if err != nil {
			return nil, err
		}
		basedOnInfo["title"] = music.Title
		basedOnInfo["artist"] = music.Artist
		basedOnInfo["album"] = music.Album

	case db.MediaTypeBook:
		book, err := db.GetBook(s.db, basedOnID)
		if err != nil {
			return nil, err
		}
		basedOnInfo["title"] = book.Title
		basedOnInfo["author"] = book.Author

	case db.MediaTypeMovie:
		movie, err := db.GetMovie(s.db, basedOnID)
		if err != nil {
			return nil, err
		}
		basedOnInfo["title"] = movie.Title
		basedOnInfo["director"] = movie.Director

	case db.MediaTypeShow:
		show, err := db.GetShow(s.db, basedOnID)
		if err != nil {
			return nil, err
		}
		basedOnInfo["title"] = show.Title
		basedOnInfo["director"] = show.Director

	case db.MediaTypeVideoGame:
		game, err := db.GetVideoGame(s.db, basedOnID)
		if err != nil {
			return nil, err
		}
		basedOnInfo["title"] = game.Title
		basedOnInfo["developer"] = game.Developer
	}

	// Call the LLM provider to generate suggestions
	return s.llmProvider.GenerateSuggestions(ctx, mediaType, basedOnInfo, limit)
}

// SaveSuggestionOutcome records a user's response to a suggestion
func (s *Service) SaveSuggestionOutcome(ctx context.Context, mediaType db.MediaType, mediaID int64, reason string, outcome db.SuggestionOutcome) error {
	// Use the AddSuggestion function from the db package
	return db.AddSuggestion(s.db, mediaID, mediaType, reason, outcome)
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
		results, err := db.SearchMusic(s.db, "", options)
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
		results, err := db.SearchBooks(s.db, "", options)
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
		results, err := db.SearchMovies(s.db, "", options)
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
		results, err := db.SearchShows(s.db, "", options)
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
		results, err := db.SearchVideoGames(s.db, "", options)
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
func (s *Service) SaveSuggestionToDatabase(ctx context.Context, suggestion Suggestion) (int64, error) {
	// Start a transaction
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	var mediaID int64

	// Insert into the appropriate table based on media type
	switch suggestion.MediaType {
	case db.MediaTypeMusic:
		music := &db.Music{
			Title:       suggestion.Title,
			Artist:      suggestion.Subtitle,
			AlbumArtURL: suggestion.ImageURL,
			IsWatchlist: true,
		}

		if err := db.AddMusic(s.db, music); err != nil {
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

		if err := db.AddBook(s.db, book); err != nil {
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

		if err := db.AddMovie(s.db, movie); err != nil {
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

		if err := db.AddShow(s.db, show); err != nil {
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

		if err := db.AddVideoGame(s.db, game); err != nil {
			return 0, err
		}
		mediaID = game.ID

	default:
		return 0, errors.New("invalid media type")
	}

	// Also record this as a suggestion with the outcome "added"
	if err := db.AddSuggestion(s.db, mediaID, suggestion.MediaType, suggestion.Reason, db.OutcomeAdded); err != nil {
		return 0, err
	}

	// Commit the transaction
	if err := tx.Commit(); err != nil {
		return 0, err
	}

	return mediaID, nil
}
