package session

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sync"
)

const (
	FavoritesSuffix string = "_favorites" + Ext
	QueuedSuffix    string = "_queued" + Ext
)

// FavoritesManager handles storage and retrieval of user favorites across all media types
type FavoritesManager struct {
	data     Favorites
	mu       sync.RWMutex
	filePath string
}

// QueuedManager handles storage and retrieval of user queued items across all media types
type QueuedManager struct {
	data     Queued
	mu       sync.RWMutex
	filePath string
}

// NewFavoritesManager creates a new favorites manager and loads existing data
func NewFavoritesManager(userID string, dataDir string) (*FavoritesManager, error) {
	filePath := filepath.Join(dataDir, fmt.Sprintf("%s%s", userID, FavoritesSuffix))

	fm := &FavoritesManager{
		filePath: filePath,
		data: Favorites{
			Movies:     []Movie{},
			Books:      []Book{},
			TVShows:    []TVShow{},
			VideoGames: []VideoGame{},
		},
	}

	if err := fm.load(); err != nil {
		log.Printf("WARNING: Failed to load favorites: %v", err)
	}

	return fm, nil
}

// NewQueuedManager creates a new queued items manager and loads existing data
func NewQueuedManager(userID string, dataDir string) (*QueuedManager, error) {
	filePath := filepath.Join(dataDir, fmt.Sprintf("%s%s", userID, QueuedSuffix))

	qm := &QueuedManager{
		filePath: filePath,
		data: Queued{
			Movies:     []Movie{},
			Books:      []Book{},
			TVShows:    []TVShow{},
			VideoGames: []VideoGame{},
		},
	}

	if err := qm.load(); err != nil {
		log.Printf("WARNING: Failed to load queued items: %v", err)
	}

	return qm, nil
}

// GetMovies returns all movie favorites
func (fm *FavoritesManager) GetMovies() []Movie {
	fm.mu.RLock()
	defer fm.mu.RUnlock()

	// Return a copy to prevent race conditions if the slice is modified
	result := make([]Movie, len(fm.data.Movies))
	copy(result, fm.data.Movies)
	return result
}

// AddMovie adds a movie to favorites if it doesn't already exist
func (fm *FavoritesManager) AddMovie(movie Movie) error {
	fm.mu.Lock()
	defer fm.mu.Unlock()

	// Check if movie already exists
	for _, m := range fm.data.Movies {
		if m.Equal(movie) {
			return nil // Already exists, no need to add
		}
	}

	// Add the movie
	fm.data.Movies = append(fm.data.Movies, movie)

	// Save immediately
	return fm.save()
}

// RemoveMovie removes a movie from favorites
func (fm *FavoritesManager) RemoveMovie(movie Movie) error {
	fm.mu.Lock()
	defer fm.mu.Unlock()

	// Find the movie
	found := false
	newMovies := make([]Movie, 0, len(fm.data.Movies))

	for _, m := range fm.data.Movies {
		if !m.Equal(movie) {
			newMovies = append(newMovies, m)
		} else {
			found = true
		}
	}

	if !found {
		return fmt.Errorf("movie not found in favorites")
	}

	fm.data.Movies = newMovies

	// Save immediately
	return fm.save()
}

// Similar methods for Books, TVShows, and VideoGames

// GetBooks returns all book favorites
func (fm *FavoritesManager) GetBooks() []Book {
	fm.mu.RLock()
	defer fm.mu.RUnlock()

	result := make([]Book, len(fm.data.Books))
	copy(result, fm.data.Books)
	return result
}

// AddBook adds a book to favorites if it doesn't already exist
func (fm *FavoritesManager) AddBook(book Book) error {
	fm.mu.Lock()
	defer fm.mu.Unlock()

	// Check if book already exists
	for _, b := range fm.data.Books {
		if b.Equal(book) {
			return nil
		}
	}

	fm.data.Books = append(fm.data.Books, book)

	return fm.save()
}

// RemoveBook removes a book from favorites
func (fm *FavoritesManager) RemoveBook(book Book) error {
	fm.mu.Lock()
	defer fm.mu.Unlock()

	found := false
	newBooks := make([]Book, 0, len(fm.data.Books))

	for _, b := range fm.data.Books {
		if !b.Equal(book) {
			newBooks = append(newBooks, b)
		} else {
			found = true
		}
	}

	if !found {
		return fmt.Errorf("book not found in favorites")
	}

	fm.data.Books = newBooks

	return fm.save()
}

// GetTVShows returns all TV show favorites
func (fm *FavoritesManager) GetTVShows() []TVShow {
	fm.mu.RLock()
	defer fm.mu.RUnlock()

	result := make([]TVShow, len(fm.data.TVShows))
	copy(result, fm.data.TVShows)
	return result
}

// AddTVShow adds a TV show to favorites if it doesn't already exist
func (fm *FavoritesManager) AddTVShow(tvShow TVShow) error {
	fm.mu.Lock()
	defer fm.mu.Unlock()

	// Check if TV show already exists
	for _, t := range fm.data.TVShows {
		if t.Equal(tvShow) {
			return nil
		}
	}

	fm.data.TVShows = append(fm.data.TVShows, tvShow)

	return fm.save()
}

// RemoveTVShow removes a TV show from favorites
func (fm *FavoritesManager) RemoveTVShow(tvShow TVShow) error {
	fm.mu.Lock()
	defer fm.mu.Unlock()

	found := false
	newTVShows := make([]TVShow, 0, len(fm.data.TVShows))

	for _, t := range fm.data.TVShows {
		if !t.Equal(tvShow) {
			newTVShows = append(newTVShows, t)
		} else {
			found = true
		}
	}

	if !found {
		return fmt.Errorf("TV show not found in favorites")
	}

	fm.data.TVShows = newTVShows

	return fm.save()
}

// GetVideoGames returns all video game favorites
func (fm *FavoritesManager) GetVideoGames() []VideoGame {
	fm.mu.RLock()
	defer fm.mu.RUnlock()

	result := make([]VideoGame, len(fm.data.VideoGames))
	copy(result, fm.data.VideoGames)
	return result
}

// AddVideoGame adds a video game to favorites if it doesn't already exist
func (fm *FavoritesManager) AddVideoGame(videoGame VideoGame) error {
	fm.mu.Lock()
	defer fm.mu.Unlock()

	// Check if video game already exists
	for _, v := range fm.data.VideoGames {
		if v.Equal(videoGame) {
			return nil
		}
	}

	fm.data.VideoGames = append(fm.data.VideoGames, videoGame)

	return fm.save()
}

// RemoveVideoGame removes a video game from favorites
func (fm *FavoritesManager) RemoveVideoGame(videoGame VideoGame) error {
	fm.mu.Lock()
	defer fm.mu.Unlock()

	found := false
	newVideoGames := make([]VideoGame, 0, len(fm.data.VideoGames))

	for _, v := range fm.data.VideoGames {
		if !v.Equal(videoGame) {
			newVideoGames = append(newVideoGames, v)
		} else {
			found = true
		}
	}

	if !found {
		return fmt.Errorf("video game not found in favorites")
	}

	fm.data.VideoGames = newVideoGames

	return fm.save()
}

// load loads favorites from disk
func (fm *FavoritesManager) load() error {
	// Check if file exists
	_, err := os.Stat(fm.filePath)
	if os.IsNotExist(err) {
		// File doesn't exist, initialize with empty data
		log.Printf("No favorites file exists at %s, initializing with empty data", fm.filePath)
		return fm.save() // Create the file
	}

	// Read the file
	data, err := os.ReadFile(fm.filePath)
	if err != nil {
		return fmt.Errorf("failed to read favorites file: %w", err)
	}

	// Unmarshal the data
	if err := json.Unmarshal(data, &fm.data); err != nil {
		return fmt.Errorf("failed to unmarshal favorites: %w", err)
	}

	log.Printf("Successfully loaded favorites with %d movies, %d books, %d TV shows, %d video games",
		len(fm.data.Movies), len(fm.data.Books), len(fm.data.TVShows), len(fm.data.VideoGames))

	return nil
}

// save saves favorites to disk
func (fm *FavoritesManager) save() error {
	// Marshal the data
	data, err := json.MarshalIndent(fm.data, "", "  ") // Pretty print for easier debugging
	if err != nil {
		return fmt.Errorf("failed to marshal favorites: %w", err)
	}

	// Write the file
	if err := os.WriteFile(fm.filePath, data, 0644); err != nil {
		return fmt.Errorf("failed to write favorites file: %w", err)
	}

	log.Printf("Successfully saved favorites to %s", fm.filePath)

	return nil
}

// QueuedManager methods

// GetMovies returns all movies in the queue
func (qm *QueuedManager) GetMovies() []Movie {
	qm.mu.RLock()
	defer qm.mu.RUnlock()

	result := make([]Movie, len(qm.data.Movies))
	copy(result, qm.data.Movies)
	return result
}

// AddMovie adds a movie to the queue if it doesn't already exist
func (qm *QueuedManager) AddMovie(movie Movie) error {
	qm.mu.Lock()
	defer qm.mu.Unlock()

	// Check if movie already exists
	for _, m := range qm.data.Movies {
		if m.Equal(movie) {
			return nil
		}
	}

	qm.data.Movies = append(qm.data.Movies, movie)

	return qm.save()
}

// RemoveMovie removes a movie from the queue
func (qm *QueuedManager) RemoveMovie(movie Movie) error {
	qm.mu.Lock()
	defer qm.mu.Unlock()

	found := false
	newMovies := make([]Movie, 0, len(qm.data.Movies))

	for _, m := range qm.data.Movies {
		if !m.Equal(movie) {
			newMovies = append(newMovies, m)
		} else {
			found = true
		}
	}

	if !found {
		return fmt.Errorf("movie not found in queue")
	}

	qm.data.Movies = newMovies

	return qm.save()
}

// Similar methods for Books, TVShows, and VideoGames
// GetBooks returns all books in the queue
func (qm *QueuedManager) GetBooks() []Book {
	qm.mu.RLock()
	defer qm.mu.RUnlock()

	result := make([]Book, len(qm.data.Books))
	copy(result, qm.data.Books)
	return result
}

// AddBook adds a book to the queue if it doesn't already exist
func (qm *QueuedManager) AddBook(book Book) error {
	qm.mu.Lock()
	defer qm.mu.Unlock()

	// Check if book already exists
	for _, b := range qm.data.Books {
		if b.Equal(book) {
			return nil
		}
	}

	qm.data.Books = append(qm.data.Books, book)

	return qm.save()
}

// RemoveBook removes a book from the queue
func (qm *QueuedManager) RemoveBook(book Book) error {
	qm.mu.Lock()
	defer qm.mu.Unlock()

	found := false
	newBooks := make([]Book, 0, len(qm.data.Books))

	for _, b := range qm.data.Books {
		if !b.Equal(book) {
			newBooks = append(newBooks, b)
		} else {
			found = true
		}
	}

	if !found {
		return fmt.Errorf("book not found in queue")
	}

	qm.data.Books = newBooks

	return qm.save()
}

// GetTVShows returns all TV shows in the queue
func (qm *QueuedManager) GetTVShows() []TVShow {
	qm.mu.RLock()
	defer qm.mu.RUnlock()

	result := make([]TVShow, len(qm.data.TVShows))
	copy(result, qm.data.TVShows)
	return result
}

// AddTVShow adds a TV show to the queue if it doesn't already exist
func (qm *QueuedManager) AddTVShow(tvShow TVShow) error {
	qm.mu.Lock()
	defer qm.mu.Unlock()

	// Check if TV show already exists
	for _, t := range qm.data.TVShows {
		if t.Equal(tvShow) {
			return nil
		}
	}

	qm.data.TVShows = append(qm.data.TVShows, tvShow)

	return qm.save()
}

// RemoveTVShow removes a TV show from the queue
func (qm *QueuedManager) RemoveTVShow(tvShow TVShow) error {
	qm.mu.Lock()
	defer qm.mu.Unlock()

	found := false
	newTVShows := make([]TVShow, 0, len(qm.data.TVShows))

	for _, t := range qm.data.TVShows {
		if !t.Equal(tvShow) {
			newTVShows = append(newTVShows, t)
		} else {
			found = true
		}
	}

	if !found {
		return fmt.Errorf("TV show not found in queue")
	}

	qm.data.TVShows = newTVShows

	return qm.save()
}

// GetVideoGames returns all video games in the queue
func (qm *QueuedManager) GetVideoGames() []VideoGame {
	qm.mu.RLock()
	defer qm.mu.RUnlock()

	result := make([]VideoGame, len(qm.data.VideoGames))
	copy(result, qm.data.VideoGames)
	return result
}

// AddVideoGame adds a video game to the queue if it doesn't already exist
func (qm *QueuedManager) AddVideoGame(videoGame VideoGame) error {
	qm.mu.Lock()
	defer qm.mu.Unlock()

	// Check if video game already exists
	for _, v := range qm.data.VideoGames {
		if v.Equal(videoGame) {
			return nil
		}
	}

	qm.data.VideoGames = append(qm.data.VideoGames, videoGame)

	return qm.save()
}

// RemoveVideoGame removes a video game from the queue
func (qm *QueuedManager) RemoveVideoGame(videoGame VideoGame) error {
	qm.mu.Lock()
	defer qm.mu.Unlock()

	found := false
	newVideoGames := make([]VideoGame, 0, len(qm.data.VideoGames))

	for _, v := range qm.data.VideoGames {
		if !v.Equal(videoGame) {
			newVideoGames = append(newVideoGames, v)
		} else {
			found = true
		}
	}

	if !found {
		return fmt.Errorf("video game not found in queue")
	}

	qm.data.VideoGames = newVideoGames

	return qm.save()
}

// load loads queue from disk
func (qm *QueuedManager) load() error {
	// Check if file exists
	_, err := os.Stat(qm.filePath)
	if os.IsNotExist(err) {
		// File doesn't exist, initialize with empty data
		log.Printf("No queued items file exists at %s, initializing with empty data", qm.filePath)
		return qm.save() // Create the file
	}

	// Read the file
	data, err := os.ReadFile(qm.filePath)
	if err != nil {
		return fmt.Errorf("failed to read queued items file: %w", err)
	}

	// Unmarshal the data
	if err := json.Unmarshal(data, &qm.data); err != nil {
		return fmt.Errorf("failed to unmarshal queued items: %w", err)
	}

	log.Printf("Successfully loaded queued items with %d movies, %d books, %d TV shows, %d video games",
		len(qm.data.Movies), len(qm.data.Books), len(qm.data.TVShows), len(qm.data.VideoGames))

	return nil
}

// save saves queue to disk
func (qm *QueuedManager) save() error {
	// Marshal the data
	data, err := json.MarshalIndent(qm.data, "", "  ") // Pretty print for easier debugging
	if err != nil {
		return fmt.Errorf("failed to marshal queued items: %w", err)
	}

	// Write the file
	if err := os.WriteFile(qm.filePath, data, 0644); err != nil {
		return fmt.Errorf("failed to write queued items file: %w", err)
	}

	log.Printf("Successfully saved queued items to %s", qm.filePath)

	return nil
}
