package db

import (
	"database/sql"
	"fmt"
	"log"

	_ "github.com/mattn/go-sqlite3"
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
	// Initialize the database connection
	sqlDB, err := sql.Open("sqlite3", path)
	if err != nil {
		log.Printf("Failed to open database: %v", err)
		return err
	}

	// Test the connection
	if err = sqlDB.Ping(); err != nil {
		log.Printf("Failed to ping database: %v", err)
		return err
	}

	// Enable foreign keys
	_, eErr := sqlDB.Exec("PRAGMA foreign_keys = ON")
	if eErr != nil {
		log.Printf("Failed to enable foreign keys: %v", eErr)
		sqlDB.Close()
		return eErr
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
