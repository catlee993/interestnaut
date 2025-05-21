package db

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"interestnaut/internal/app/models"
	"log"
	"strings"
	"time"

	"github.com/google/uuid"
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
	CreatedAt   time.Time
	UpdatedAt   time.Time
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
	ID        uint64
	Rule      string
	Media     MediaType
	CreatedAt time.Time
	UpdatedAt time.Time
}

// AddMusic adds a new music entry to the database
func (db *SqliteDatabase) AddMusic(music *Music) error {
	query := `
	INSERT INTO music (title, artist, album, album_art_url, is_favorite, is_watchlist)
	VALUES (?, ?, ?, ?, ?, ?)
	`

	result, err := db.db.Exec(
		query,
		music.Title,
		music.Artist,
		music.Album,
		music.AlbumArtURL,
		music.IsFavorite,
		music.IsWatchlist,
	)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	music.ID = uint64(id)
	return nil
}

// GetMusic retrieves a music entry by ID
func (db *SqliteDatabase) GetMusic(id uint64) (*Music, error) {
	query := `
	SELECT id, title, artist, album, album_art_url, is_favorite, is_watchlist, created_at, updated_at
	FROM music
	WHERE id = ?
	`

	var music Music
	var createdAt, updatedAt string

	err := db.db.QueryRow(query, id).Scan(
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

	if err == sql.ErrNoRows {
		return nil, ErrNotFound
	} else if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	// Parse timestamps
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
	VALUES (?, ?, ?, ?, ?)
	`

	result, err := db.db.Exec(
		query,
		book.Title,
		book.Author,
		book.CoverArtURL,
		book.IsFavorite,
		book.IsWatchlist,
	)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	book.ID = uint64(id)
	return nil
}

// GetBook retrieves a book entry by ID
func (db *SqliteDatabase) GetBook(id uint64) (*Book, error) {
	query := `
	SELECT id, title, author, cover_art_url, is_favorite, is_watchlist, created_at, updated_at
	FROM books
	WHERE id = ?
	`

	var book Book
	var createdAt, updatedAt string

	err := db.db.QueryRow(query, id).Scan(
		&book.ID,
		&book.Title,
		&book.Author,
		&book.CoverArtURL,
		&book.IsFavorite,
		&book.IsWatchlist,
		&createdAt,
		&updatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, ErrNotFound
	} else if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	// Parse timestamps
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
	VALUES (?, ?, ?, ?, ?, ?)
	`

	result, err := db.db.Exec(
		query,
		movie.Title,
		movie.Director,
		movie.Writer,
		movie.PosterURL,
		movie.IsFavorite,
		movie.IsWatchlist,
	)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	movie.ID = uint64(id)
	return nil
}

// GetMovie retrieves a movie entry by ID
func (db *SqliteDatabase) GetMovie(id uint64) (*Movie, error) {
	query := `
	SELECT id, title, director, writer, poster_url, is_favorite, is_watchlist, created_at, updated_at
	FROM movies
	WHERE id = ?
	`

	var movie Movie
	var createdAt, updatedAt string

	err := db.db.QueryRow(query, id).Scan(
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

	if err == sql.ErrNoRows {
		return nil, ErrNotFound
	} else if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}

	// Parse timestamps
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
	VALUES (?, ?, ?, ?, ?, ?)
	`

	result, err := db.db.Exec(
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

	show.ID = uint64(id)
	return nil
}

// GetShow retrieves a show entry by ID
func (db *SqliteDatabase) GetShow(id uint64) (*Show, error) {
	query := `
	SELECT id, title, director, writer, poster_url, is_favorite, is_watchlist, created_at, updated_at
	FROM shows
	WHERE id = ?
	`

	var show Show
	var createdAt, updatedAt string

	err := db.db.QueryRow(query, id).Scan(
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
func (db *SqliteDatabase) AddVideoGame(game *VideoGame) error {
	// Begin transaction to handle both the video game and its platforms
	tx, err := db.db.Begin()
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
func (db *SqliteDatabase) GetVideoGame(id uint64) (*VideoGame, error) {
	// Get the video game
	gameQuery := `
	SELECT id, title, developer, cover_art_url, is_favorite, is_watchlist, created_at, updated_at
	FROM video_games
	WHERE id = ?
	`

	var game VideoGame
	err := db.db.QueryRow(gameQuery, id).Scan(
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

	rows, err := db.db.Query(platformsQuery, id)
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
	VALUES (?, ?, ?)
	`, tableName, idColumn)

	_, err := db.db.Exec(query, mediaID, reason, string(outcome))
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
	SET is_favorite = ?, updated_at = CURRENT_TIMESTAMP
	WHERE id = ?
	`, tableName)

	result, err := db.db.Exec(query, isFavorite, id)
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
	SET is_watchlist = ?, updated_at = CURRENT_TIMESTAMP
	WHERE id = ?
	`, tableName)

	result, err := db.db.Exec(query, isWatchlist, id)
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
func (db *SqliteDatabase) AddConstraint(rule string, mediaType MediaType) error {
	query := `
	INSERT INTO constraints (rule, media)
	VALUES (?, ?)
	`

	_, err := db.db.Exec(query, rule, string(mediaType))
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
	WHERE media = ? OR media = 'global'
	`

	rows, err := db.db.Query(query, mediaType)
	if err != nil {
		return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
	}
	defer rows.Close()

	var constraints []*Constraint
	for rows.Next() {
		var constraint Constraint
		var createdAt, updatedAt string
		if err := rows.Scan(
			&constraint.ID,
			&constraint.Rule,
			&constraint.Media,
			&createdAt,
			&updatedAt,
		); err != nil {
			return nil, fmt.Errorf("%w: %v", ErrDatabaseFailure, err)
		}
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

	query := `
	INSERT INTO recommendations (id, query, media_type, title, artist, album, cover_art_url, description, wiki_url, wikidata_id, bot_reasoning, status, created_at, updated_at)
	VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	ON CONFLICT(id) DO UPDATE SET
		query = excluded.query,
		media_type = excluded.media_type,
		title = excluded.title,
		artist = excluded.artist,
		album = excluded.album,
		cover_art_url = excluded.cover_art_url,
		description = excluded.description,
		wiki_url = excluded.wiki_url,
		wikidata_id = excluded.wikidata_id,
		bot_reasoning = excluded.bot_reasoning,
		status = excluded.status,
		updated_at = excluded.updated_at
	`
	// If it's a new record, use its own CreatedAt. If updating, keep original CreatedAt.
	// The ON CONFLICT clause for SQLite doesn't easily allow preserving created_at on update while setting it on insert.
	// So, if it's not new, we fetch current created_at first, or rely on the fact that we don't list created_at in the SET part for updates (but excluded.updated_at handles this example).
	// For simplicity and because the trigger handles updated_at, we can simplify the insert.
	// The trigger will update `updated_at` so we don't strictly need to set it in the query, but it's good practice.

	// For created_at, if it's an update, we want to preserve the original creation time.
	// The current UPSERT logic will use `excluded.created_at` if it's an update, which is not what we want.
	// We'll handle this by setting `created_at` only on `INSERT` and not touching it on `UPDATE`.

	var stmt *sql.Stmt
	var err error

	if isNew {
		query = `
		INSERT INTO recommendations (id, query, media_type, title, artist, album, cover_art_url, description, wiki_url, wikidata_id, bot_reasoning, status, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		`
		stmt, err = db.db.PrepareContext(ctx, query)
		if err != nil {
			return fmt.Errorf("%w: preparing insert: %v", ErrDatabaseFailure, err)
		}
		defer stmt.Close()
		_, err = stmt.ExecContext(ctx, s.ID, s.Query, s.MediaType, s.Title, s.Artist, s.Album, s.CoverArtURL, s.Description, s.WikiURL, s.WikidataID, s.BotReasoning, s.Status, s.CreatedAt, s.UpdatedAt)
	} else {
		query = `
		UPDATE recommendations SET
			query = ?,
			media_type = ?,
			title = ?,
			artist = ?,
			album = ?,
			cover_art_url = ?,
			description = ?,
			wiki_url = ?,
			wikidata_id = ?,
			bot_reasoning = ?,
			status = ?,
			updated_at = ? 
		WHERE id = ?
		` // created_at is not updated
		stmt, err = db.db.PrepareContext(ctx, query)
		if err != nil {
			return fmt.Errorf("%w: preparing update: %v", ErrDatabaseFailure, err)
		}
		defer stmt.Close()
		_, err = stmt.ExecContext(ctx, s.Query, s.MediaType, s.Title, s.Artist, s.Album, s.CoverArtURL, s.Description, s.WikiURL, s.WikidataID, s.BotReasoning, s.Status, s.UpdatedAt, s.ID)
	}

	if err != nil {
		return fmt.Errorf("%w: executing insert/update suggestion: %v", ErrDatabaseFailure, err)
	}
	return nil
}

// GetMediaSuggestionByID retrieves a specific suggestion by its unique ID.
func (db *SqliteDatabase) GetMediaSuggestionByID(ctx context.Context, id string) (*models.MediaSuggestion, error) {
	query := `
	SELECT id, query, media_type, title, artist, album, cover_art_url, description, wiki_url, wikidata_id, bot_reasoning, status, created_at, updated_at
	FROM recommendations
	WHERE id = ?
	`
	row := db.db.QueryRowContext(ctx, query, id)
	var s models.MediaSuggestion
	var createdAtStr string
	var updatedAtStr sql.NullString // updated_at can be NULL if using older sqlite versions or if not set by trigger initially

	err := row.Scan(
		&s.ID, &s.Query, &s.MediaType,
		&s.Title, &s.Artist, &s.Album, &s.CoverArtURL,
		&s.Description, &s.WikiURL, &s.WikidataID, &s.BotReasoning,
		&s.Status, &createdAtStr, &updatedAtStr,
	)

	if err == sql.ErrNoRows {
		return nil, ErrNotFound
	} else if err != nil {
		return nil, fmt.Errorf("%w: scanning suggestion: %v", ErrDatabaseFailure, err)
	}

	s.CreatedAt, err = time.Parse(time.RFC3339, createdAtStr) 
	if err != nil {
        // Fallback for different timestamp formats that might be in the DB
        s.CreatedAt, err = time.Parse("2006-01-02 15:04:05-07:00", createdAtStr)
        if err != nil {
            s.CreatedAt, err = time.Parse("2006-01-02T15:04:05Z", createdAtStr) // ISO8601 UTC
             if err != nil {
                log.Printf("WARN: Could not parse GetMediaSuggestionByID.CreatedAt timestamp '%s': %v", createdAtStr, err)
             }
        }
	}
	if updatedAtStr.Valid {
		updatedAt, parseErr := time.Parse(time.RFC3339, updatedAtStr.String)
        if parseErr != nil {
            updatedAt, parseErr = time.Parse("2006-01-02 15:04:05-07:00", updatedAtStr.String)
            if parseErr != nil {
                updatedAt, parseErr = time.Parse("2006-01-02T15:04:05Z", updatedAtStr.String)
                if parseErr != nil {
                     log.Printf("WARN: Could not parse GetMediaSuggestionByID.UpdatedAt timestamp '%s': %v", updatedAtStr.String, parseErr)
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
		conditions = append(conditions, "media_type = ?")
		args = append(args, mediaType)
	}
	if statusFilter != "" {
		conditions = append(conditions, "status = ?")
		args = append(args, statusFilter)
	}

	if len(conditions) > 0 {
		queryBuilder.WriteString(" WHERE ")
		queryBuilder.WriteString(strings.Join(conditions, " AND "))
	}

	queryBuilder.WriteString(" ORDER BY created_at DESC")

	if limit > 0 {
		queryBuilder.WriteString(" LIMIT ?")
		args = append(args, limit)
	}
	if offset > 0 {
		queryBuilder.WriteString(" OFFSET ?")
		args = append(args, offset)
	}

	rows, err := db.db.QueryContext(ctx, queryBuilder.String(), args...)
	if err != nil {
		return nil, fmt.Errorf("%w: querying suggestions: %v", ErrDatabaseFailure, err)
	}
	defer rows.Close()

	var suggestions []*models.MediaSuggestion
	for rows.Next() {
		var s models.MediaSuggestion
		var createdAtStr string
		var updatedAtStr sql.NullString
		if err := rows.Scan(
			&s.ID, &s.Query, &s.MediaType,
			&s.Title, &s.Artist, &s.Album, &s.CoverArtURL,
			&s.Description, &s.WikiURL, &s.WikidataID, &s.BotReasoning,
			&s.Status, &createdAtStr, &updatedAtStr,
		); err != nil {
			return nil, fmt.Errorf("%w: scanning suggestion in GetAll: %v", ErrDatabaseFailure, err)
		}
		s.CreatedAt, err = time.Parse(time.RFC3339, createdAtStr)
		if err != nil {
            s.CreatedAt, err = time.Parse("2006-01-02 15:04:05-07:00", createdAtStr)
            if err != nil {
                s.CreatedAt, err = time.Parse("2006-01-02T15:04:05Z", createdAtStr)
                if err != nil {
    			    log.Printf("WARN: Could not parse GetAllMediaSuggestions.CreatedAt timestamp '%s': %v", createdAtStr, err)
                }
            }
		}
		if updatedAtStr.Valid {
			updatedAt, parseErr := time.Parse(time.RFC3339, updatedAtStr.String)
            if parseErr != nil {
                updatedAt, parseErr = time.Parse("2006-01-02 15:04:05-07:00", updatedAtStr.String)
                if parseErr != nil {
                    updatedAt, parseErr = time.Parse("2006-01-02T15:04:05Z", updatedAtStr.String)
                    if parseErr != nil {
                        log.Printf("WARN: Could not parse GetAllMediaSuggestions.UpdatedAt timestamp '%s': %v", updatedAtStr.String, parseErr)
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
	query := `UPDATE recommendations SET status = ?, updated_at = ? WHERE id = ?`
	stmt, err := db.db.PrepareContext(ctx, query)
	if err != nil {
		return fmt.Errorf("%w: preparing update status: %v", ErrDatabaseFailure, err)
	}
	defer stmt.Close()

	result, err := stmt.ExecContext(ctx, status, time.Now(), id)
	if err != nil {
		return fmt.Errorf("%w: executing update status: %v", ErrDatabaseFailure, err)
	}
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("%w: getting rows affected: %v", ErrDatabaseFailure, err)
	}
	if rowsAffected == 0 {
		return ErrNotFound
	}
	return nil
}

// DeleteMediaSuggestion removes a suggestion from the database.
func (db *SqliteDatabase) DeleteMediaSuggestion(ctx context.Context, id string) error {
	query := `DELETE FROM recommendations WHERE id = ?`
	stmt, err := db.db.PrepareContext(ctx, query)
	if err != nil {
		return fmt.Errorf("%w: preparing delete suggestion: %v", ErrDatabaseFailure, err)
	}
	defer stmt.Close()

	result, err := stmt.ExecContext(ctx, id)
	if err != nil {
		return fmt.Errorf("%w: executing delete suggestion: %v", ErrDatabaseFailure, err)
	}
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("%w: getting rows affected on delete: %v", ErrDatabaseFailure, err)
	}
	if rowsAffected == 0 {
		return ErrNotFound // Or just return nil if not finding it is acceptable
	}
	return nil
}

// CountPendingMediaSuggestions counts pending suggestions for a specific media type.
func (db *SqliteDatabase) CountPendingMediaSuggestions(ctx context.Context, mediaType string) (int, error) {
	query := `SELECT COUNT(*) FROM recommendations WHERE media_type = ? AND status = ?`
	var count int
	err := db.db.QueryRowContext(ctx, query, mediaType, models.StatusPending).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("%w: counting pending suggestions: %v", ErrDatabaseFailure, err)
	}
	return count, nil
}
