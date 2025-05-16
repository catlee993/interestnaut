package db

import (
	"database/sql"
	"fmt"
	"log"

	_ "github.com/mattn/go-sqlite3"
)

// InitDB initializes the database and creates all necessary tables if they don't exist
func InitDB(path string) (*sql.DB, error) {
	// Initialize the database connection
	db, err := sql.Open("sqlite3", path)
	if err != nil {
		log.Printf("Failed to open database: %v", err)
		return nil, err
	}

	// Enable foreign keys
	_, err = db.Exec("PRAGMA foreign_keys = ON")
	if err != nil {
		log.Printf("Failed to enable foreign keys: %v", err)
		db.Close()
		return nil, err
	}

	// Apply migrations if needed
	if err := applyMigrations(db); err != nil {
		log.Printf("Failed to apply migrations: %v", err)
		db.Close()
		return nil, err
	}

	log.Printf("Database initialized successfully at %s", path)
	return db, nil
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

// GetSchemaVersion returns the current schema version from the database
func GetSchemaVersion(db *sql.DB) (int, error) {
	var version int
	err := db.QueryRow("SELECT version FROM schema_version WHERE id = 1").Scan(&version)
	if err != nil {
		if err == sql.ErrNoRows {
			return 0, nil
		}
		return 0, err
	}
	return version, nil
}
