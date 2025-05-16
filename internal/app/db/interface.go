package db

import (
	"database/sql"
	"context"
)

// Database defines the interface for all database operations
type Database interface {
	// Operations from operations.go
	AddMusic(music *Music) error
	GetMusic(id uint64) (*Music, error)
	AddBook(book *Book) error
	GetBook(id uint64) (*Book, error)
	AddMovie(movie *Movie) error
	GetMovie(id uint64) (*Movie, error)
	AddShow(show *Show) error
	GetShow(id uint64) (*Show, error)
	AddVideoGame(game *VideoGame) error
	GetVideoGame(id uint64) (*VideoGame, error)
	AddSuggestion(mediaID uint64, mediaType MediaType, reason string, outcome SuggestionOutcome) error
	UpdateFavoriteStatus(id uint64, mediaType MediaType, isFavorite bool) error
	UpdateWatchlistStatus(id uint64, mediaType MediaType, isWatchlist bool) error
	AddConstraint(rule string, mediaType MediaType) error
	GetConstraintsByMediaType(mediaType MediaType) ([]*Constraint, error)
	
	// Queries from queries.go
	SearchMusic(searchTerm string, options SearchOptions) ([]*Music, error)
	GetFavoriteMusic(options SearchOptions) ([]*Music, error)
	GetWatchlistMusic(options SearchOptions) ([]*Music, error)
	SearchBooks(searchTerm string, options SearchOptions) ([]*Book, error)
	GetFavoriteBooks(options SearchOptions) ([]*Book, error)
	SearchMovies(searchTerm string, options SearchOptions) ([]*Movie, error)
	SearchShows(searchTerm string, options SearchOptions) ([]*Show, error)
	SearchVideoGames(searchTerm string, options SearchOptions) ([]*VideoGame, error)
	GetSuggestionsByMedia(mediaID uint64, mediaType MediaType) ([]*Suggestion, error)
	GetAllSuggestions(options SearchOptions) ([]*Suggestion, error)
	GetAllConstraints() ([]*Constraint, error)
	CountItems(tableName string, onlyFavorites, onlyWatchlist bool) (int, error)
	
	// Transaction support
	BeginTx(ctx context.Context, opts *sql.TxOptions) (*sql.Tx, error)
	
	// Schema management
	GetSchemaVersion() (int, error)
}
