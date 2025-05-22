package db

import (
	"context"
	"errors"
	"fmt"
	"interestnaut/internal/app/models"
	"log"
	"strings"
	"time"

	"github.com/google/uuid"
	"zombiezen.com/go/sqlite"
	"zombiezen.com/go/sqlite/sqlitex"
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
	MediaTypeMusic     MediaType = "music"
	MediaTypeBook      MediaType = "book"
	MediaTypeMovie     MediaType = "movie"
	MediaTypeShow      MediaType = "show"
	MediaTypeVideoGame MediaType = "video_game"
	MediaTypeGlobal    MediaType = "global"
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
	ID          uint64
	Title       string
	Artist      string
	Album       string
	AlbumArtURL string
	IsFavorite  bool
	IsWatchlist bool
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// Book represents a book entry in the database
type Book struct {
	ID          uint64
	Title       string
	Author      string
	CoverArtURL string
	IsFavorite  bool
	IsWatchlist bool
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// Movie represents a movie entry in the database
type Movie struct {
	ID          uint64
	Title       string
	Director    string
	Writer      string
	PosterURL   string
	IsFavorite  bool
	IsWatchlist bool
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// Show represents a TV show entry in the database
type Show struct {
	ID          uint64
	Title       string
	Director    string
	Writer      string
	PosterURL   string
	IsFavorite  bool
	IsWatchlist bool
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// VideoGame represents a video game entry in the database
type VideoGame struct {
	ID          uint64
	Title       string
	Developer   string
	CoverArtURL string
	IsFavorite  bool
	IsWatchlist bool
	Platforms   []string
	CreatedAt   string
	UpdatedAt   string
}

// Suggestion represents a suggestion entry for any media type
type Suggestion struct {
	ID        uint64
	MediaID   uint64
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
func (db *SqliteDatabase) AddMusic(music *Music) error {
	query := `
	INSERT INTO music (title, artist, album, album_art_url, is_favorite, is_watchlist)
	VALUES (:1, :2, :3, :4, :5, :6)
	`

	err := sqlitex.Execute(db.db, query, &sqlitex.ExecOptions{
		Args: []interface{}{
			music.Title,
			music.Artist,
			music.Album,
			music.AlbumArtURL,
			music.IsFavorite,
			music.IsWatchlist,
		},
	})
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	// Get the last inserted ID
	var lastID int64
	err = sqlitex.Execute(db.db, "SELECT last_insert_rowid()", &sqlitex.ExecOptions{
		ResultFunc: func(stmt *sqlite.Stmt) error {
			lastID = stmt.ColumnInt64(0)
			return nil
		},
	})
	if err != nil {
		return fmt.Errorf("%w: getting last insert ID: %v", ErrDatabaseFailure, err)
	}

	music.ID = uint64(lastID)
	return nil
}

// GetMusic retrieves a music entry by ID
func (db *SqliteDatabase) GetMusic(id uint64) (*Music, error) {
	query := `
	SELECT id, title, artist, album, album_art_url, is_favorite, is_watchlist, created_at, updated_at
	FROM music
	WHERE id = :1
	`

	var music Music

	stmt := db.db.Prep(query)
	defer stmt.Reset()

	stmt.SetInt64(":1", int64(id))

	if hasRow, err := stmt.Step(); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	} else if !hasRow {
		return nil, ErrNotFound
	}

	music.ID = uint64(stmt.ColumnInt64(0))
	music.Title = stmt.ColumnText(1)
	music.Artist = stmt.ColumnText(2)
	music.Album = stmt.ColumnText(3)
	music.AlbumArtURL = stmt.ColumnText(4)
	music.IsFavorite = stmt.ColumnBool(5)
	music.IsWatchlist = stmt.ColumnBool(6)

	createdAt := stmt.ColumnText(7)
	updatedAt := stmt.ColumnText(8)

	// Parse timestamps
	var err error
	if music.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	if music.UpdatedAt, err = time.Parse(time.RFC3339, updatedAt); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	return &music, nil
}

// AddBook adds a new book entry to the database
func (db *SqliteDatabase) AddBook(book *Book) error {
	query := `
	INSERT INTO books (title, author, cover_art_url, is_favorite, is_watchlist)
	VALUES (:1, :2, :3, :4, :5)
	`

	err := sqlitex.Execute(db.db, query, &sqlitex.ExecOptions{
		Args: []interface{}{
			book.Title,
			book.Author,
			book.CoverArtURL,
			book.IsFavorite,
			book.IsWatchlist,
		},
	})
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	// Get the last inserted ID
	var lastID int64
	err = sqlitex.Execute(db.db, "SELECT last_insert_rowid()", &sqlitex.ExecOptions{
		ResultFunc: func(stmt *sqlite.Stmt) error {
			lastID = stmt.ColumnInt64(0)
			return nil
		},
	})
	if err != nil {
		return fmt.Errorf("%w: getting last insert ID: %v", ErrDatabaseFailure, err)
	}

	book.ID = uint64(lastID)
	return nil
}

// GetBook retrieves a book entry by ID
func (db *SqliteDatabase) GetBook(id uint64) (*Book, error) {
	query := `
	SELECT id, title, author, cover_art_url, is_favorite, is_watchlist, created_at, updated_at
	FROM books
	WHERE id = :1
	`

	var book Book

	stmt := db.db.Prep(query)
	defer stmt.Reset()

	stmt.SetInt64(":1", int64(id))

	if hasRow, err := stmt.Step(); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	} else if !hasRow {
		return nil, ErrNotFound
	}

	book.ID = uint64(stmt.ColumnInt64(0))
	book.Title = stmt.ColumnText(1)
	book.Author = stmt.ColumnText(2)
	book.CoverArtURL = stmt.ColumnText(3)
	book.IsFavorite = stmt.ColumnBool(4)
	book.IsWatchlist = stmt.ColumnBool(5)

	createdAt := stmt.ColumnText(6)
	updatedAt := stmt.ColumnText(7)

	// Parse timestamps
	var err error
	if book.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	if book.UpdatedAt, err = time.Parse(time.RFC3339, updatedAt); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	return &book, nil
}

// AddMovie adds a new movie entry to the database
func (db *SqliteDatabase) AddMovie(movie *Movie) error {
	query := `
	INSERT INTO movies (title, director, writer, poster_url, is_favorite, is_watchlist)
	VALUES (:1, :2, :3, :4, :5, :6)
	`

	err := sqlitex.Execute(db.db, query, &sqlitex.ExecOptions{
		Args: []interface{}{
			movie.Title,
			movie.Director,
			movie.Writer,
			movie.PosterURL,
			movie.IsFavorite,
			movie.IsWatchlist,
		},
	})
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	// Get the last inserted ID
	var lastID int64
	err = sqlitex.Execute(db.db, "SELECT last_insert_rowid()", &sqlitex.ExecOptions{
		ResultFunc: func(stmt *sqlite.Stmt) error {
			lastID = stmt.ColumnInt64(0)
			return nil
		},
	})
	if err != nil {
		return fmt.Errorf("%w: getting last insert ID: %v", ErrDatabaseFailure, err)
	}

	movie.ID = uint64(lastID)
	return nil
}

// GetMovie retrieves a movie entry by ID
func (db *SqliteDatabase) GetMovie(id uint64) (*Movie, error) {
	query := `
	SELECT id, title, director, writer, poster_url, is_favorite, is_watchlist, created_at, updated_at
	FROM movies
	WHERE id = :1
	`

	var movie Movie

	stmt := db.db.Prep(query)
	defer stmt.Reset()

	stmt.SetInt64(":1", int64(id))

	if hasRow, err := stmt.Step(); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	} else if !hasRow {
		return nil, ErrNotFound
	}

	movie.ID = uint64(stmt.ColumnInt64(0))
	movie.Title = stmt.ColumnText(1)
	movie.Director = stmt.ColumnText(2)
	movie.Writer = stmt.ColumnText(3)
	movie.PosterURL = stmt.ColumnText(4)
	movie.IsFavorite = stmt.ColumnBool(5)
	movie.IsWatchlist = stmt.ColumnBool(6)

	createdAt := stmt.ColumnText(7)
	updatedAt := stmt.ColumnText(8)

	// Parse timestamps
	var err error
	if movie.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	if movie.UpdatedAt, err = time.Parse(time.RFC3339, updatedAt); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	return &movie, nil
}

// AddShow adds a new show entry to the database
func (db *SqliteDatabase) AddShow(show *Show) error {
	query := `
	INSERT INTO shows (title, director, writer, poster_url, is_favorite, is_watchlist)
	VALUES (:1, :2, :3, :4, :5, :6)
	`

	err := sqlitex.Execute(db.db, query, &sqlitex.ExecOptions{
		Args: []interface{}{
			show.Title,
			show.Director,
			show.Writer,
			show.PosterURL,
			show.IsFavorite,
			show.IsWatchlist,
		},
	})
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	// Get the last inserted ID
	var lastID int64
	err = sqlitex.Execute(db.db, "SELECT last_insert_rowid()", &sqlitex.ExecOptions{
		ResultFunc: func(stmt *sqlite.Stmt) error {
			lastID = stmt.ColumnInt64(0)
			return nil
		},
	})
	if err != nil {
		return fmt.Errorf("%w: getting last insert ID: %v", ErrDatabaseFailure, err)
	}

	show.ID = uint64(lastID)
	return nil
}

// GetShow retrieves a show entry by ID
func (db *SqliteDatabase) GetShow(id uint64) (*Show, error) {
	query := `
	SELECT id, title, director, writer, poster_url, is_favorite, is_watchlist, created_at, updated_at
	FROM shows
	WHERE id = :1
	`

	var show Show

	stmt := db.db.Prep(query)
	defer stmt.Reset()

	stmt.SetInt64(":1", int64(id))

	if hasRow, err := stmt.Step(); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	} else if !hasRow {
		return nil, ErrNotFound
	}

	show.ID = uint64(stmt.ColumnInt64(0))
	show.Title = stmt.ColumnText(1)
	show.Director = stmt.ColumnText(2)
	show.Writer = stmt.ColumnText(3)
	show.PosterURL = stmt.ColumnText(4)
	show.IsFavorite = stmt.ColumnBool(5)
	show.IsWatchlist = stmt.ColumnBool(6)

	createdAt := stmt.ColumnText(7)
	updatedAt := stmt.ColumnText(8)

	// Parse timestamps
	var err error
	if show.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	if show.UpdatedAt, err = time.Parse(time.RFC3339, updatedAt); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	return &show, nil
}

// AddVideoGame adds a new video game entry to the database with platforms
func (db *SqliteDatabase) AddVideoGame(game *VideoGame) error {
	// Begin transaction to handle both the video game and its platforms
	if err := sqlitex.Execute(db.db, "BEGIN TRANSACTION", nil); err != nil {
		return fmt.Errorf("%w: failed to begin transaction: %v", ErrDatabaseFailure, err)
	}

	// Ensure we either commit or rollback the transaction
	defer func() {
		// If there was a panic, roll back the transaction
		if r := recover(); r != nil {
			sqlitex.Execute(db.db, "ROLLBACK", nil)
			panic(r) // Re-throw the panic
		}
	}()

	// Insert the video game
	query := `
	INSERT INTO video_games (title, developer, cover_art_url, is_favorite, is_watchlist)
	VALUES (:1, :2, :3, :4, :5)
	`

	err := sqlitex.Execute(db.db, query, &sqlitex.ExecOptions{
		Args: []interface{}{
			game.Title,
			game.Developer,
			game.CoverArtURL,
			game.IsFavorite,
			game.IsWatchlist,
		},
	})
	if err != nil {
		sqlitex.Execute(db.db, "ROLLBACK", nil)
		return fmt.Errorf("%w: insert video game: %v", ErrDatabaseFailure, err)
	}

	// Get the last inserted ID
	var lastID int64
	err = sqlitex.Execute(db.db, "SELECT last_insert_rowid()", &sqlitex.ExecOptions{
		ResultFunc: func(stmt *sqlite.Stmt) error {
			lastID = stmt.ColumnInt64(0)
			return nil
		},
	})
	if err != nil {
		sqlitex.Execute(db.db, "ROLLBACK", nil)
		return fmt.Errorf("%w: getting last insert ID: %v", ErrDatabaseFailure, err)
	}

	game.ID = uint64(lastID)

	// Get created_at and updated_at timestamps
	timestampQuery := `
	SELECT created_at, updated_at
	FROM video_games
	WHERE id = :1
	`
	err = sqlitex.Execute(db.db, timestampQuery, &sqlitex.ExecOptions{
		Args: []interface{}{game.ID},
		ResultFunc: func(stmt *sqlite.Stmt) error {
			game.CreatedAt = stmt.ColumnText(0)
			game.UpdatedAt = stmt.ColumnText(1)
			return nil
		},
	})
	if err != nil {
		sqlitex.Execute(db.db, "ROLLBACK", nil)
		return fmt.Errorf("%w: getting timestamps: %v", ErrDatabaseFailure, err)
	}

	// Insert platforms if provided
	if len(game.Platforms) > 0 {
		platformQuery := `
		INSERT INTO video_game_platforms (video_game_id, platform)
		VALUES (:1, :2)
		`

		for _, platform := range game.Platforms {
			err = sqlitex.Execute(db.db, platformQuery, &sqlitex.ExecOptions{
				Args: []interface{}{game.ID, platform},
			})
			if err != nil {
				sqlitex.Execute(db.db, "ROLLBACK", nil)
				return fmt.Errorf("%w: insert platform %s: %v", ErrDatabaseFailure, platform, err)
			}
		}
	}

	// Commit the transaction
	if err := sqlitex.Execute(db.db, "COMMIT", nil); err != nil {
		// Try to roll back if commit fails
		sqlitex.Execute(db.db, "ROLLBACK", nil)
		return fmt.Errorf("%w: failed to commit transaction: %v", ErrDatabaseFailure, err)
	}

	return nil
}

// GetVideoGame retrieves a video game entry by ID, including its platforms
func (db *SqliteDatabase) GetVideoGame(id uint64) (*VideoGame, error) {
	// First, get the main video game data
	query := `
	SELECT id, title, developer, cover_art_url, is_favorite, is_watchlist, created_at, updated_at
	FROM video_games
	WHERE id = :1
	`

	var game VideoGame

	stmt := db.db.Prep(query)
	defer stmt.Reset()

	stmt.SetInt64(":1", int64(id))

	if hasRow, err := stmt.Step(); err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	} else if !hasRow {
		return nil, ErrNotFound
	}

	game.ID = uint64(stmt.ColumnInt64(0))
	game.Title = stmt.ColumnText(1)
	game.Developer = stmt.ColumnText(2)
	game.CoverArtURL = stmt.ColumnText(3)
	game.IsFavorite = stmt.ColumnBool(4)
	game.IsWatchlist = stmt.ColumnBool(5)
	game.CreatedAt = stmt.ColumnText(6)
	game.UpdatedAt = stmt.ColumnText(7)

	// Then, get the platforms
	platformQuery := `
	SELECT platform
	FROM video_game_platforms
	WHERE video_game_id = :1
	ORDER BY platform
	`

	platformStmt := db.db.Prep(platformQuery)
	defer platformStmt.Reset()

	platformStmt.SetInt64(":1", int64(id))

	game.Platforms = []string{}
	for {
		hasRow, err := platformStmt.Step()
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
		if !hasRow {
			break
		}

		platform := platformStmt.ColumnText(0)
		game.Platforms = append(game.Platforms, platform)
	}

	return &game, nil
}

// AddSuggestion adds a new suggestion to the database
func (db *SqliteDatabase) AddSuggestion(mediaID uint64, mediaType MediaType, reason string, outcome SuggestionOutcome) error {
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
	VALUES (:1, :2, :3)
	`, tableName, idColumn)

	err := sqlitex.Execute(db.db, query, &sqlitex.ExecOptions{
		Args: []interface{}{mediaID, reason, string(outcome)},
	})
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	return nil
}

// UpdateFavoriteStatus updates the favorite status of an item
func (db *SqliteDatabase) UpdateFavoriteStatus(id uint64, mediaType MediaType, isFavorite bool) error {
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
	SET is_favorite = :1, updated_at = CURRENT_TIMESTAMP
	WHERE id = :2
	`, tableName)

	err := sqlitex.Execute(db.db, query, &sqlitex.ExecOptions{
		Args: []interface{}{isFavorite, id},
	})
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	// Check if any rows were affected
	var rowsAffected int
	err = sqlitex.Execute(db.db, "SELECT changes()", &sqlitex.ExecOptions{
		ResultFunc: func(stmt *sqlite.Stmt) error {
			rowsAffected = stmt.ColumnInt(0)
			return nil
		},
	})
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	if rowsAffected == 0 {
		return ErrNotFound
	}

	return nil
}

// UpdateWatchlistStatus updates the watchlist status of an item
func (db *SqliteDatabase) UpdateWatchlistStatus(id uint64, mediaType MediaType, isWatchlist bool) error {
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
	SET is_watchlist = :1, updated_at = CURRENT_TIMESTAMP
	WHERE id = :2
	`, tableName)

	err := sqlitex.Execute(db.db, query, &sqlitex.ExecOptions{
		Args: []interface{}{isWatchlist, id},
	})
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	// Check if any rows were affected
	var rowsAffected int
	err = sqlitex.Execute(db.db, "SELECT changes()", &sqlitex.ExecOptions{
		ResultFunc: func(stmt *sqlite.Stmt) error {
			rowsAffected = stmt.ColumnInt(0)
			return nil
		},
	})
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	if rowsAffected == 0 {
		return ErrNotFound
	}

	return nil
}

// AddConstraint adds a new constraint rule to the database
func (db *SqliteDatabase) AddConstraint(rule string, mediaType MediaType) error {
	query := `
	INSERT INTO constraints (rule, media)
	VALUES (:1, :2)
	`

	err := sqlitex.Execute(db.db, query, &sqlitex.ExecOptions{
		Args: []interface{}{rule, string(mediaType)},
	})
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	return nil
}

// GetConstraintsByMediaType retrieves all constraints for a specific media type
func (db *SqliteDatabase) GetConstraintsByMediaType(mediaType MediaType) ([]*Constraint, error) {
	query := `
	SELECT id, rule, media, created_at, updated_at
	FROM constraints
	WHERE media = :1 OR media = 'global'
	`

	var constraints []*Constraint

	err := sqlitex.Execute(db.db, query, &sqlitex.ExecOptions{
		Args: []interface{}{string(mediaType)},
		ResultFunc: func(stmt *sqlite.Stmt) error {
			var constraint Constraint

			constraint.ID = stmt.ColumnInt64(0)
			constraint.Rule = stmt.ColumnText(1)
			constraint.Media = MediaType(stmt.ColumnText(2))

			createdAt := stmt.ColumnText(3)
			updatedAt := stmt.ColumnText(4)

			var err error
			// Parse timestamps
			if constraint.CreatedAt, err = time.Parse(time.RFC3339, createdAt); err != nil {
				// Try parsing without RFC3339 for older sqlite versions that might not store it perfectly
				if constraint.CreatedAt, err = time.Parse("2006-01-02 15:04:05-07:00", createdAt); err != nil {
					log.Printf("WARN: Could not parse constraint.CreatedAt timestamp '%s': %v", createdAt, err)
				}
			}
			if constraint.UpdatedAt, err = time.Parse(time.RFC3339, updatedAt); err != nil {
				if constraint.UpdatedAt, err = time.Parse("2006-01-02 15:04:05-07:00", updatedAt); err != nil {
					log.Printf("WARN: Could not parse constraint.UpdatedAt timestamp '%s': %v", updatedAt, err)
				}
			}

			constraints = append(constraints, &constraint)
			return nil
		},
	})

	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	return constraints, nil
}

// --- Recommendation System Methods ---

// SaveMediaSuggestion saves a new suggestion or updates an existing one based on ID.
func (db *SqliteDatabase) SaveMediaSuggestion(ctx context.Context, s *models.MediaSuggestion) error {
	isNew := false
	if s.ID == "" {
		s.ID = uuid.NewString()
		isNew = true
		s.CreatedAt = time.Now()
	}
	now := time.Now()
	s.UpdatedAt = &now

	var err error

	if isNew {
		query := `
		INSERT INTO recommendations (id, query, media_type, title, artist, album, cover_art_url, description, wiki_url, wikidata_id, bot_reasoning, status, created_at, updated_at)
		VALUES (:1, :2, :3, :4, :5, :6, :7, :8, :9, :10, :11, :12, :13, :14)
		`

		err = sqlitex.Execute(db.db, query, &sqlitex.ExecOptions{
			Args: []interface{}{
				s.ID, s.Query, s.MediaType, s.Title, s.Artist, s.Album, s.CoverArtURL,
				s.Description, s.WikiURL, s.WikidataID, s.BotReasoning, string(s.Status),
				s.CreatedAt.Format(time.RFC3339), s.UpdatedAt.Format(time.RFC3339),
			},
		})
		if err != nil {
			return fmt.Errorf("%w: executing insert suggestion: %v", ErrDatabaseFailure, err)
		}
	} else {
		query := `
		UPDATE recommendations SET
			query = :1,
			media_type = :2,
			title = :3,
			artist = :4,
			album = :5,
			cover_art_url = :6,
			description = :7,
			wiki_url = :8,
			wikidata_id = :9,
			bot_reasoning = :10,
			status = :11,
			updated_at = :12 
		WHERE id = :13
		` // created_at is not updated

		err = sqlitex.Execute(db.db, query, &sqlitex.ExecOptions{
			Args: []interface{}{
				s.Query, s.MediaType, s.Title, s.Artist, s.Album, s.CoverArtURL,
				s.Description, s.WikiURL, s.WikidataID, s.BotReasoning, string(s.Status),
				s.UpdatedAt.Format(time.RFC3339), s.ID,
			},
		})
		if err != nil {
			return fmt.Errorf("%w: executing update suggestion: %v", ErrDatabaseFailure, err)
		}
	}

	return nil
}

// GetMediaSuggestionByID retrieves a specific suggestion by its unique ID.
func (db *SqliteDatabase) GetMediaSuggestionByID(ctx context.Context, id string) (*models.MediaSuggestion, error) {
	query := `
	SELECT id, query, media_type, title, artist, album, cover_art_url, description, wiki_url, wikidata_id, bot_reasoning, status, created_at, updated_at
	FROM recommendations
	WHERE id = :1
	`

	stmt := db.db.Prep(query)
	defer stmt.Reset()

	stmt.SetText(":1", id)

	hasRow, err := stmt.Step()
	if err != nil {
		return nil, fmt.Errorf("%w: querying suggestion: %v", ErrDatabaseFailure, err)
	}
	if !hasRow {
		return nil, ErrNotFound
	}

	var s models.MediaSuggestion

	s.ID = stmt.ColumnText(0)
	s.Query = stmt.ColumnText(1)
	s.MediaType = stmt.ColumnText(2)

	// Handle potential NULL values for string pointer fields
	if !stmt.ColumnIsNull(3) {
		title := stmt.ColumnText(3)
		s.Title = &title
	}
	
	if !stmt.ColumnIsNull(4) {
		artist := stmt.ColumnText(4)
		s.Artist = &artist
	}
	
	if !stmt.ColumnIsNull(5) {
		album := stmt.ColumnText(5)
		s.Album = &album
	}
	
	if !stmt.ColumnIsNull(6) {
		coverArtURL := stmt.ColumnText(6)
		s.CoverArtURL = &coverArtURL
	}
	
	if !stmt.ColumnIsNull(7) {
		description := stmt.ColumnText(7)
		s.Description = &description
	}
	
	if !stmt.ColumnIsNull(8) {
		wikiURL := stmt.ColumnText(8)
		s.WikiURL = &wikiURL
	}
	
	if !stmt.ColumnIsNull(9) {
		wikidataID := stmt.ColumnText(9)
		s.WikidataID = &wikidataID
	}
	
	if !stmt.ColumnIsNull(10) {
		botReasoning := stmt.ColumnText(10)
		s.BotReasoning = &botReasoning
	}
	
	s.Status = models.SuggestionStatus(stmt.ColumnText(11))

	createdAtStr := stmt.ColumnText(12)
	var updatedAtStr string
	if !stmt.ColumnIsNull(13) {
		updatedAtStr = stmt.ColumnText(13)
	}

	var parseErr error
	s.CreatedAt, parseErr = time.Parse(time.RFC3339, createdAtStr)
	if parseErr != nil {
		// Fallback for different timestamp formats that might be in the DB
		s.CreatedAt, parseErr = time.Parse("2006-01-02 15:04:05-07:00", createdAtStr)
		if parseErr != nil {
			s.CreatedAt, parseErr = time.Parse("2006-01-02T15:04:05Z", createdAtStr) // ISO8601 UTC
			if parseErr != nil {
				log.Printf("WARN: Could not parse GetMediaSuggestionByID.CreatedAt timestamp '%s': %v", createdAtStr, parseErr)
			}
		}
	}

	if updatedAtStr != "" {
		updatedAt, parseErr := time.Parse(time.RFC3339, updatedAtStr)
		if parseErr != nil {
			updatedAt, parseErr = time.Parse("2006-01-02 15:04:05-07:00", updatedAtStr)
			if parseErr != nil {
				updatedAt, parseErr = time.Parse("2006-01-02T15:04:05Z", updatedAtStr)
				if parseErr != nil {
					log.Printf("WARN: Could not parse GetMediaSuggestionByID.UpdatedAt timestamp '%s': %v", updatedAtStr, parseErr)
				}
			}
		}
		if parseErr == nil {
			s.UpdatedAt = &updatedAt
		}
	}

	return &s, nil
}

// GetAllMediaSuggestions retrieves a list of suggestions, optionally filtered by media type and status.
func (db *SqliteDatabase) GetAllMediaSuggestions(ctx context.Context, mediaType string, statusFilter models.SuggestionStatus, limit int, offset int) ([]*models.MediaSuggestion, error) {
	var args []interface{}
	queryBuilder := strings.Builder{}
	queryBuilder.WriteString(`
	SELECT id, query, media_type, title, artist, album, cover_art_url, description, wiki_url, wikidata_id, bot_reasoning, status, created_at, updated_at
	FROM recommendations
	`)

	conditions := []string{}
	if mediaType != "" {
		conditions = append(conditions, "media_type = :1")
		args = append(args, mediaType)
	}
	if statusFilter != "" {
		conditions = append(conditions, "status = :2")
		args = append(args, string(statusFilter))
	}

	if len(conditions) > 0 {
		queryBuilder.WriteString(" WHERE ")
		queryBuilder.WriteString(strings.Join(conditions, " AND "))
	}

	queryBuilder.WriteString(" ORDER BY created_at DESC")

	if limit > 0 {
		queryBuilder.WriteString(" LIMIT :3")
		args = append(args, limit)
	}
	if offset > 0 {
		queryBuilder.WriteString(" OFFSET :4")
		args = append(args, offset)
	}

	query := queryBuilder.String()
	stmt := db.db.Prep(query)
	defer stmt.Reset()

	// Bind parameters
	for i, arg := range args {
		switch v := arg.(type) {
		case string:
			stmt.SetText(fmt.Sprintf(":%d", i+1), v)
		case int:
			stmt.SetInt64(fmt.Sprintf(":%d", i+1), int64(v))
		case int64:
			stmt.SetInt64(fmt.Sprintf(":%d", i+1), v)
		case bool:
			stmt.SetBool(fmt.Sprintf(":%d", i+1), v)
		case []byte:
			stmt.SetBytes(fmt.Sprintf(":%d", i+1), v)
		default:
			stmt.SetText(fmt.Sprintf(":%d", i+1), fmt.Sprintf("%v", v))
		}
	}

	var suggestions []*models.MediaSuggestion

	for {
		hasRow, err := stmt.Step()
		if err != nil {
			return nil, fmt.Errorf("%w: querying suggestions: %v", ErrDatabaseFailure, err)
		}
		if !hasRow {
			break
		}

		var s models.MediaSuggestion
		s.ID = stmt.ColumnText(0)
		s.Query = stmt.ColumnText(1)
		s.MediaType = stmt.ColumnText(2)

		// Handle potential NULL values for string pointer fields
		if !stmt.ColumnIsNull(3) {
			title := stmt.ColumnText(3)
			s.Title = &title
		}
		
		if !stmt.ColumnIsNull(4) {
			artist := stmt.ColumnText(4)
			s.Artist = &artist
		}
		
		if !stmt.ColumnIsNull(5) {
			album := stmt.ColumnText(5)
			s.Album = &album
		}
		
		if !stmt.ColumnIsNull(6) {
			coverArtURL := stmt.ColumnText(6)
			s.CoverArtURL = &coverArtURL
		}
		
		if !stmt.ColumnIsNull(7) {
			description := stmt.ColumnText(7)
			s.Description = &description
		}
		
		if !stmt.ColumnIsNull(8) {
			wikiURL := stmt.ColumnText(8)
			s.WikiURL = &wikiURL
		}
		
		if !stmt.ColumnIsNull(9) {
			wikidataID := stmt.ColumnText(9)
			s.WikidataID = &wikidataID
		}
		
		if !stmt.ColumnIsNull(10) {
			botReasoning := stmt.ColumnText(10)
			s.BotReasoning = &botReasoning
		}
		
		s.Status = models.SuggestionStatus(stmt.ColumnText(11))

		createdAtStr := stmt.ColumnText(12)
		var updatedAtStr string
		if !stmt.ColumnIsNull(13) {
			updatedAtStr = stmt.ColumnText(13)
		}

		var parseErr error
		s.CreatedAt, parseErr = time.Parse(time.RFC3339, createdAtStr)
		if parseErr != nil {
			s.CreatedAt, parseErr = time.Parse("2006-01-02 15:04:05-07:00", createdAtStr)
			if parseErr != nil {
				s.CreatedAt, parseErr = time.Parse("2006-01-02T15:04:05Z", createdAtStr)
				if parseErr != nil {
					log.Printf("WARN: Could not parse GetAllMediaSuggestions.CreatedAt timestamp '%s': %v", createdAtStr, parseErr)
				}
			}
		}

		if updatedAtStr != "" {
			updatedAt, parseErr := time.Parse(time.RFC3339, updatedAtStr)
			if parseErr != nil {
				updatedAt, parseErr = time.Parse("2006-01-02 15:04:05-07:00", updatedAtStr)
				if parseErr != nil {
					updatedAt, parseErr = time.Parse("2006-01-02T15:04:05Z", updatedAtStr)
					if parseErr != nil {
						log.Printf("WARN: Could not parse GetAllMediaSuggestions.UpdatedAt timestamp '%s': %v", updatedAtStr, parseErr)
					}
				}
			}
			if parseErr == nil {
				s.UpdatedAt = &updatedAt
			}
		}

		suggestions = append(suggestions, &s)
	}

	return suggestions, nil
}

// GetPendingMediaSuggestions retrieves a list of pending suggestions for a specific media type.
func (db *SqliteDatabase) GetPendingMediaSuggestions(ctx context.Context, mediaType string, limit int) ([]*models.MediaSuggestion, error) {
	return db.GetAllMediaSuggestions(ctx, mediaType, models.StatusPending, limit, 0)
}

// UpdateMediaSuggestionStatus updates the status of an existing suggestion.
func (db *SqliteDatabase) UpdateMediaSuggestionStatus(ctx context.Context, id string, status models.SuggestionStatus) error {
	query := `
	UPDATE recommendations
	SET status = :1, updated_at = :2
	WHERE id = :3
	`

	now := time.Now().Format(time.RFC3339)

	stmt := db.db.Prep(query)
	defer stmt.Reset()

	stmt.SetText(":1", string(status))
	stmt.SetText(":2", now)
	stmt.SetText(":3", id)

	if _, err := stmt.Step(); err != nil {
		return fmt.Errorf("%w: updating suggestion status: %v", ErrDatabaseFailure, err)
	}

	return nil
}

// DeleteMediaSuggestion deletes a media suggestion by ID.
func (db *SqliteDatabase) DeleteMediaSuggestion(ctx context.Context, id string) error {
	query := `
	DELETE FROM recommendations
	WHERE id = :1
	`

	stmt := db.db.Prep(query)
	defer stmt.Reset()

	stmt.SetText(":1", id)

	if _, err := stmt.Step(); err != nil {
		return fmt.Errorf("%w: executing delete suggestion: %v", ErrDatabaseFailure, err)
	}

	// Check if the delete affected any rows
	var rowsAffected int
	err := sqlitex.Execute(db.db, "SELECT changes()", &sqlitex.ExecOptions{
		ResultFunc: func(stmt *sqlite.Stmt) error {
			rowsAffected = stmt.ColumnInt(0)
			return nil
		},
	})
	if err != nil {
		return fmt.Errorf("%w: checking rows affected on delete: %v", ErrDatabaseFailure, err)
	}

	if rowsAffected == 0 {
		return ErrNotFound // Or just return nil if not finding it is acceptable
	}
	return nil
}

// CountPendingMediaSuggestions counts pending suggestions for a specific media type.
func (db *SqliteDatabase) CountPendingMediaSuggestions(ctx context.Context, mediaType string) (int, error) {
	query := `
	SELECT COUNT(*)
	FROM recommendations
	WHERE media_type = :1 AND status = :2
	`

	stmt := db.db.Prep(query)
	defer stmt.Reset()

	stmt.SetText(":1", mediaType)
	stmt.SetText(":2", string(models.StatusPending))

	hasRow, err := stmt.Step()
	if err != nil {
		return 0, fmt.Errorf("%w: counting pending suggestions: %v", ErrDatabaseFailure, err)
	}
	if !hasRow {
		return 0, fmt.Errorf("%w: no rows returned for count query", ErrDatabaseFailure)
	}

	count := stmt.ColumnInt(0)
	return count, nil
}
