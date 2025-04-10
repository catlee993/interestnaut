package openai

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// SuggestionOutcome represents what happened with a suggestion
type SuggestionOutcome string

const (
	OutcomeLiked    SuggestionOutcome = "liked"
	OutcomeDisliked SuggestionOutcome = "disliked"
	OutcomeSkipped  SuggestionOutcome = "skipped"
	OutcomeAdded    SuggestionOutcome = "added_to_library"
	OutcomePending  SuggestionOutcome = "pending"
)

// SuggestionRecord stores information about a suggested song and what happened
type SuggestionRecord struct {
	Name       string            `json:"name"`
	Artist     string            `json:"artist"`
	Album      string            `json:"album,omitempty"`
	SpotifyID  string            `json:"spotify_id,omitempty"`
	Outcome    SuggestionOutcome `json:"outcome"`
	Reason     string            `json:"reason,omitempty"`      // AI's reason for suggesting
	Timestamp  int64             `json:"timestamp"`             // Unix timestamp of suggestion
	FeedbackAt int64             `json:"feedback_at,omitempty"` // When user provided feedback
}

type Session struct {
	Messages       []Message                   `json:"messages"`
	UserID         string                      `json:"user_id"`
	SuggestedSongs map[string]SuggestionRecord `json:"suggested_songs"` // key: "name:artist"
}

type SessionManager struct {
	sessions map[string]*Session
	dataDir  string
	mu       sync.RWMutex
}

func NewSessionManager() (*SessionManager, error) {
	// Create data directory in user's home directory
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("failed to get user home directory: %w", err)
	}
	dataDir := filepath.Join(homeDir, ".interestnaut", "sessions")
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create data directory: %w", err)
	}

	sm := &SessionManager{
		sessions: make(map[string]*Session),
		dataDir:  dataDir,
	}

	// Load existing sessions
	files, err := os.ReadDir(dataDir)
	if err != nil {
		return nil, fmt.Errorf("failed to read data directory: %w", err)
	}

	for _, file := range files {
		if !file.IsDir() && strings.HasSuffix(file.Name(), ".json") {
			userID := strings.TrimSuffix(file.Name(), ".json")
			if err := sm.loadSession(userID); err != nil {
				log.Printf("Warning: Failed to load session for user %s: %v", userID, err)
			}
		}
	}

	return sm, nil
}

func (sm *SessionManager) loadSession(userID string) error {
	filePath := filepath.Join(sm.dataDir, userID+".json")
	log.Printf("Attempting to load session from file: %s", filePath)

	data, err := os.ReadFile(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			log.Printf("No session file exists for user %s", userID)
			return nil // Not an error if file doesn't exist
		}
		log.Printf("Failed to read session file for user %s: %v", userID, err)
		return fmt.Errorf("failed to read session file: %w", err)
	}

	var session Session
	if err := json.Unmarshal(data, &session); err != nil {
		log.Printf("Failed to unmarshal session for user %s: %v", userID, err)
		return fmt.Errorf("failed to unmarshal session: %w", err)
	}

	sm.mu.Lock()
	sm.sessions[userID] = &session
	sm.mu.Unlock()

	log.Printf("Successfully loaded session for user %s with %d messages", userID, len(session.Messages))
	return nil
}

func (sm *SessionManager) saveSession(session *Session) error {
	log.Printf("Saving session for user %s with %d messages", session.UserID, len(session.Messages))

	data, err := json.Marshal(session)
	if err != nil {
		log.Printf("Failed to marshal session for user %s: %v", session.UserID, err)
		return fmt.Errorf("failed to marshal session: %w", err)
	}

	filePath := filepath.Join(sm.dataDir, session.UserID+".json")
	log.Printf("Writing session to file: %s", filePath)

	if err := os.WriteFile(filePath, data, 0644); err != nil {
		log.Printf("Failed to write session file for user %s: %v", session.UserID, err)
		return fmt.Errorf("failed to write session file: %w", err)
	}

	log.Printf("Successfully saved session for user %s", session.UserID)
	return nil
}

func (sm *SessionManager) GetOrCreateSession(userID string) *Session {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	log.Printf("GetOrCreateSession called for user %s", userID)

	session, exists := sm.sessions[userID]
	if !exists {
		log.Printf("No session found in memory for user %s, trying to load from disk", userID)
		// Try to load from disk first
		if err := sm.loadSession(userID); err == nil {
			session = sm.sessions[userID]
			log.Printf("Successfully loaded session from disk for user %s", userID)
		} else {
			log.Printf("Failed to load session from disk for user %s: %v", userID, err)
		}
	} else {
		log.Printf("Found existing session in memory for user %s", userID)
	}

	// If still not found, create new session
	if session == nil {
		log.Printf("Creating new session for user %s", userID)
		session = &Session{
			UserID: userID,
			Messages: []Message{
				{
					Role: "system",
					Content: `You are a music recommendation assistant. Your goal is to understand the user's music preferences and suggest new music they might enjoy. Keep track of their likes and dislikes to improve your recommendations over time.

IMPORTANT RULES:
1. Never suggest the same song twice.
2. Always respond with suggestions in this exact JSON format:
{
  "name": "Song Name",
  "artist": "Artist Name",
  "album": "Album Name",  // Optional, omit if unknown
  "reason": "Detailed explanation of why this song matches their taste, referencing specific patterns in their library"
}

Do not include any other text in your response, only the JSON object.`,
				},
			},
			SuggestedSongs: make(map[string]SuggestionRecord),
		}
		sm.sessions[userID] = session
		if err := sm.saveSession(session); err != nil {
			log.Printf("Warning: failed to save new session: %v", err)
		} else {
			log.Printf("Successfully created and saved new session for user %s", userID)
		}
	}

	return session
}

func (sm *SessionManager) AddMessage(userID string, message Message) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	session, exists := sm.sessions[userID]
	if !exists {
		return fmt.Errorf("session not found for user %s", userID)
	}

	session.Messages = append(session.Messages, message)
	return sm.saveSession(session)
}

func (sm *SessionManager) GetMessages(userID string) ([]Message, error) {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	session, exists := sm.sessions[userID]
	if !exists {
		return nil, fmt.Errorf("session not found for user %s", userID)
	}

	return session.Messages, nil
}

func (sm *SessionManager) HasAnalyzedLibrary(userID string) bool {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	session, exists := sm.sessions[userID]
	if !exists {
		return false
	}

	// Check if we have any messages beyond the system message
	return len(session.Messages) > 1
}

// HasSuggested checks if a song has been suggested before
func (sm *SessionManager) HasSuggested(userID string, songName string, artistName string) bool {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	session, exists := sm.sessions[userID]
	if !exists {
		return false
	}

	key := fmt.Sprintf("%s|||%s", songName, artistName)
	_, exists = session.SuggestedSongs[key]
	return exists
}

// AddSuggestion records a new song suggestion
func (sm *SessionManager) AddSuggestion(userID string, record SuggestionRecord) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	session, exists := sm.sessions[userID]
	if !exists {
		return fmt.Errorf("session not found for user %s", userID)
	}

	// Normalize the key by trimming spaces and converting to lowercase
	key := fmt.Sprintf("%s|||%s", strings.ToLower(strings.TrimSpace(record.Name)), strings.ToLower(strings.TrimSpace(record.Artist)))
	record.Timestamp = time.Now().Unix()
	record.Outcome = OutcomePending
	session.SuggestedSongs[key] = record
	log.Printf("Added suggestion to session: %s (key: %s)", record.Name, key)
	return sm.saveSession(session)
}

// UpdateSuggestionOutcome updates the outcome of a previously suggested song
func (sm *SessionManager) UpdateSuggestionOutcome(userID string, songName string, artistName string, outcome SuggestionOutcome) error {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	session, exists := sm.sessions[userID]
	if !exists {
		log.Printf("ERROR: Session not found for user %s", userID)
		return fmt.Errorf("session not found for user %s", userID)
	}

	// Normalize inputs
	normalizedSongName := strings.ToLower(strings.TrimSpace(songName))
	normalizedArtistName := strings.ToLower(strings.TrimSpace(artistName))

	// Try different key formats
	possibleKeys := []string{
		fmt.Sprintf("%s|||%s", normalizedSongName, normalizedArtistName),
		fmt.Sprintf("%s - %s", normalizedArtistName, normalizedSongName), // Artist - Song format
		fmt.Sprintf("%s - %s", normalizedSongName, normalizedArtistName), // Song - Artist format
	}

	log.Printf("Looking for suggestion with normalized song: '%s', artist: '%s'", normalizedSongName, normalizedArtistName)
	log.Printf("Trying possible keys: %v", possibleKeys)
	log.Printf("Current suggestions in session: %v", session.SuggestedSongs)

	// Try each possible key format
	for _, key := range possibleKeys {
		if record, exists := session.SuggestedSongs[key]; exists {
			log.Printf("Found suggestion using key: '%s'", key)
			log.Printf("Previous outcome: %s, New outcome: %s", record.Outcome, outcome)
			record.Outcome = outcome
			record.FeedbackAt = time.Now().Unix()
			session.SuggestedSongs[key] = record
			if err := sm.saveSession(session); err != nil {
				log.Printf("ERROR: Failed to save session after updating outcome: %v", err)
				return err
			}
			log.Printf("Successfully updated and saved suggestion outcome")
			return nil
		}
	}

	// If no exact match found, try fuzzy matching
	log.Printf("No exact match found, trying fuzzy matching...")
	for k, record := range session.SuggestedSongs {
		recordSongName := strings.ToLower(strings.TrimSpace(record.Name))
		recordArtistName := strings.ToLower(strings.TrimSpace(record.Artist))

		// Check if either song name or artist name contains the other
		if (strings.Contains(recordSongName, normalizedSongName) || strings.Contains(normalizedSongName, recordSongName)) &&
			(strings.Contains(recordArtistName, normalizedArtistName) || strings.Contains(normalizedArtistName, recordArtistName)) {
			log.Printf("Found fuzzy match - Record: '%s' by '%s', Input: '%s' by '%s'",
				record.Name, record.Artist, songName, artistName)
			log.Printf("Previous outcome: %s, New outcome: %s", record.Outcome, outcome)
			record.Outcome = outcome
			record.FeedbackAt = time.Now().Unix()
			session.SuggestedSongs[k] = record
			if err := sm.saveSession(session); err != nil {
				log.Printf("ERROR: Failed to save session after updating outcome: %v", err)
				return err
			}
			log.Printf("Successfully updated and saved suggestion outcome")
			return nil
		}
	}

	log.Printf("ERROR: Failed to find suggestion with any matching method")
	return fmt.Errorf("suggestion not found: %s by %s", songName, artistName)
}

// GetSuggestionHistory returns all suggestions and their outcomes
func (sm *SessionManager) GetSuggestionHistory(userID string) ([]SuggestionRecord, error) {
	sm.mu.RLock()
	defer sm.mu.RUnlock()

	session, exists := sm.sessions[userID]
	if !exists {
		return nil, fmt.Errorf("session not found for user %s", userID)
	}

	history := make([]SuggestionRecord, 0, len(session.SuggestedSongs))
	for _, record := range session.SuggestedSongs {
		history = append(history, record)
	}
	return history, nil
}
