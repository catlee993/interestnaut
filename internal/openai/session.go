package openai

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
)

type Session struct {
	Messages []Message `json:"messages"`
	UserID   string    `json:"user_id"`
}

type SessionManager struct {
	mu       sync.RWMutex
	sessions map[string]*Session
	baseDir  string
}

func NewSessionManager() (*SessionManager, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return nil, fmt.Errorf("failed to get home directory: %w", err)
	}

	baseDir := filepath.Join(homeDir, ".interestnaut", "chat_sessions")
	if err := os.MkdirAll(baseDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create sessions directory: %w", err)
	}

	sm := &SessionManager{
		sessions: make(map[string]*Session),
		baseDir:  baseDir,
	}

	// Load existing sessions
	if err := sm.loadSessions(); err != nil {
		return nil, fmt.Errorf("failed to load sessions: %w", err)
	}

	return sm, nil
}

func (sm *SessionManager) loadSessions() error {
	files, err := os.ReadDir(sm.baseDir)
	if err != nil {
		return fmt.Errorf("failed to read sessions directory: %w", err)
	}

	for _, file := range files {
		if filepath.Ext(file.Name()) != ".json" {
			continue
		}

		data, err := os.ReadFile(filepath.Join(sm.baseDir, file.Name()))
		if err != nil {
			return fmt.Errorf("failed to read session file %s: %w", file.Name(), err)
		}

		var session Session
		if err := json.Unmarshal(data, &session); err != nil {
			return fmt.Errorf("failed to unmarshal session %s: %w", file.Name(), err)
		}

		sm.sessions[session.UserID] = &session
	}

	return nil
}

func (sm *SessionManager) saveSession(session *Session) error {
	data, err := json.MarshalIndent(session, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal session: %w", err)
	}

	filename := filepath.Join(sm.baseDir, fmt.Sprintf("%s.json", session.UserID))
	if err := os.WriteFile(filename, data, 0644); err != nil {
		return fmt.Errorf("failed to write session file: %w", err)
	}

	return nil
}

func (sm *SessionManager) GetOrCreateSession(userID string) *Session {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	session, exists := sm.sessions[userID]
	if !exists {
		session = &Session{
			UserID: userID,
			Messages: []Message{
				{
					Role:    "system",
					Content: "You are a music recommendation assistant. Your goal is to understand the user's music preferences and suggest new music they might enjoy. Keep track of their likes and dislikes to improve your recommendations over time.",
				},
			},
		}
		sm.sessions[userID] = session
		if err := sm.saveSession(session); err != nil {
			fmt.Printf("Warning: failed to save new session: %v\n", err)
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
