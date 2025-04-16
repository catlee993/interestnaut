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
	SetFavorites(context.Context, *Session[T], []T) error
	GetFavorites(context.Context, *Session[T]) ([]T, error)
	RemoveFavorite(context.Context, *Session[T], T) error
	Key() Key
}

type Settings interface {
	GetContinuousPlayback() bool
	SetContinuousPlayback(context.Context, bool) error
}

type CentralManager interface {
	Music() Manager[Music]
	Movie() Manager[Movie]
	Book() Manager[Book]
	TVShow() Manager[TVShow]
	VideoGame() Manager[VideoGame]
	Settings() Settings
}

type manager[T Media] struct {
	sessions map[Key]*Session[T]
	mu       sync.RWMutex
	dataDir  string
	key      Key
}

type settings struct {
	ContinuousPlayback bool `json:"continuous_playback"`
	path               string
}

type centralManager struct {
	musicManager     Manager[Music]
	movieManager     Manager[Movie]
	tvShowManager    Manager[TVShow]
	bookManager      Manager[Book]
	videoGameManager Manager[VideoGame]
	settings         Settings
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

	cm := &centralManager{
		musicManager:     newManager[Music](ctx, userID, dataDir, music),
		movieManager:     newManager[Movie](ctx, userID, dataDir, movie),
		tvShowManager:    newManager[TVShow](ctx, userID, dataDir, tv),
		bookManager:      newManager[Book](ctx, userID, dataDir, book),
		videoGameManager: newManager[VideoGame](ctx, userID, dataDir, videoGame),
	}
	sErr := cm.loadOrCreateSettings(userID, dataDir)

	return cm, sErr
}

func (cm centralManager) Music() Manager[Music] {
	return cm.musicManager
}

func (cm centralManager) Movie() Manager[Movie] {
	return cm.movieManager
}

func (cm centralManager) Book() Manager[Book] {
	return cm.bookManager
}

func (cm centralManager) TVShow() Manager[TVShow] {
	return cm.tvShowManager
}

func (cm centralManager) VideoGame() Manager[VideoGame] {
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

func (m *manager[T]) SetFavorites(ctx context.Context, session *Session[T], favorites []T) error {
	if session == nil {
		return fmt.Errorf("session is nil")
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	session.Content.Favorites = favorites

	return m.saveSession(ctx, session)
}

func (m *manager[T]) GetFavorites(ctx context.Context, session *Session[T]) ([]T, error) {
	if session == nil {
		return nil, fmt.Errorf("session is nil")
	}

	m.mu.RLock()
	defer m.mu.RUnlock()

	return session.Content.Favorites, nil
}

func (m *manager[T]) RemoveFavorite(ctx context.Context, session *Session[T], favorite T) error {
	if session == nil {
		return fmt.Errorf("session is nil")
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	for i, f := range session.Content.Favorites {
		if favorite.Equal(f) {
			session.Content.Favorites = append(session.Content.Favorites[:i], session.Content.Favorites[i+1:]...)
			break
		}
	}

	return m.saveSession(ctx, session)
}

func (cm *centralManager) Settings() Settings {
	return cm.settings
}

func (s *settings) SetContinuousPlayback(_ context.Context, continuous bool) error {
	s.ContinuousPlayback = continuous

	return s.saveSettings()
}

func (s *settings) GetContinuousPlayback() bool {
	return s.ContinuousPlayback
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

func (cm *centralManager) loadOrCreateSettings(userID, dataDir string) error {
	filePath := filepath.Join(dataDir, fmt.Sprintf("%s%s", userID, SettingsSuffix))
	log.Printf("Attempting to load settings from file: %s", filePath)

	data, err := os.ReadFile(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			log.Printf("No settings file exists for user %s, creating default settings", userID)
			defaultSettings := &settings{ContinuousPlayback: false, path: filePath}
			if sErr := defaultSettings.saveSettings(); err != nil {
				return fmt.Errorf("failed to save default settings: %w", sErr)
			}

			cm.settings = defaultSettings

			return nil
		}
		log.Printf("Failed to read settings file %s: %v", filePath, err)
		return fmt.Errorf("failed to read settings file: %w", err)
	}
	var sets settings
	if err := json.Unmarshal(data, &sets); err != nil {
		log.Printf("Failed to unmarshal settings: %v", err)
		return fmt.Errorf("failed to unmarshal settings: %w", err)
	}
	sets.path = filePath

	log.Printf("Successfully loaded settings for user %s", userID)

	cm.settings = &sets

	return nil
}

func (s *settings) saveSettings() error {
	data, err := json.Marshal(s)
	if err != nil {
		log.Printf("Failed to marshal settings: %v", err)
		return fmt.Errorf("failed to marshal settings: %w", err)
	}

	if wErr := os.WriteFile(s.path, data, 0644); err != nil {
		log.Printf("Failed to write settings file: %v", wErr)
		return fmt.Errorf("failed to write settings file: %w", wErr)
	}

	log.Printf("Successfully saved settings to file: %s", s.path)
	return nil
}
