package db

// SchemaVersion tracks the current schema version
const SchemaVersion = 1

// Schema migrations as constants
const (
	// MusicTableSchema creates the music table
	MusicTableSchema = `
	CREATE TABLE IF NOT EXISTS music (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		title TEXT NOT NULL,
		artist TEXT NOT NULL,
		album TEXT,
		album_art_url TEXT,
		is_favorite BOOLEAN DEFAULT 0,
		is_watchlist BOOLEAN DEFAULT 0,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);
	CREATE INDEX IF NOT EXISTS idx_music_title ON music(title);
	CREATE INDEX IF NOT EXISTS idx_music_artist ON music(artist);
	CREATE INDEX IF NOT EXISTS idx_music_favorite ON music(is_favorite);
	CREATE INDEX IF NOT EXISTS idx_music_watchlist ON music(is_watchlist);
	`

	// BooksTableSchema creates the books table
	BooksTableSchema = `
	CREATE TABLE IF NOT EXISTS books (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		title TEXT NOT NULL,
		author TEXT NOT NULL,
		cover_art_url TEXT,
		is_favorite BOOLEAN DEFAULT 0,
		is_watchlist BOOLEAN DEFAULT 0,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);
	CREATE INDEX IF NOT EXISTS idx_books_title ON books(title);
	CREATE INDEX IF NOT EXISTS idx_books_author ON books(author);
	CREATE INDEX IF NOT EXISTS idx_books_favorite ON books(is_favorite);
	CREATE INDEX IF NOT EXISTS idx_books_watchlist ON books(is_watchlist);
	`

	// MoviesTableSchema creates the movies table
	MoviesTableSchema = `
	CREATE TABLE IF NOT EXISTS movies (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		title TEXT NOT NULL,
		director TEXT,
		writer TEXT,
		poster_url TEXT,
		is_favorite BOOLEAN DEFAULT 0,
		is_watchlist BOOLEAN DEFAULT 0,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);
	CREATE INDEX IF NOT EXISTS idx_movies_title ON movies(title);
	CREATE INDEX IF NOT EXISTS idx_movies_director ON movies(director);
	CREATE INDEX IF NOT EXISTS idx_movies_favorite ON movies(is_favorite);
	CREATE INDEX IF NOT EXISTS idx_movies_watchlist ON movies(is_watchlist);
	`

	// ShowsTableSchema creates the shows table
	ShowsTableSchema = `
	CREATE TABLE IF NOT EXISTS shows (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		title TEXT NOT NULL,
		director TEXT,
		writer TEXT,
		poster_url TEXT,
		is_favorite BOOLEAN DEFAULT 0,
		is_watchlist BOOLEAN DEFAULT 0,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);
	CREATE INDEX IF NOT EXISTS idx_shows_title ON shows(title);
	CREATE INDEX IF NOT EXISTS idx_shows_director ON shows(director);
	CREATE INDEX IF NOT EXISTS idx_shows_favorite ON shows(is_favorite);
	CREATE INDEX IF NOT EXISTS idx_shows_watchlist ON shows(is_watchlist);
	`

	// VideoGamesTableSchema creates the video_games table
	VideoGamesTableSchema = `
	CREATE TABLE IF NOT EXISTS video_games (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		title TEXT NOT NULL,
		developer TEXT,
		cover_art_url TEXT,
		is_favorite BOOLEAN DEFAULT 0,
		is_watchlist BOOLEAN DEFAULT 0,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);
	CREATE INDEX IF NOT EXISTS idx_video_games_title ON video_games(title);
	CREATE INDEX IF NOT EXISTS idx_video_games_developer ON video_games(developer);
	CREATE INDEX IF NOT EXISTS idx_video_games_favorite ON video_games(is_favorite);
	CREATE INDEX IF NOT EXISTS idx_video_games_watchlist ON video_games(is_watchlist);
	`

	// VideoGamePlatformsTableSchema creates the video_game_platforms table
	VideoGamePlatformsTableSchema = `
	CREATE TABLE IF NOT EXISTS video_game_platforms (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		video_game_id INTEGER NOT NULL,
		name TEXT NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (video_game_id) REFERENCES video_games(id) ON DELETE CASCADE
	);
	CREATE INDEX IF NOT EXISTS idx_video_game_platforms_game_id ON video_game_platforms(video_game_id);
	CREATE INDEX IF NOT EXISTS idx_video_game_platforms_name ON video_game_platforms(name);
	`

	// MusicSuggestionsTableSchema creates the music_suggestions table
	MusicSuggestionsTableSchema = `
	CREATE TABLE IF NOT EXISTS music_suggestions (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		music_id INTEGER NOT NULL,
		reason TEXT,
		outcome TEXT NOT NULL CHECK (outcome IN ('liked', 'disliked', 'skipped', 'added')),
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (music_id) REFERENCES music(id) ON DELETE CASCADE
	);
	CREATE INDEX IF NOT EXISTS idx_music_suggestions_music_id ON music_suggestions(music_id);
	CREATE INDEX IF NOT EXISTS idx_music_suggestions_outcome ON music_suggestions(outcome);
	`

	// BookSuggestionsTableSchema creates the book_suggestions table
	BookSuggestionsTableSchema = `
	CREATE TABLE IF NOT EXISTS book_suggestions (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		book_id INTEGER NOT NULL,
		reason TEXT,
		outcome TEXT NOT NULL CHECK (outcome IN ('liked', 'disliked', 'skipped', 'added')),
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
	);
	CREATE INDEX IF NOT EXISTS idx_book_suggestions_book_id ON book_suggestions(book_id);
	CREATE INDEX IF NOT EXISTS idx_book_suggestions_outcome ON book_suggestions(outcome);
	`

	// MovieSuggestionsTableSchema creates the movie_suggestions table
	MovieSuggestionsTableSchema = `
	CREATE TABLE IF NOT EXISTS movie_suggestions (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		movie_id INTEGER NOT NULL,
		reason TEXT,
		outcome TEXT NOT NULL CHECK (outcome IN ('liked', 'disliked', 'skipped', 'added')),
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (movie_id) REFERENCES movies(id) ON DELETE CASCADE
	);
	CREATE INDEX IF NOT EXISTS idx_movie_suggestions_movie_id ON movie_suggestions(movie_id);
	CREATE INDEX IF NOT EXISTS idx_movie_suggestions_outcome ON movie_suggestions(outcome);
	`

	// ShowSuggestionsTableSchema creates the show_suggestions table
	ShowSuggestionsTableSchema = `
	CREATE TABLE IF NOT EXISTS show_suggestions (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		show_id INTEGER NOT NULL,
		reason TEXT,
		outcome TEXT NOT NULL CHECK (outcome IN ('liked', 'disliked', 'skipped', 'added')),
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (show_id) REFERENCES shows(id) ON DELETE CASCADE
	);
	CREATE INDEX IF NOT EXISTS idx_show_suggestions_show_id ON show_suggestions(show_id);
	CREATE INDEX IF NOT EXISTS idx_show_suggestions_outcome ON show_suggestions(outcome);
	`

	// VideoGameSuggestionsTableSchema creates the video_game_suggestions table
	VideoGameSuggestionsTableSchema = `
	CREATE TABLE IF NOT EXISTS video_game_suggestions (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		video_game_id INTEGER NOT NULL,
		reason TEXT,
		outcome TEXT NOT NULL CHECK (outcome IN ('liked', 'disliked', 'skipped', 'added')),
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (video_game_id) REFERENCES video_games(id) ON DELETE CASCADE
	);
	CREATE INDEX IF NOT EXISTS idx_video_game_suggestions_video_game_id ON video_game_suggestions(video_game_id);
	CREATE INDEX IF NOT EXISTS idx_video_game_suggestions_outcome ON video_game_suggestions(outcome);
	`

	// ConstraintsTableSchema creates the constraints table
	ConstraintsTableSchema = `
	CREATE TABLE IF NOT EXISTS constraints (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		rule TEXT NOT NULL,
		media TEXT NOT NULL CHECK (media IN ('music', 'book', 'movie', 'show', 'video_game', 'global')),
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);
	CREATE INDEX IF NOT EXISTS idx_constraints_media ON constraints(media);
	`

	// SchemaVersionTableSchema creates a table to track schema versions
	SchemaVersionTableSchema = `
	CREATE TABLE IF NOT EXISTS schema_version (
		id INTEGER PRIMARY KEY CHECK (id = 1),
		version INTEGER NOT NULL,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);
	`

	// InitializeSchemaVersionSQL adds the initial schema version record
	InitializeSchemaVersionSQL = `
	INSERT OR REPLACE INTO schema_version (id, version) VALUES (1, ?);
	`
)

// AllMigrations contains all migration scripts in order
var AllMigrations = []string{
	SchemaVersionTableSchema,
	MusicTableSchema,
	BooksTableSchema,
	MoviesTableSchema,
	ShowsTableSchema,
	VideoGamesTableSchema,
	VideoGamePlatformsTableSchema,
	MusicSuggestionsTableSchema,
	BookSuggestionsTableSchema,
	MovieSuggestionsTableSchema,
	ShowSuggestionsTableSchema,
	VideoGameSuggestionsTableSchema,
	ConstraintsTableSchema,
}
