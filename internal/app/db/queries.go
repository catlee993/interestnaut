package db

import (
	"database/sql"
	"fmt"
	"strings"
	"time"
	"context"
)

// SearchOptions contains options for filtering and pagination
type SearchOptions struct {
	Limit      int
	Offset     int
	SortBy     string
	SortOrder  string // "ASC" or "DESC"
	OnlyFavorites bool
	OnlyWatchlist bool
}

// DefaultSearchOptions returns default search options
func DefaultSearchOptions() SearchOptions {
	return SearchOptions{
		Limit:     50,
		Offset:    0,
		SortBy:    "title",
		SortOrder: "ASC",
	}
}

// SearchMusic searches for music with the given term
func (db *SqliteDatabase) SearchMusic(searchTerm string, options SearchOptions) ([]*Music, error) {
	// Build the query with proper sorting and filtering
	whereClause := "WHERE (title LIKE ? OR artist LIKE ? OR album LIKE ?)"
	if options.OnlyFavorites {
		whereClause += " AND is_favorite = 1"
	}
	if options.OnlyWatchlist {
		whereClause += " AND is_watchlist = 1"
	}
	
	// Validate sort column to prevent SQL injection
	validSortColumns := map[string]bool{
		"id": true, "title": true, "artist": true, "album": true, 
		"created_at": true, "updated_at": true,
	}
	
	sortBy := "title"
	if validSortColumns[options.SortBy] {
		sortBy = options.SortBy
	}
	
	// Validate sort order to prevent SQL injection
	sortOrder := "ASC"
	if strings.ToUpper(options.SortOrder) == "DESC" {
		sortOrder = "DESC"
	}
	
	query := fmt.Sprintf(`
		SELECT id, title, artist, album, album_art_url, is_favorite, is_watchlist, created_at, updated_at
		FROM music
		%s
		ORDER BY %s %s
		LIMIT ? OFFSET ?
	`, whereClause, sortBy, sortOrder)
	
	// Use ? for all parameters including LIKE patterns
	searchPattern := "%" + searchTerm + "%"
	
	rows, err := db.db.Query(
		query,
		searchPattern, searchPattern, searchPattern,
		options.Limit, options.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	defer rows.Close()
	
	var results []*Music
	var createdAt, updatedAt string
	
	for rows.Next() {
		music := &Music{}
		err := rows.Scan(
			&music.ID,
			&music.Title,
			&music.Artist,
			&music.Album,
			&music.AlbumArtURL,
			&music.IsFavorite,
			&music.IsWatchlist,
			&createdAt,
			&updatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		// Parse timestamps
		if music.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		if music.UpdatedAt, err = time.Parse(time.RFC3339, updatedAt); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		results = append(results, music)
	}
	
	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	return results, nil
}

// GetFavoriteMusic retrieves the user's favorite music
func (db *SqliteDatabase) GetFavoriteMusic(options SearchOptions) ([]*Music, error) {
	options.OnlyFavorites = true
	return db.SearchMusic("", options)
}

// GetWatchlistMusic retrieves the user's watchlist music
func (db *SqliteDatabase) GetWatchlistMusic(options SearchOptions) ([]*Music, error) {
	options.OnlyWatchlist = true
	return db.SearchMusic("", options)
}

// SearchBooks searches for books with the given term
func (db *SqliteDatabase) SearchBooks(searchTerm string, options SearchOptions) ([]*Book, error) {
	// Build the query with proper sorting and filtering
	whereClause := "WHERE (title LIKE ? OR author LIKE ?)"
	if options.OnlyFavorites {
		whereClause += " AND is_favorite = 1"
	}
	if options.OnlyWatchlist {
		whereClause += " AND is_watchlist = 1"
	}
	
	// Validate sort column to prevent SQL injection
	validSortColumns := map[string]bool{
		"id": true, "title": true, "author": true, 
		"created_at": true, "updated_at": true,
	}
	
	sortBy := "title"
	if validSortColumns[options.SortBy] {
		sortBy = options.SortBy
	}
	
	// Validate sort order
	sortOrder := "ASC"
	if strings.ToUpper(options.SortOrder) == "DESC" {
		sortOrder = "DESC"
	}
	
	query := fmt.Sprintf(`
		SELECT id, title, author, cover_art_url, is_favorite, is_watchlist, created_at, updated_at
		FROM books
		%s
		ORDER BY %s %s
		LIMIT ? OFFSET ?
	`, whereClause, sortBy, sortOrder)
	
	// Use ? for all parameters including LIKE patterns
	searchPattern := "%" + searchTerm + "%"
	
	rows, err := db.db.Query(
		query, 
		searchPattern, searchPattern, 
		options.Limit, options.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	defer rows.Close()
	
	var results []*Book
	var createdAt, updatedAt string
	
	for rows.Next() {
		book := &Book{}
		err := rows.Scan(
			&book.ID,
			&book.Title,
			&book.Author,
			&book.CoverArtURL,
			&book.IsFavorite,
			&book.IsWatchlist,
			&createdAt,
			&updatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		// Parse timestamps
		if book.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		if book.UpdatedAt, err = time.Parse(time.RFC3339, updatedAt); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		results = append(results, book)
	}
	
	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	return results, nil
}

// GetFavoriteBooks retrieves the user's favorite books
func (db *SqliteDatabase) GetFavoriteBooks(options SearchOptions) ([]*Book, error) {
	options.OnlyFavorites = true
	return db.SearchBooks("", options)
}

// SearchMovies searches for movies with the given term
func (db *SqliteDatabase) SearchMovies(searchTerm string, options SearchOptions) ([]*Movie, error) {
	// Build the query with proper sorting and filtering
	whereClause := "WHERE (title LIKE ? OR director LIKE ? OR writer LIKE ?)"
	if options.OnlyFavorites {
		whereClause += " AND is_favorite = 1"
	}
	if options.OnlyWatchlist {
		whereClause += " AND is_watchlist = 1"
	}
	
	// Validate sort column to prevent SQL injection
	validSortColumns := map[string]bool{
		"id": true, "title": true, "director": true, "writer": true,
		"created_at": true, "updated_at": true,
	}
	
	sortBy := "title"
	if validSortColumns[options.SortBy] {
		sortBy = options.SortBy
	}
	
	// Validate sort order
	sortOrder := "ASC"
	if strings.ToUpper(options.SortOrder) == "DESC" {
		sortOrder = "DESC"
	}
	
	query := fmt.Sprintf(`
		SELECT id, title, director, writer, poster_url, is_favorite, is_watchlist, created_at, updated_at
		FROM movies
		%s
		ORDER BY %s %s
		LIMIT ? OFFSET ?
	`, whereClause, sortBy, sortOrder)
	
	// Use ? for all parameters including LIKE patterns
	searchPattern := "%" + searchTerm + "%"
	
	rows, err := db.db.Query(
		query, 
		searchPattern, searchPattern, searchPattern, 
		options.Limit, options.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	defer rows.Close()
	
	var results []*Movie
	var createdAt, updatedAt string
	
	for rows.Next() {
		movie := &Movie{}
		err := rows.Scan(
			&movie.ID,
			&movie.Title,
			&movie.Director,
			&movie.Writer,
			&movie.PosterURL,
			&movie.IsFavorite,
			&movie.IsWatchlist,
			&createdAt,
			&updatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		// Parse timestamps
		if movie.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		if movie.UpdatedAt, err = time.Parse(time.RFC3339, updatedAt); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		results = append(results, movie)
	}
	
	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	return results, nil
}

// SearchShows searches for TV shows with the given term
func (db *SqliteDatabase) SearchShows(searchTerm string, options SearchOptions) ([]*Show, error) {
	// Build the query with proper sorting and filtering
	whereClause := "WHERE (title LIKE ? OR director LIKE ? OR writer LIKE ?)"
	if options.OnlyFavorites {
		whereClause += " AND is_favorite = 1"
	}
	if options.OnlyWatchlist {
		whereClause += " AND is_watchlist = 1"
	}
	
	// Validate sort column to prevent SQL injection
	validSortColumns := map[string]bool{
		"id": true, "title": true, "director": true, "writer": true,
		"created_at": true, "updated_at": true,
	}
	
	sortBy := "title"
	if validSortColumns[options.SortBy] {
		sortBy = options.SortBy
	}
	
	// Validate sort order
	sortOrder := "ASC"
	if strings.ToUpper(options.SortOrder) == "DESC" {
		sortOrder = "DESC"
	}
	
	query := fmt.Sprintf(`
		SELECT id, title, director, writer, poster_url, is_favorite, is_watchlist, created_at, updated_at
		FROM shows
		%s
		ORDER BY %s %s
		LIMIT ? OFFSET ?
	`, whereClause, sortBy, sortOrder)
	
	// Use ? for all parameters including LIKE patterns
	searchPattern := "%" + searchTerm + "%"
	
	rows, err := db.db.Query(
		query, 
		searchPattern, searchPattern, searchPattern, 
		options.Limit, options.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	defer rows.Close()
	
	var results []*Show
	var createdAt, updatedAt string
	
	for rows.Next() {
		show := &Show{}
		err := rows.Scan(
			&show.ID,
			&show.Title,
			&show.Director,
			&show.Writer,
			&show.PosterURL,
			&show.IsFavorite,
			&show.IsWatchlist,
			&createdAt,
			&updatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		// Parse timestamps
		if show.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		if show.UpdatedAt, err = time.Parse(time.RFC3339, updatedAt); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		results = append(results, show)
	}
	
	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	return results, nil
}

// SearchVideoGames searches for video games with the given term
func (db *SqliteDatabase) SearchVideoGames(searchTerm string, options SearchOptions) ([]*VideoGame, error) {
	// Build the query with proper sorting and filtering
	whereClause := "WHERE (title LIKE ? OR developer LIKE ?)"
	if options.OnlyFavorites {
		whereClause += " AND is_favorite = 1"
	}
	if options.OnlyWatchlist {
		whereClause += " AND is_watchlist = 1"
	}
	
	// Validate sort column to prevent SQL injection
	validSortColumns := map[string]bool{
		"id": true, "title": true, "developer": true,
		"created_at": true, "updated_at": true,
	}
	
	sortBy := "title"
	if validSortColumns[options.SortBy] {
		sortBy = options.SortBy
	}
	
	// Validate sort order
	sortOrder := "ASC"
	if strings.ToUpper(options.SortOrder) == "DESC" {
		sortOrder = "DESC"
	}
	
	query := fmt.Sprintf(`
		SELECT id, title, developer, cover_art_url, is_favorite, is_watchlist, created_at, updated_at
		FROM video_games
		%s
		ORDER BY %s %s
		LIMIT ? OFFSET ?
	`, whereClause, sortBy, sortOrder)
	
	// Use ? for all parameters including LIKE patterns
	searchPattern := "%" + searchTerm + "%"
	
	rows, err := db.db.Query(
		query, 
		searchPattern, searchPattern, 
		options.Limit, options.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	defer rows.Close()
	
	var results []*VideoGame
	var createdAt, updatedAt string
	
	for rows.Next() {
		videoGame := &VideoGame{}
		err := rows.Scan(
			&videoGame.ID,
			&videoGame.Title,
			&videoGame.Developer,
			&videoGame.CoverArtURL,
			&videoGame.IsFavorite,
			&videoGame.IsWatchlist,
			&createdAt,
			&updatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		// Parse timestamps
		if videoGame.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		if videoGame.UpdatedAt, err = time.Parse(time.RFC3339, updatedAt); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		// Get the platforms for each game
		platformsQuery := `
		SELECT name FROM video_game_platforms
		WHERE video_game_id = ?
		ORDER BY name
		`
		
		platformRows, err := db.db.Query(platformsQuery, videoGame.ID)
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		videoGame.Platforms = []string{}
		for platformRows.Next() {
			var platform string
			if err := platformRows.Scan(&platform); err != nil {
				platformRows.Close()
				return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
			}
			videoGame.Platforms = append(videoGame.Platforms, platform)
		}
		platformRows.Close()
		
		results = append(results, videoGame)
	}
	
	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	return results, nil
}

// GetSuggestionsByMedia gets suggestions for a specific media item
func (db *SqliteDatabase) GetSuggestionsByMedia(mediaID uint64, mediaType MediaType) ([]*Suggestion, error) {
	var tableName string
	var idColumn string
	
	switch mediaType {
	case MediaTypeMusic:
		tableName = "music_suggestions"
		idColumn = "music_id"
	case MediaTypeBook:
		tableName = "book_suggestions"
		idColumn = "book_id"
	case MediaTypeMovie:
		tableName = "movie_suggestions"
		idColumn = "movie_id"
	case MediaTypeShow:
		tableName = "show_suggestions"
		idColumn = "show_id"
	case MediaTypeVideoGame:
		tableName = "video_game_suggestions"
		idColumn = "video_game_id"
	default:
		return nil, fmt.Errorf("%w: invalid media type", ErrInvalidInput)
	}
	
	query := fmt.Sprintf(`
		SELECT id, %s, reason, outcome, created_at
		FROM %s
		WHERE %s = ?
		ORDER BY created_at DESC
	`, idColumn, tableName, idColumn)
	
	rows, err := db.db.Query(query, mediaID)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	defer rows.Close()
	
	var suggestions []*Suggestion
	var createdAt string
	
	for rows.Next() {
		suggestion := &Suggestion{}
		var outcomeStr string
		
		if err := rows.Scan(&suggestion.ID, &suggestion.MediaID, &suggestion.Reason, &outcomeStr, &createdAt); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		suggestion.MediaType = mediaType
		suggestion.Outcome = SuggestionOutcome(outcomeStr)
		if suggestion.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		suggestions = append(suggestions, suggestion)
	}
	
	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	return suggestions, nil
}

// GetAllSuggestions gets all suggestions across all media types
func (db *SqliteDatabase) GetAllSuggestions(options SearchOptions) ([]*Suggestion, error) {
	var suggestions []*Suggestion
	
	// We need to query each suggestions table separately and combine the results
	mediaTypes := []MediaType{
		MediaTypeMusic,
		MediaTypeBook,
		MediaTypeMovie,
		MediaTypeShow,
		MediaTypeVideoGame,
	}
	
	for _, mediaType := range mediaTypes {
		var tableName string
		var idColumn string
		
		switch mediaType {
		case MediaTypeMusic:
			tableName = "music_suggestions"
			idColumn = "music_id"
		case MediaTypeBook:
			tableName = "book_suggestions"
			idColumn = "book_id"
		case MediaTypeMovie:
			tableName = "movie_suggestions"
			idColumn = "movie_id"
		case MediaTypeShow:
			tableName = "show_suggestions"
			idColumn = "show_id"
		case MediaTypeVideoGame:
			tableName = "video_game_suggestions"
			idColumn = "video_game_id"
		}
		
		query := fmt.Sprintf(`
		SELECT id, %s, reason, outcome, created_at
		FROM %s
		ORDER BY created_at DESC
		LIMIT ? OFFSET ?
		`, idColumn, tableName)
		
		rows, err := db.db.Query(query, options.Limit, options.Offset)
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		var createdAt string
		
		for rows.Next() {
			suggestion := &Suggestion{}
			var outcomeStr string
			
			if err := rows.Scan(&suggestion.ID, &suggestion.MediaID, &suggestion.Reason, &outcomeStr, &createdAt); err != nil {
				rows.Close()
				return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
			}
			
			suggestion.MediaType = mediaType
			suggestion.Outcome = SuggestionOutcome(outcomeStr)
			if suggestion.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
				rows.Close()
				return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
			}
			
			suggestions = append(suggestions, suggestion)
		}
		rows.Close()
	}
	
	// TODO: Sort the combined results by creation date if needed
	
	return suggestions, nil
}

// GetAllConstraints retrieves all constraints from the database
func (db *SqliteDatabase) GetAllConstraints() ([]*Constraint, error) {
	query := `
		SELECT id, rule, media, created_at, updated_at
		FROM constraints
		ORDER BY id
	`
	
	rows, err := db.db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	defer rows.Close()
	
	var constraints []*Constraint
	var createdAt, updatedAt string
	
	for rows.Next() {
		constraint := &Constraint{}
		var mediaTypeStr string
		
		if err := rows.Scan(&constraint.ID, &constraint.Rule, &mediaTypeStr, &createdAt, &updatedAt); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		constraint.Media = MediaType(mediaTypeStr)
		if constraint.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		if constraint.UpdatedAt, err = time.Parse(time.RFC3339, updatedAt); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		constraints = append(constraints, constraint)
	}
	
	return constraints, nil
}

// CountItems counts the number of items in a given table with optional filtering
func (db *SqliteDatabase) CountItems(tableName string, onlyFavorites, onlyWatchlist bool) (int, error) {
	whereClause := ""
	if onlyFavorites && onlyWatchlist {
		whereClause = "WHERE is_favorite = 1 AND is_watchlist = 1"
	} else if onlyFavorites {
		whereClause = "WHERE is_favorite = 1"
	} else if onlyWatchlist {
		whereClause = "WHERE is_watchlist = 1"
	}
	
	query := fmt.Sprintf("SELECT COUNT(*) FROM %s %s", tableName, whereClause)
	
	var count int
	err := db.db.QueryRow(query).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	return count, nil
}

// BeginTx begins a transaction
func (db *SqliteDatabase) BeginTx(ctx context.Context, opts *sql.TxOptions) (*sql.Tx, error) {
	return db.db.BeginTx(ctx, opts)
}

// GetSchemaVersion retrieves the current schema version
func (db *SqliteDatabase) GetSchemaVersion() (int, error) {
	var version int
	err := db.db.QueryRow("SELECT version FROM schema_version ORDER BY id DESC LIMIT 1").Scan(&version)
	if err != nil {
		if err == sql.ErrNoRows {
			return 0, nil // No schema version found, assume 0
		}
		return 0, err
	}
	return version, nil
}
