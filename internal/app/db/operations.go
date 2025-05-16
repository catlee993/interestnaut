package db

import (
	"database/sql"
	"errors"
	"fmt"
	"time"
)

// Common errors
var (
	ErrNotFound        = errors.New("item not found")
	ErrAlreadyExists   = errors.New("item already exists")
	ErrInvalidInput    = errors.New("invalid input")
	ErrDatabaseFailure = errors.New("database operation failed")
)

// MediaType represents the different types of media in the database
type MediaType string

// Media type constants
const (
	MediaTypeMusic      MediaType = "music"
	MediaTypeBook       MediaType = "book"
	MediaTypeMovie      MediaType = "movie"
	MediaTypeShow       MediaType = "show"
	MediaTypeVideoGame  MediaType = "video_game"
	MediaTypeGlobal     MediaType = "global"
)

// SuggestionOutcome represents the possible outcomes of a suggestion
type SuggestionOutcome string

// Suggestion outcome constants
const (
	OutcomeLiked    SuggestionOutcome = "liked"
	OutcomeDisliked SuggestionOutcome = "disliked"
	OutcomeSkipped  SuggestionOutcome = "skipped"
	OutcomeAdded    SuggestionOutcome = "added"
)

// Music represents a music entry in the database
type Music struct {
	ID           int64
	Title        string
	Artist       string
	Album        string
	AlbumArtURL  string
	IsFavorite   bool
	IsWatchlist  bool
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// Book represents a book entry in the database
type Book struct {
	ID           int64
	Title        string
	Author       string
	CoverArtURL  string
	IsFavorite   bool
	IsWatchlist  bool
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// Movie represents a movie entry in the database
type Movie struct {
	ID           int64
	Title        string
	Director     string
	Writer       string
	PosterURL    string
	IsFavorite   bool
	IsWatchlist  bool
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// Show represents a TV show entry in the database
type Show struct {
	ID           int64
	Title        string
	Director     string
	Writer       string
	PosterURL    string
	IsFavorite   bool
	IsWatchlist  bool
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// VideoGame represents a video game entry in the database
type VideoGame struct {
	ID           int64
	Title        string
	Developer    string
	CoverArtURL  string
	IsFavorite   bool
	IsWatchlist  bool
	Platforms    []string
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// Suggestion represents a suggestion entry for any media type
type Suggestion struct {
	ID        int64
	MediaID   int64
	MediaType MediaType
	Reason    string
	Outcome   SuggestionOutcome
	CreatedAt time.Time
}

// Constraint represents a constraint rule in the database
type Constraint struct {
	ID        int64
	Rule      string
	Media     MediaType
	CreatedAt time.Time
	UpdatedAt time.Time
}

// AddMusic adds a new music entry to the database
func AddMusic(db *sql.DB, music *Music) error {
	query := `
	INSERT INTO music (title, artist, album, album_art_url, is_favorite, is_watchlist)
	VALUES (?, ?, ?, ?, ?, ?)
	RETURNING id, created_at, updated_at
	`
	
	row := db.QueryRow(
		query, 
		music.Title, 
		music.Artist, 
		music.Album, 
		music.AlbumArtURL, 
		music.IsFavorite, 
		music.IsWatchlist,
	)
	
	err := row.Scan(&music.ID, &music.CreatedAt, &music.UpdatedAt)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	return nil
}

// GetMusic retrieves a music entry by ID
func GetMusic(db *sql.DB, id int64) (*Music, error) {
	query := `
	SELECT id, title, artist, album, album_art_url, is_favorite, is_watchlist, created_at, updated_at
	FROM music
	WHERE id = ?
	`
	
	var music Music
	err := db.QueryRow(query, id).Scan(
		&music.ID,
		&music.Title,
		&music.Artist,
		&music.Album,
		&music.AlbumArtURL,
		&music.IsFavorite,
		&music.IsWatchlist,
		&music.CreatedAt,
		&music.UpdatedAt,
	)
	
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	return &music, nil
}

// AddBook adds a new book entry to the database
func AddBook(db *sql.DB, book *Book) error {
	query := `
	INSERT INTO books (title, author, cover_art_url, is_favorite, is_watchlist)
	VALUES (?, ?, ?, ?, ?)
	RETURNING id, created_at, updated_at
	`
	
	row := db.QueryRow(
		query, 
		book.Title, 
		book.Author, 
		book.CoverArtURL, 
		book.IsFavorite, 
		book.IsWatchlist,
	)
	
	err := row.Scan(&book.ID, &book.CreatedAt, &book.UpdatedAt)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	return nil
}

// GetBook retrieves a book entry by ID
func GetBook(db *sql.DB, id int64) (*Book, error) {
	query := `
	SELECT id, title, author, cover_art_url, is_favorite, is_watchlist, created_at, updated_at
	FROM books
	WHERE id = ?
	`
	
	var book Book
	err := db.QueryRow(query, id).Scan(
		&book.ID,
		&book.Title,
		&book.Author,
		&book.CoverArtURL,
		&book.IsFavorite,
		&book.IsWatchlist,
		&book.CreatedAt,
		&book.UpdatedAt,
	)
	
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	return &book, nil
}

// AddMovie adds a new movie entry to the database
func AddMovie(db *sql.DB, movie *Movie) error {
	query := `
	INSERT INTO movies (title, director, writer, poster_url, is_favorite, is_watchlist)
	VALUES (?, ?, ?, ?, ?, ?)
	RETURNING id, created_at, updated_at
	`
	
	row := db.QueryRow(
		query, 
		movie.Title, 
		movie.Director, 
		movie.Writer, 
		movie.PosterURL, 
		movie.IsFavorite, 
		movie.IsWatchlist,
	)
	
	err := row.Scan(&movie.ID, &movie.CreatedAt, &movie.UpdatedAt)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	return nil
}

// GetMovie retrieves a movie entry by ID
func GetMovie(db *sql.DB, id int64) (*Movie, error) {
	query := `
	SELECT id, title, director, writer, poster_url, is_favorite, is_watchlist, created_at, updated_at
	FROM movies
	WHERE id = ?
	`
	
	var movie Movie
	err := db.QueryRow(query, id).Scan(
		&movie.ID,
		&movie.Title,
		&movie.Director,
		&movie.Writer,
		&movie.PosterURL,
		&movie.IsFavorite,
		&movie.IsWatchlist,
		&movie.CreatedAt,
		&movie.UpdatedAt,
	)
	
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	return &movie, nil
}

// AddShow adds a new show entry to the database
func AddShow(db *sql.DB, show *Show) error {
	query := `
	INSERT INTO shows (title, director, writer, poster_url, is_favorite, is_watchlist)
	VALUES (?, ?, ?, ?, ?, ?)
	`

	result, err := db.Exec(
		query,
		show.Title,
		show.Director,
		show.Writer,
		show.PosterURL,
		show.IsFavorite,
		show.IsWatchlist,
	)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	show.ID = id
	return nil
}

// GetShow retrieves a show entry by ID
func GetShow(db *sql.DB, id int64) (*Show, error) {
	query := `
	SELECT id, title, director, writer, poster_url, is_favorite, is_watchlist, created_at, updated_at
	FROM shows
	WHERE id = ?
	`

	var show Show
	var createdAt, updatedAt string

	err := db.QueryRow(query, id).Scan(
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

	if err == sql.ErrNoRows {
		return nil, ErrNotFound
	} else if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	// Parse timestamps
	if show.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	if show.UpdatedAt, err = time.Parse(time.RFC3339, updatedAt); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	return &show, nil
}

// AddVideoGame adds a new video game entry to the database with platforms
func AddVideoGame(db *sql.DB, game *VideoGame) error {
	// Begin transaction to handle both the video game and its platforms
	tx, err := db.Begin()
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	// Ensure proper rollback on error
	defer func() {
		if err != nil {
			tx.Rollback()
		}
	}()
	
	// Insert the video game
	query := `
	INSERT INTO video_games (title, developer, cover_art_url, is_favorite, is_watchlist)
	VALUES (?, ?, ?, ?, ?)
	RETURNING id, created_at, updated_at
	`
	
	row := tx.QueryRow(
		query, 
		game.Title, 
		game.Developer, 
		game.CoverArtURL, 
		game.IsFavorite, 
		game.IsWatchlist,
	)
	
	err = row.Scan(&game.ID, &game.CreatedAt, &game.UpdatedAt)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	// Insert platforms if provided
	if len(game.Platforms) > 0 {
		platformQuery := `
		INSERT INTO video_game_platforms (video_game_id, name)
		VALUES (?, ?)
		`
		
		for _, platform := range game.Platforms {
			_, err = tx.Exec(platformQuery, game.ID, platform)
			if err != nil {
				return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
			}
		}
	}
	
	// Commit the transaction
	if err = tx.Commit(); err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	return nil
}

// GetVideoGame retrieves a video game entry by ID, including its platforms
func GetVideoGame(db *sql.DB, id int64) (*VideoGame, error) {
	// Get the video game
	gameQuery := `
	SELECT id, title, developer, cover_art_url, is_favorite, is_watchlist, created_at, updated_at
	FROM video_games
	WHERE id = ?
	`
	
	var game VideoGame
	err := db.QueryRow(gameQuery, id).Scan(
		&game.ID,
		&game.Title,
		&game.Developer,
		&game.CoverArtURL,
		&game.IsFavorite,
		&game.IsWatchlist,
		&game.CreatedAt,
		&game.UpdatedAt,
	)
	
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	// Get the platforms
	platformsQuery := `
	SELECT name FROM video_game_platforms
	WHERE video_game_id = ?
	ORDER BY name
	`
	
	rows, err := db.Query(platformsQuery, id)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	defer rows.Close()
	
	game.Platforms = []string{}
	for rows.Next() {
		var platform string
		if err := rows.Scan(&platform); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		game.Platforms = append(game.Platforms, platform)
	}
	
	return &game, nil
}

// AddSuggestion adds a new suggestion to the database
func AddSuggestion(db *sql.DB, mediaID int64, mediaType MediaType, reason string, outcome SuggestionOutcome) error {
	// Choose the appropriate table based on media type
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
		return fmt.Errorf("%w: invalid media type", ErrInvalidInput)
	}
	
	// Create the dynamic query
	query := fmt.Sprintf(`
	INSERT INTO %s (%s, reason, outcome)
	VALUES (?, ?, ?)
	`, tableName, idColumn)
	
	_, err := db.Exec(query, mediaID, reason, string(outcome))
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	return nil
}

// UpdateFavoriteStatus updates the favorite status of an item
func UpdateFavoriteStatus(db *sql.DB, id int64, mediaType MediaType, isFavorite bool) error {
	var tableName string
	
	switch mediaType {
	case MediaTypeMusic:
		tableName = "music"
	case MediaTypeBook:
		tableName = "books"
	case MediaTypeMovie:
		tableName = "movies"
	case MediaTypeShow:
		tableName = "shows"
	case MediaTypeVideoGame:
		tableName = "video_games"
	default:
		return fmt.Errorf("%w: invalid media type", ErrInvalidInput)
	}
	
	query := fmt.Sprintf(`
	UPDATE %s
	SET is_favorite = ?, updated_at = CURRENT_TIMESTAMP
	WHERE id = ?
	`, tableName)
	
	result, err := db.Exec(query, isFavorite, id)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	if rowsAffected == 0 {
		return ErrNotFound
	}
	
	return nil
}

// UpdateWatchlistStatus updates the watchlist status of an item
func UpdateWatchlistStatus(db *sql.DB, id int64, mediaType MediaType, isWatchlist bool) error {
	var tableName string
	
	switch mediaType {
	case MediaTypeMusic:
		tableName = "music"
	case MediaTypeBook:
		tableName = "books"
	case MediaTypeMovie:
		tableName = "movies"
	case MediaTypeShow:
		tableName = "shows"
	case MediaTypeVideoGame:
		tableName = "video_games"
	default:
		return fmt.Errorf("%w: invalid media type", ErrInvalidInput)
	}
	
	query := fmt.Sprintf(`
	UPDATE %s
	SET is_watchlist = ?, updated_at = CURRENT_TIMESTAMP
	WHERE id = ?
	`, tableName)
	
	result, err := db.Exec(query, isWatchlist, id)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	if rowsAffected == 0 {
		return ErrNotFound
	}
	
	return nil
}

// AddConstraint adds a new constraint rule to the database
func AddConstraint(db *sql.DB, rule string, mediaType MediaType) error {
	query := `
	INSERT INTO constraints (rule, media)
	VALUES (?, ?)
	`
	
	_, err := db.Exec(query, rule, string(mediaType))
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	
	return nil
}

// GetConstraintsByMediaType retrieves all constraints for a specific media type
func GetConstraintsByMediaType(db *sql.DB, mediaType MediaType) ([]*Constraint, error) {
	query := `
	SELECT id, rule, media, created_at, updated_at
	FROM constraints
	WHERE media = ? OR media = ?
	ORDER BY id
	`
	
	rows, err := db.Query(query, string(mediaType), string(MediaTypeGlobal))
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
