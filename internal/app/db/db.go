package db

import (
	"database/sql"
	_ "github.com/mattn/go-sqlite3"
	"log"
)

func InitDB(path string) {
	// Initialize the database connection
	db, err := sql.Open("sqlite3", path)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	// Create the necessary tables if they don't exist
	//createTables(db)
}
