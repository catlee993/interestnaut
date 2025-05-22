package db

import (
	"fmt"
	"strings"
	"time"

	"zombiezen.com/go/sqlite"
	"zombiezen.com/go/sqlite/sqlitex"
)

// SearchOptions contains options for filtering and pagination
type SearchOptions struct {
	Limit         int
	Offset        int
	SortBy        string
	SortOrder     string // "ASC" or "DESC"
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

	stmt := db.db.Prep(query)
	defer stmt.Reset()

	// Bind parameters
	stmt.SetText(":1", searchPattern)
	stmt.SetText(":2", searchPattern)
	stmt.SetText(":3", searchPattern)
	stmt.SetInt64(":4", int64(options.Limit))
	stmt.SetInt64(":5", int64(options.Offset))

	var results []*Music

	for {
		hasRow, err := stmt.Step()
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		if !hasRow {
			break
		}

		music := &Music{}
		music.ID = uint64(stmt.ColumnInt64(0))
		music.Title = stmt.ColumnText(1)
		music.Artist = stmt.ColumnText(2)
		music.Album = stmt.ColumnText(3)
		music.AlbumArtURL = stmt.ColumnText(4)
		music.IsFavorite = stmt.ColumnBool(5)
		music.IsWatchlist = stmt.ColumnBool(6)

		// Parse timestamps
		createdAt := stmt.ColumnText(7)
		updatedAt := stmt.ColumnText(8)

		var err2 error
		if music.CreatedAt, err2 = time.Parse(time.RFC3339, createdAt); err2 != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err2)
		}
		if music.UpdatedAt, err2 = time.Parse(time.RFC3339, updatedAt); err2 != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err2)
		}

		results = append(results, music)
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

	stmt := db.db.Prep(query)
	defer stmt.Reset()

	// Bind parameters
	stmt.SetText(":1", searchPattern)
	stmt.SetText(":2", searchPattern)
	stmt.SetInt64(":3", int64(options.Limit))
	stmt.SetInt64(":4", int64(options.Offset))

	var results []*Book

	for {
		hasRow, err := stmt.Step()
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		if !hasRow {
			break
		}

		book := &Book{}
		book.ID = uint64(stmt.ColumnInt64(0))
		book.Title = stmt.ColumnText(1)
		book.Author = stmt.ColumnText(2)
		book.CoverArtURL = stmt.ColumnText(3)
		book.IsFavorite = stmt.ColumnBool(4)
		book.IsWatchlist = stmt.ColumnBool(5)

		// Parse timestamps
		createdAt := stmt.ColumnText(6)
		updatedAt := stmt.ColumnText(7)

		var err2 error
		if book.CreatedAt, err2 = time.Parse(time.RFC3339, createdAt); err2 != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err2)
		}
		if book.UpdatedAt, err2 = time.Parse(time.RFC3339, updatedAt); err2 != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err2)
		}

		results = append(results, book)
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
	// Start with a base WHERE clause for the search term
	whereClause := `WHERE (
		title LIKE ? OR
		director LIKE ? OR
		writer LIKE ?
	)`

	// Add favorite filter if requested
	if options.OnlyFavorites {
		whereClause += " AND is_favorite = 1"
	}

	// Add watchlist filter if requested
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

	var results []*Movie

	err := sqlitex.Execute(db.db, query, &sqlitex.ExecOptions{
		Args: []interface{}{
			searchPattern, searchPattern, searchPattern,
			options.Limit, options.Offset,
		},
		ResultFunc: func(stmt *sqlite.Stmt) error {
			movie := &Movie{}
			movie.ID = uint64(stmt.ColumnInt64(0))
			movie.Title = stmt.ColumnText(1)
			movie.Director = stmt.ColumnText(2)
			movie.Writer = stmt.ColumnText(3)
			movie.PosterURL = stmt.ColumnText(4)
			movie.IsFavorite = stmt.ColumnInt(5) != 0
			movie.IsWatchlist = stmt.ColumnInt(6) != 0

			createdAt := stmt.ColumnText(7)
			updatedAt := stmt.ColumnText(8)

			// Parse timestamps
			var err error
			if movie.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
				return fmt.Errorf("parse created_at: %v", err)
			}
			if movie.UpdatedAt, err = time.Parse(time.RFC3339, updatedAt); err != nil {
				return fmt.Errorf("parse updated_at: %v", err)
			}

			results = append(results, movie)
			return nil
		},
	})

	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	return results, nil
}

// SearchShows searches for TV shows with the given term
func (db *SqliteDatabase) SearchShows(searchTerm string, options SearchOptions) ([]*Show, error) {
	// Start with a base WHERE clause for the search term
	whereClause := `WHERE (
		title LIKE ? OR
		director LIKE ? OR
		writer LIKE ?
	)`

	// Add favorite filter if requested
	if options.OnlyFavorites {
		whereClause += " AND is_favorite = 1"
	}

	// Add watchlist filter if requested
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

	var results []*Show

	err := sqlitex.Execute(db.db, query, &sqlitex.ExecOptions{
		Args: []interface{}{
			searchPattern, searchPattern, searchPattern,
			options.Limit, options.Offset,
		},
		ResultFunc: func(stmt *sqlite.Stmt) error {
			show := &Show{}
			show.ID = uint64(stmt.ColumnInt64(0))
			show.Title = stmt.ColumnText(1)
			show.Director = stmt.ColumnText(2)
			show.Writer = stmt.ColumnText(3)
			show.PosterURL = stmt.ColumnText(4)
			show.IsFavorite = stmt.ColumnInt(5) != 0
			show.IsWatchlist = stmt.ColumnInt(6) != 0

			createdAt := stmt.ColumnText(7)
			updatedAt := stmt.ColumnText(8)

			// Parse timestamps
			var err error
			if show.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
				return fmt.Errorf("parse created_at: %v", err)
			}
			if show.UpdatedAt, err = time.Parse(time.RFC3339, updatedAt); err != nil {
				return fmt.Errorf("parse updated_at: %v", err)
			}

			results = append(results, show)
			return nil
		},
	})

	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	return results, nil
}

// SearchVideoGames searches for video games with the given term
func (db *SqliteDatabase) SearchVideoGames(searchTerm string, options SearchOptions) ([]*VideoGame, error) {
	// Start with a base WHERE clause for the search term
	whereClause := `WHERE (
		title LIKE ? OR
		developer LIKE ?
	)`

	// Add favorite filter if requested
	if options.OnlyFavorites {
		whereClause += " AND is_favorite = 1"
	}

	// Add watchlist filter if requested
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

	var results []*VideoGame

	err := sqlitex.Execute(db.db, query, &sqlitex.ExecOptions{
		Args: []interface{}{
			searchPattern, searchPattern,
			options.Limit, options.Offset,
		},
		ResultFunc: func(stmt *sqlite.Stmt) error {
			videoGame := &VideoGame{}
			videoGame.ID = uint64(stmt.ColumnInt64(0))
			videoGame.Title = stmt.ColumnText(1)
			videoGame.Developer = stmt.ColumnText(2)
			videoGame.CoverArtURL = stmt.ColumnText(3)
			videoGame.IsFavorite = stmt.ColumnInt(4) != 0
			videoGame.IsWatchlist = stmt.ColumnInt(5) != 0

			createdAt := stmt.ColumnText(6)
			updatedAt := stmt.ColumnText(7)

			// Store timestamps as strings directly
			videoGame.CreatedAt = createdAt
			videoGame.UpdatedAt = updatedAt

			// Get the platforms for each game
			platformsQuery := `
			SELECT name FROM video_game_platforms
			WHERE video_game_id = ?
			ORDER BY name
			`

			videoGame.Platforms = []string{}

			err := sqlitex.Execute(db.db, platformsQuery, &sqlitex.ExecOptions{
				Args: []interface{}{videoGame.ID},
				ResultFunc: func(platformStmt *sqlite.Stmt) error {
					platform := platformStmt.ColumnText(0)
					videoGame.Platforms = append(videoGame.Platforms, platform)
					return nil
				},
			})
			if err != nil {
				return fmt.Errorf("get platforms: %v", err)
			}

			results = append(results, videoGame)
			return nil
		},
	})

	if err != nil {
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

	var suggestions []*Suggestion

	err := sqlitex.Execute(db.db, query, &sqlitex.ExecOptions{
		Args: []interface{}{mediaID},
		ResultFunc: func(stmt *sqlite.Stmt) error {
			suggestion := &Suggestion{}
			suggestion.ID = uint64(stmt.ColumnInt64(0))
			suggestion.MediaID = uint64(stmt.ColumnInt64(1))
			suggestion.Reason = stmt.ColumnText(2)
			outcomeStr := stmt.ColumnText(3)
			createdAt := stmt.ColumnText(4)

			suggestion.MediaType = mediaType
			suggestion.Outcome = SuggestionOutcome(outcomeStr)

			var err error
			if suggestion.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
				return fmt.Errorf("parse created_at: %v", err)
			}

			suggestions = append(suggestions, suggestion)
			return nil
		},
	})

	if err != nil {
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

		err := sqlitex.Execute(db.db, query, &sqlitex.ExecOptions{
			Args: []interface{}{options.Limit, options.Offset},
			ResultFunc: func(stmt *sqlite.Stmt) error {
				suggestion := &Suggestion{}
				suggestion.ID = uint64(stmt.ColumnInt64(0))
				suggestion.MediaID = uint64(stmt.ColumnInt64(1))
				suggestion.Reason = stmt.ColumnText(2)
				outcomeStr := stmt.ColumnText(3)
				createdAt := stmt.ColumnText(4)

				suggestion.MediaType = mediaType
				suggestion.Outcome = SuggestionOutcome(outcomeStr)

				var err error
				if suggestion.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
					return fmt.Errorf("parse created_at: %v", err)
				}

				suggestions = append(suggestions, suggestion)
				return nil
			},
		})

		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
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

	stmt := db.db.Prep(query)
	defer stmt.Reset()

	var constraints []*Constraint

	for {
		hasRow, err := stmt.Step()
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		if !hasRow {
			break
		}

		constraint := &Constraint{}

		constraint.ID = stmt.ColumnInt64(0)
		constraint.Rule = stmt.ColumnText(1)
		mediaTypeStr := stmt.ColumnText(2)
		constraint.Media = MediaType(mediaTypeStr)

		createdAt := stmt.ColumnText(3)
		updatedAt := stmt.ColumnText(4)

		var err2 error
		if constraint.CreatedAt, err2 = time.Parse(time.RFC3339, createdAt); err2 != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err2)
		}
		if constraint.UpdatedAt, err2 = time.Parse(time.RFC3339, updatedAt); err2 != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err2)
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

	stmt := db.db.Prep(query)
	defer stmt.Reset()

	hasRow, err := stmt.Step()
	if err != nil {
		return 0, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	if !hasRow {
		return 0, fmt.Errorf("%w: no rows returned for count query", ErrDatabaseFailure)
	}

	count := stmt.ColumnInt(0)
	return count, nil
}

// GetSchemaVersion retrieves the current schema version
func (db *SqliteDatabase) GetSchemaVersion() (int, error) {
	stmt := db.db.Prep("SELECT version FROM schema_version ORDER BY id DESC LIMIT 1")
	defer stmt.Reset()

	hasRow, err := stmt.Step()
	if err != nil {
		return 0, err
	}
	if !hasRow {
		return 0, nil // No schema version found, assume 0
	}

	version := stmt.ColumnInt(0)
	return version, nil
}
