package db

import (
	"database/sql"
	"fmt"
	"log"

	_ "modernc.org/sqlite"
)

// DB is global
var DB Database

// SqliteDatabase implements the Database interface for SQLite
type SqliteDatabase struct {
	db *sql.DB
}

// NewSqliteDatabase creates a new SQLite database implementation
func NewSqliteDatabase(db *sql.DB) Database {
	return &SqliteDatabase{db: db}
}

// InitDB initializes the database and creates all necessary tables if they don't exist
func InitDB(path string) error {
	// Initialize the database connection with the pure Go SQLite driver
	// The connection string format is slightly different with modernc.org/sqlite
	connString := fmt.Sprintf("file:%s?_pragma=foreign_keys(1)&_pragma=busy_timeout(5000)", path)
	sqlDB, err := sql.Open("sqlite", connString)
	if err != nil {
		log.Printf("Failed to open database: %v", err)
		return err
	}

	// Configure the connection pool to minimize issues with signal handling
	// For SQLite, a single connection is safer and avoids goroutine signal issues
	sqlDB.SetMaxOpenConns(1)    // Only one connection in the pool
	sqlDB.SetMaxIdleConns(0)    // Close connections when not in use - no idle connections
	sqlDB.SetConnMaxLifetime(0) // Connections live until closed manually

	// Test the connection - this forces the driver to establish a real connection
	// instead of lazily creating it later in a background goroutine
	if err = sqlDB.Ping(); err != nil {
		log.Printf("Failed to ping database: %v", err)
		return err
	}

	// Always run a simple query to ensure proper initialization
	// This helps avoid lazy connection creation later
	var dummy int
	if err = sqlDB.QueryRow("SELECT 1").Scan(&dummy); err != nil {
		log.Printf("Failed initial test query: %v", err)
		return err
	}

	// Enable WAL mode for better concurrency
	_, walErr := sqlDB.Exec("PRAGMA journal_mode = WAL")
	if walErr != nil {
		log.Printf("Warning: Failed to enable WAL mode: %v", walErr)
		// Continue anyway - not critical
	}

	// Set other pragmas for better performance and stability
	pragmas := []string{
		"PRAGMA foreign_keys = ON",
		"PRAGMA synchronous = FULL", // Maximum safety - ensures data is on disk
		"PRAGMA cache_size = 1000", // Larger cache for better performance
	}

	for _, pragma := range pragmas {
		if _, pErr := sqlDB.Exec(pragma); pErr != nil {
			log.Printf("Warning: Failed to execute pragma '%s': %v", pragma, pErr)
			// Continue anyway - not critical
		}
	}

	// Apply migrations if needed
	if aErr := applyMigrations(sqlDB); aErr != nil {
		log.Printf("Failed to apply migrations: %v", aErr)
		sqlDB.Close()
		return aErr
	}

	log.Printf("Database initialized successfully at %s", path)
	// Create and set the global DB instance
	DB = NewSqliteDatabase(sqlDB)
	return nil
}

// applyMigrations applies all necessary migrations based on the current schema version
func applyMigrations(db *sql.DB) error {
	// Start a transaction for migration process
	tx, err := db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}

	// Ensure proper rollback on error
	defer func() {
		if err != nil {
			tx.Rollback()
		}
	}()

	// First create the schema_version table if it doesn't exist
	_, err = tx.Exec(SchemaVersionTableSchema)
	if err != nil {
		return fmt.Errorf("failed to create schema version table: %w", err)
	}

	// Check current schema version
	var currentVersion int
	err = tx.QueryRow("SELECT version FROM schema_version WHERE id = 1").Scan(&currentVersion)
	if err != nil {
		if err == sql.ErrNoRows {
			// No version found, this is a new database
			currentVersion = 0
		} else {
			return fmt.Errorf("failed to get current schema version: %w", err)
		}
	}

	log.Printf("Current schema version: %d, Target version: %d", currentVersion, SchemaVersion)

	// Apply all migrations if we need to upgrade
	if currentVersion < SchemaVersion {
		log.Printf("Applying database migrations from version %d to %d", currentVersion, SchemaVersion)

		// Apply all migrations in order
		for _, migration := range AllMigrations {
			_, err = tx.Exec(migration)
			if err != nil {
				return fmt.Errorf("migration failed: %w", err)
			}
		}

		// Update schema version
		_, err = tx.Exec(InitializeSchemaVersionSQL, SchemaVersion)
		if err != nil {
			return fmt.Errorf("failed to update schema version: %w", err)
		}

		log.Printf("Successfully applied migrations to version %d", SchemaVersion)
	}

	// Commit the transaction
	if err = tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	return nil
}
