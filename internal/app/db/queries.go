package db

import (
	"database/sql"
	"fmt"
	"strings"
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
func SearchMusic(db *sql.DB, searchTerm string, options SearchOptions) ([]*Music, error) {
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
	
	// Use % for wildcard search
	searchPattern := "%" + searchTerm + "%"
	
	rows, err := db.Query(
		query, 
		searchPattern, searchPattern, searchPattern, 
		options.Limit, options.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	defer rows.Close()
	
	var results []*Music
	for rows.Next() {
		var m Music
		if err := rows.Scan(
			&m.ID, &m.Title, &m.Artist, &m.Album, &m.AlbumArtURL,
			&m.IsFavorite, &m.IsWatchlist, &m.CreatedAt, &m.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		results = append(results, &m)
	}
	
	return results, nil
}

// GetFavoriteMusic retrieves the user's favorite music
func GetFavoriteMusic(db *sql.DB, options SearchOptions) ([]*Music, error) {
	options.OnlyFavorites = true
	return SearchMusic(db, "", options)
}

// GetWatchlistMusic retrieves the user's watchlist music
func GetWatchlistMusic(db *sql.DB, options SearchOptions) ([]*Music, error) {
	options.OnlyWatchlist = true
	return SearchMusic(db, "", options)
}

// SearchBooks searches for books with the given term
func SearchBooks(db *sql.DB, searchTerm string, options SearchOptions) ([]*Book, error) {
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
	
	// Use % for wildcard search
	searchPattern := "%" + searchTerm + "%"
	
	rows, err := db.Query(
		query, 
		searchPattern, searchPattern, 
		options.Limit, options.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	defer rows.Close()
	
	var results []*Book
	for rows.Next() {
		var b Book
		if err := rows.Scan(
			&b.ID, &b.Title, &b.Author, &b.CoverArtURL,
			&b.IsFavorite, &b.IsWatchlist, &b.CreatedAt, &b.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		results = append(results, &b)
	}
	
	return results, nil
}

// GetFavoriteBooks retrieves the user's favorite books
func GetFavoriteBooks(db *sql.DB, options SearchOptions) ([]*Book, error) {
	options.OnlyFavorites = true
	return SearchBooks(db, "", options)
}

// SearchMovies searches for movies with the given term
func SearchMovies(db *sql.DB, searchTerm string, options SearchOptions) ([]*Movie, error) {
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
	
	// Use % for wildcard search
	searchPattern := "%" + searchTerm + "%"
	
	rows, err := db.Query(
		query, 
		searchPattern, searchPattern, searchPattern, 
		options.Limit, options.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	defer rows.Close()
	
	var results []*Movie
	for rows.Next() {
		var m Movie
		if err := rows.Scan(
			&m.ID, &m.Title, &m.Director, &m.Writer, &m.PosterURL,
			&m.IsFavorite, &m.IsWatchlist, &m.CreatedAt, &m.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		results = append(results, &m)
	}
	
	return results, nil
}

// SearchShows searches for TV shows with the given term
func SearchShows(db *sql.DB, searchTerm string, options SearchOptions) ([]*Show, error) {
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
	
	// Use % for wildcard search
	searchPattern := "%" + searchTerm + "%"
	
	rows, err := db.Query(
		query, 
		searchPattern, searchPattern, searchPattern, 
		options.Limit, options.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	defer rows.Close()
	
	var results []*Show
	for rows.Next() {
		var s Show
		if err := rows.Scan(
			&s.ID, &s.Title, &s.Director, &s.Writer, &s.PosterURL,
			&s.IsFavorite, &s.IsWatchlist, &s.CreatedAt, &s.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		results = append(results, &s)
	}
	
	return results, nil
}

// SearchVideoGames searches for video games with the given term
func SearchVideoGames(db *sql.DB, searchTerm string, options SearchOptions) ([]*VideoGame, error) {
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
	
	// Use % for wildcard search
	searchPattern := "%" + searchTerm + "%"
	
	rows, err := db.Query(
		query, 
		searchPattern, searchPattern, 
		options.Limit, options.Offset,
	)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	defer rows.Close()
	
	var results []*VideoGame
	for rows.Next() {
		var vg VideoGame
		if err := rows.Scan(
			&vg.ID, &vg.Title, &vg.Developer, &vg.CoverArtURL,
			&vg.IsFavorite, &vg.IsWatchlist, &vg.CreatedAt, &vg.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		// Get the platforms for each game
		platformsQuery := `
		SELECT name FROM video_game_platforms
		WHERE video_game_id = ?
		ORDER BY name
		`
		
		platformRows, err := db.Query(platformsQuery, vg.ID)
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		vg.Platforms = []string{}
		for platformRows.Next() {
			var platform string
			if err := platformRows.Scan(&platform); err != nil {
				platformRows.Close()
				return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
			}
			vg.Platforms = append(vg.Platforms, platform)
		}
		platformRows.Close()
		
		results = append(results, &vg)
	}
	
	return results, nil
}

// GetSuggestionsByMedia gets suggestions for a specific media item
func GetSuggestionsByMedia(db *sql.DB, mediaID int64, mediaType MediaType) ([]*Suggestion, error) {
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
	
	rows, err := db.Query(query, mediaID)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	defer rows.Close()
	
	var suggestions []*Suggestion
	for rows.Next() {
		var s Suggestion
		var outcomeStr string
		
		if err := rows.Scan(&s.ID, &s.MediaID, &s.Reason, &outcomeStr, &s.CreatedAt); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		s.MediaType = mediaType
		s.Outcome = SuggestionOutcome(outcomeStr)
		suggestions = append(suggestions, &s)
	}
	
	return suggestions, nil
}

// GetAllSuggestions gets all suggestions across all media types
func GetAllSuggestions(db *sql.DB, options SearchOptions) ([]*Suggestion, error) {
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
		
		rows, err := db.Query(query, options.Limit, options.Offset)
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		for rows.Next() {
			var s Suggestion
			var outcomeStr string
			
			if err := rows.Scan(&s.ID, &s.MediaID, &s.Reason, &outcomeStr, &s.CreatedAt); err != nil {
				rows.Close()
				return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
			}
			
			s.MediaType = mediaType
			s.Outcome = SuggestionOutcome(outcomeStr)
			suggestions = append(suggestions, &s)
		}
		rows.Close()
	}
	
	// TODO: Sort the combined results by creation date if needed
	
	return suggestions, nil
}

// GetAllConstraints retrieves all constraints from the database
func GetAllConstraints(db *sql.DB) ([]*Constraint, error) {
	query := `
	SELECT id, rule, media, created_at, updated_at
	FROM constraints
	ORDER BY id
	`
	
	rows, err := db.Query(query)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	defer rows.Close()
	
	var constraints []*Constraint
	for rows.Next() {
		var c Constraint
		var mediaTypeStr string
		
		if err := rows.Scan(&c.ID, &c.Rule, &mediaTypeStr, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		
		c.Media = MediaType(mediaTypeStr)
		constraints = append(constraints, &c)
	}
	
	return constraints, nil
}

// CountItems counts the number of items in a given table with optional filtering
func CountItems(db *sql.DB, tableName string, onlyFavorites, onlyWatchlist bool) (int, error) {
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
	err := db.QueryRow(query).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	return count, nil
}
