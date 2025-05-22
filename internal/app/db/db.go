package db

import (
	"fmt"
	"log"

	"zombiezen.com/go/sqlite"
	"zombiezen.com/go/sqlite/sqlitex"
)

// DB is global
var DB Database

// SqliteDatabase implements the Database interface for SQLite
type SqliteDatabase struct {
	db *sqlite.Conn
}

// NewSqliteDatabase creates a new SQLite database implementation
func NewSqliteDatabase(db *sqlite.Conn) Database {
	return &SqliteDatabase{db: db}
}

// InitDB initializes the database and creates all necessary tables if they don't exist
func InitDB(path string) error {
	// Initialize the database connection
	conn, err := sqlite.OpenConn(path, sqlite.OpenReadWrite|sqlite.OpenCreate|sqlite.OpenFullMutex)
	if err != nil {
		log.Printf("Failed to open database: %v", err)
		return err
	}

	// Enable foreign keys and other pragmas
	pragmas := []string{
		"PRAGMA foreign_keys = ON",
		"PRAGMA journal_mode = WAL",
		"PRAGMA synchronous = NORMAL",
		"PRAGMA cache_size = 1000",
	}

	for _, pragma := range pragmas {
		if err := sqlitex.Execute(conn, pragma, nil); err != nil {
			log.Printf("Warning: Failed to execute pragma '%s': %v", pragma, err)
			// Continue anyway - not critical
		}
	}

	// Apply migrations if needed
	if err := applyMigrations(conn); err != nil {
		conn.Close()
		return fmt.Errorf("failed to apply migrations: %w", err)
	}

	// Initialize the global DB instance
	DB = NewSqliteDatabase(conn)

	log.Printf("Database initialized successfully at %s", path)
	return nil
}

// applyMigrations applies all necessary migrations
func applyMigrations(conn *sqlite.Conn) error {
	log.Println("Applying database migrations...")

	// Create the media_suggestions table if it doesn't exist
	createTableSQL := `
	CREATE TABLE IF NOT EXISTS media_suggestions (
		id TEXT PRIMARY KEY,
		query TEXT NOT NULL,
		title TEXT,
		artist TEXT,
		media_type TEXT NOT NULL,
		bot_reasoning TEXT,
		status TEXT NOT NULL DEFAULT 'pending',
		wikidata_id TEXT,
		wiki_url TEXT,
		description TEXT,
		created_at TEXT NOT NULL,
		updated_at TEXT NOT NULL
	);
	`

	err := sqlitex.Execute(conn, createTableSQL, nil)
	if err != nil {
		return fmt.Errorf("failed to create media_suggestions table: %w", err)
	}

	// Add indices for commonly queried fields
	indices := []string{
		`CREATE INDEX IF NOT EXISTS idx_media_suggestions_status ON media_suggestions(status);`,
		`CREATE INDEX IF NOT EXISTS idx_media_suggestions_media_type ON media_suggestions(media_type);`,
		`CREATE INDEX IF NOT EXISTS idx_media_suggestions_created_at ON media_suggestions(created_at);`,
	}

	for _, indexSQL := range indices {
		if err := sqlitex.Execute(conn, indexSQL, nil); err != nil {
			log.Printf("Warning: Failed to create index: %v", err)
			// Continue anyway - indices are not critical
		}
	}

	log.Println("Database migrations applied successfully")
	return nil
}
