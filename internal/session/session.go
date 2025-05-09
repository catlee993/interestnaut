package session

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"sync"
)

type subject string

const (
	music     subject = "music"
	movie     subject = "movie"
	book      subject = "book"
	tv        subject = "tv"
	videoGame subject = "video_game"
)

type Manager[T Media] interface {
	GetOrCreateSession(ctx context.Context, key Key, directive, baseline func() string) *Session[T]
	GetSession(ctx context.Context, key Key) (*Session[T], error)
	AddSuggestion(context.Context, *Session[T], Suggestion[T]) error
	UpdateSuggestionOutcome(ctx context.Context, session *Session[T], suggestionKey string, outcome Outcome) error
	Key() Key
}

type FavoriteManager interface {
	GetMovies() []Movie
	GetBooks() []Book
	GetTVShows() []TVShow
	GetVideoGames() []VideoGame
	AddMovie(Movie) error
	AddBook(Book) error
	AddTVShow(TVShow) error
	AddVideoGame(VideoGame) error
	RemoveMovie(Movie) error
	RemoveBook(Book) error
	RemoveTVShow(TVShow) error
	RemoveVideoGame(VideoGame) error
}

type QueueManager interface {
	GetMovies() []Movie
	GetBooks() []Book
	GetTVShows() []TVShow
	GetVideoGames() []VideoGame
	AddMovie(Movie) error
	AddBook(Book) error
	AddTVShow(TVShow) error
	AddVideoGame(VideoGame) error
	RemoveMovie(Movie) error
	RemoveBook(Book) error
	RemoveTVShow(TVShow) error
	RemoveVideoGame(VideoGame) error
}

type CentralManager interface {
	Music() Manager[Music]
	Movie() Manager[Movie]
	Book() Manager[Book]
	TVShow() Manager[TVShow]
	VideoGame() Manager[VideoGame]
	Settings() Settings
	Favorites() FavoriteManager
	Queue() QueueManager
}

type manager[T Media] struct {
	sessions map[Key]*Session[T]
	mu       sync.RWMutex
	dataDir  string
	key      Key
}

type centralManager struct {
	musicManager     Manager[Music]
	movieManager     Manager[Movie]
	tvShowManager    Manager[TVShow]
	bookManager      Manager[Book]
	videoGameManager Manager[VideoGame]
	settings         Settings
	favoriteManager  FavoriteManager
	queueManager     QueueManager
	dataDir          string
	userID           string
}

func newManager[T Media](ctx context.Context, userID, dataDir string, subject subject) Manager[T] {
	m := &manager[T]{
		sessions: make(map[Key]*Session[T]),
		dataDir:  dataDir,
	}

	key := Key(fmt.Sprintf("%s_%s", userID, subject))
	m.key = key

	if err := m.loadSession(ctx, key); err != nil {
		log.Printf("Failed to load session for user %s: %v", userID, err)
	}

	return m
}

func NewCentralManager(ctx context.Context, userID string) (CentralManager, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("failed to get user home directory: %w", err)
	}
	dataDir := filepath.Join(homeDir, ".interestnaut", "sessions")
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create data directory: %w", err)
	}

	// Initialize favorites and queued managers first
	favoritesManager, err := NewFavoritesManager(userID, dataDir)
	if err != nil {
		log.Printf("WARNING: Failed to initialize favorites manager: %v", err)
		favoritesManager = &FavoritesManager{
			filePath: filepath.Join(dataDir, fmt.Sprintf("%s%s", userID, FavoritesSuffix)),
			data: Favorites{
				Movies:     []Movie{},
				Books:      []Book{},
				TVShows:    []TVShow{},
				VideoGames: []VideoGame{},
			},
		}
	}

	queuedManager, err := NewQueuedManager(userID, dataDir)
	if err != nil {
		log.Printf("WARNING: Failed to initialize queued manager: %v", err)
		queuedManager = &QueuedManager{
			filePath: filepath.Join(dataDir, fmt.Sprintf("%s%s", userID, QueuedSuffix)),
			data: Queued{
				Movies:     []Movie{},
				Books:      []Book{},
				TVShows:    []TVShow{},
				VideoGames: []VideoGame{},
			},
		}
	}

	cm := &centralManager{
		musicManager:     newManager[Music](ctx, userID, dataDir, music),
		movieManager:     newManager[Movie](ctx, userID, dataDir, movie),
		tvShowManager:    newManager[TVShow](ctx, userID, dataDir, tv),
		bookManager:      newManager[Book](ctx, userID, dataDir, book),
		videoGameManager: newManager[VideoGame](ctx, userID, dataDir, videoGame),
		favoriteManager:  favoritesManager,
		queueManager:     queuedManager,
		dataDir:          dataDir,
		userID:           userID,
	}
	sErr := cm.loadOrCreateSettings(userID, dataDir)

	return cm, sErr
}

func (cm *centralManager) Music() Manager[Music] {
	return cm.musicManager
}

func (cm *centralManager) Movie() Manager[Movie] {
	return cm.movieManager
}

func (cm *centralManager) Book() Manager[Book] {
	return cm.bookManager
}

func (cm *centralManager) TVShow() Manager[TVShow] {
	return cm.tvShowManager
}

func (cm *centralManager) VideoGame() Manager[VideoGame] {
	return cm.videoGameManager
}

func (m *manager[T]) Key() Key {
	return m.key
}

func (m *manager[T]) GetOrCreateSession(ctx context.Context, key Key, directive, baseline func() string) *Session[T] {
	m.mu.Lock()
	defer m.mu.Unlock()

	log.Printf("GetOrCreateSession called for key %s", key)

	session, exists := m.sessions[key]
	if !exists {
		log.Printf("No session found in memory for key %s, trying to load from disk", key)
		// Try to load from disk first
		if err := m.loadSession(ctx, key); err == nil {
			session = m.sessions[key]
			log.Printf("Successfully loaded session from disk for key %s", key)
		} else {
			log.Printf("Failed to load session from disk for key %s: %v", key, err)
		}
	} else {
		log.Printf("Found existing session in memory for key %s", key)
	}

	// If still not found, create new session
	if session == nil {
		log.Printf("Creating new session for key %s", key)
		session = composeSession[T](ctx, key, directive, baseline)
		m.sessions[key] = session
		if err := m.saveSession(ctx, session); err != nil {
			log.Printf("Warning: failed to save new session: %v", err)
		} else {
			log.Printf("Successfully created and saved new session for key %s", key)
		}
	}

	return session
}

func (m *manager[T]) GetSession(_ context.Context, key Key) (*Session[T], error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	session, exists := m.sessions[key]
	if !exists {
		log.Printf("No session found for key %s", key)
		return nil, fmt.Errorf("session not found")
	}

	return session, nil
}

func (m *manager[T]) AddSuggestion(
	ctx context.Context,
	session *Session[T],
	suggestion Suggestion[T],
) error {
	if m.hasSuggested(ctx, session, suggestion) {
		return fmt.Errorf("duplicate suggestion")
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	session.Suggestions[suggestion.Content.Key()] = suggestion

	return m.saveSession(ctx, session)
}

func (cm *centralManager) Favorites() FavoriteManager {
	return cm.favoriteManager
}

func (cm *centralManager) Queue() QueueManager {
	return cm.queueManager
}

func (cm *centralManager) Settings() Settings {
	return cm.settings
}

func (cm *centralManager) loadOrCreateSettings(userID, dataDir string) error {
	settings, err := NewSettings(userID, dataDir)
	if err != nil {
		return fmt.Errorf("failed to initialize settings: %w", err)
	}

	cm.settings = settings
	return nil
}

// UpdateSuggestionOutcome updates the outcome of a previously suggested song
func (m *manager[T]) UpdateSuggestionOutcome(
	ctx context.Context,
	session *Session[T],
	suggestionKey string,
	outcome Outcome,
) error {
	if session == nil {
		log.Printf("ERROR: Session is nil")
		return fmt.Errorf("session is nil")
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	// Get the suggestion directly from the map
	suggestion, exists := session.Suggestions[suggestionKey]
	if !exists {
		log.Printf("ERROR: Failed to find suggestion with key %s", suggestionKey)
		return fmt.Errorf("suggestion not found: %s", suggestionKey)
	}

	// Update the suggestion
	suggestion.UserOutcome = outcome
	// Update the map with the modified suggestion
	session.Suggestions[suggestionKey] = suggestion

	// Save the session
	sErr := m.saveSession(ctx, session)
	if sErr != nil {
		log.Printf("ERROR: Failed to save session after updating suggestion outcome: %v", sErr)
		return fmt.Errorf("failed to save session: %w", sErr)
	}

	return nil
}

func composeSession[T Media](
	_ context.Context,
	key Key,
	directive func() string,
	baseline func() string,
) *Session[T] {
	return &Session[T]{
		Key: key,
		Content: Content[T]{
			PrimeDirective: PrimeDirective{
				Task:     directive(),
				Baseline: baseline(),
			},
			Suggestions:     make(map[string]Suggestion[T]),
			UserConstraints: []string{},
		},
	}
}

func (m *manager[T]) loadSession(_ context.Context, key Key) error {
	filePath := filepath.Join(m.dataDir, fmt.Sprintf("%s%s", key, Ext))
	log.Printf("Attempting to load session from file: %s", filePath)

	data, err := os.ReadFile(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			log.Printf("No session file exists for key %s", key)
			return nil // Not an error if file doesn't exist
		}
		log.Printf("Failed to read session file for key %s: %v", key, err)
		return fmt.Errorf("failed to read session file: %w", err)
	}

	var session Session[T]
	session.Key = key
	if err := json.Unmarshal(data, &session); err != nil {
		log.Printf("Failed to unmarshal session for key %s: %v", key, err)
		return fmt.Errorf("failed to unmarshal session: %w", err)
	}

	m.mu.Lock()
	m.sessions[key] = &session
	m.mu.Unlock()

	log.Printf("Successfully loaded session for key %s with %d suggestions", key, len(session.Suggestions))
	return nil
}

func (m *manager[T]) saveSession(_ context.Context, session *Session[T]) error {
	if session == nil {
		log.Printf("Session is nil")
		return fmt.Errorf("session is nil")
	}

	data, err := json.Marshal(session)
	if err != nil {
		log.Printf("Failed to marshal session for key %s: %v", session.Key, err)
		return fmt.Errorf("failed to marshal session: %w", err)
	}

	filePath := filepath.Join(m.dataDir, fmt.Sprintf("%s%s", session.Key, ".json"))
	log.Printf("Writing session to file: %s", filePath)

	if err := os.WriteFile(filePath, data, 0644); err != nil {
		log.Printf("Failed to write session file for file %s: %v", session.Key, err)
		return fmt.Errorf("failed to write session file: %w", err)
	}

	log.Printf("Successfully saved session for key %s", session.Key)
	return nil
}

// hasSuggested checks if a song has been suggested before
func (m *manager[T]) hasSuggested(
	_ context.Context,
	session *Session[T],
	candidate Suggestion[T],
) bool {
	if session == nil {
		return false
	}

	m.mu.RLock()
	defer m.mu.RUnlock()

	for _, s := range session.Suggestions {
		if s.Content.Equal(candidate.Content) {
			return true
		}
	}
	return false
}

func (cm *centralManager) GetMovies() []Movie {
	return cm.favoriteManager.GetMovies()
}

func (cm *centralManager) GetBooks() []Book {
	return cm.favoriteManager.GetBooks()
}

func (cm *centralManager) GetTVShows() []TVShow {
	return cm.favoriteManager.GetTVShows()
}

func (cm *centralManager) GetVideoGames() []VideoGame {
	return cm.favoriteManager.GetVideoGames()
}

func (cm *centralManager) AddMovie(movie Movie) error {
	return cm.favoriteManager.AddMovie(movie)
}

func (cm *centralManager) AddBook(book Book) error {
	return cm.favoriteManager.AddBook(book)
}

func (cm *centralManager) AddTVShow(tvShow TVShow) error {
	return cm.favoriteManager.AddTVShow(tvShow)
}

func (cm *centralManager) AddVideoGame(videoGame VideoGame) error {
	return cm.favoriteManager.AddVideoGame(videoGame)
}

func (cm *centralManager) RemoveMovie(movie Movie) error {
	return cm.favoriteManager.RemoveMovie(movie)
}

func (cm *centralManager) RemoveBook(book Book) error {
	return cm.favoriteManager.RemoveBook(book)
}

func (cm *centralManager) RemoveTVShow(tvShow TVShow) error {
	return cm.favoriteManager.RemoveTVShow(tvShow)
}

func (cm *centralManager) RemoveVideoGame(videoGame VideoGame) error {
	return cm.favoriteManager.RemoveVideoGame(videoGame)
}

// Queued methods
func (cm *centralManager) GetMoviesQueued() []Movie {
	return cm.queueManager.GetMovies()
}

func (cm *centralManager) GetBooksQueued() []Book {
	return cm.queueManager.GetBooks()
}

func (cm *centralManager) GetTVShowsQueued() []TVShow {
	return cm.queueManager.GetTVShows()
}

func (cm *centralManager) GetVideoGamesQueued() []VideoGame {
	return cm.queueManager.GetVideoGames()
}

func (cm *centralManager) AddMovieQueued(movie Movie) error {
	return cm.queueManager.AddMovie(movie)
}

func (cm *centralManager) AddBookQueued(book Book) error {
	return cm.queueManager.AddBook(book)
}

func (cm *centralManager) AddTVShowQueued(tvShow TVShow) error {
	return cm.queueManager.AddTVShow(tvShow)
}

func (cm *centralManager) AddVideoGameQueued(videoGame VideoGame) error {
	return cm.queueManager.AddVideoGame(videoGame)
}

func (cm *centralManager) RemoveMovieQueued(movie Movie) error {
	return cm.queueManager.RemoveMovie(movie)
}

func (cm *centralManager) RemoveBookQueued(book Book) error {
	return cm.queueManager.RemoveBook(book)
}

func (cm *centralManager) RemoveTVShowQueued(tvShow TVShow) error {
	return cm.queueManager.RemoveTVShow(tvShow)
}

func (cm *centralManager) RemoveVideoGameQueued(videoGame VideoGame) error {
	return cm.queueManager.RemoveVideoGame(videoGame)
}
