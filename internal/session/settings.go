package session

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
)

// Settings defines the interface for application settings
type Settings interface {
	GetContinuousPlayback() bool
	SetContinuousPlayback(context.Context, bool) error
	GetChatGPTModel() string
	SetChatGPTModel(context.Context, string) error
	GetLLMProvider() string
	SetLLMProvider(context.Context, string) error
	GetGeminiModel() string
	SetGeminiModel(context.Context, string) error
}

// settings implements the Settings interface
type settings struct {
	ContinuousPlayback bool   `json:"continuous_playback"`
	ChatGPTModel       string `json:"chatgpt_model"`
	LLMProvider        string `json:"llm_provider"`
	GeminiModel        string `json:"gemini_model"`
	path               string // This field is not serialized
}

// Default settings values
const (
	DefaultChatGPTModel = "gpt-4o"
	DefaultLLMProvider  = "openai"
	DefaultGeminiModel  = "gemini-1.5-pro"
)

// NewSettings creates a new settings instance or loads it from disk
func NewSettings(userID, dataDir string) (Settings, error) {
	filePath := filepath.Join(dataDir, fmt.Sprintf("%s%s", userID, SettingsSuffix))
	log.Printf("Attempting to load settings from file: %s", filePath)

	data, err := os.ReadFile(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			log.Printf("No settings file exists for user %s, creating default settings", userID)
			defaultSettings := &settings{
				ContinuousPlayback: false,
				ChatGPTModel:       DefaultChatGPTModel,
				LLMProvider:        DefaultLLMProvider,
				GeminiModel:        DefaultGeminiModel,
				path:               filePath,
			}
			if sErr := defaultSettings.saveSettings(); sErr != nil {
				return nil, fmt.Errorf("failed to save default settings: %w", sErr)
			}

			return defaultSettings, nil
		}
		log.Printf("Failed to read settings file %s: %v", filePath, err)
		return nil, fmt.Errorf("failed to read settings file: %w", err)
	}

	var s settings
	if err := json.Unmarshal(data, &s); err != nil {
		log.Printf("Failed to unmarshal settings: %v", err)
		return nil, fmt.Errorf("failed to unmarshal settings: %w", err)
	}

	// Set the path so the settings can be saved later
	s.path = filePath

	// Apply defaults for any missing values
	if s.ChatGPTModel == "" {
		s.ChatGPTModel = DefaultChatGPTModel
	}
	if s.LLMProvider == "" {
		s.LLMProvider = DefaultLLMProvider
	}
	if s.GeminiModel == "" {
		s.GeminiModel = DefaultGeminiModel
	}

	// Save if we had to set defaults
	if s.ChatGPTModel == DefaultChatGPTModel || s.LLMProvider == DefaultLLMProvider || s.GeminiModel == DefaultGeminiModel {
		if sErr := s.saveSettings(); sErr != nil {
			log.Printf("WARNING: Failed to save updated settings with defaults: %v", sErr)
		}
	}

	log.Printf("Successfully loaded settings for user %s: continuousPlayback=%v, chatGptModel=%s, llmProvider=%s, geminiModel=%s",
		userID, s.ContinuousPlayback, s.ChatGPTModel, s.LLMProvider, s.GeminiModel)

	return &s, nil
}

// ContinuousPlayback settings
func (s *settings) SetContinuousPlayback(_ context.Context, continuous bool) error {
	s.ContinuousPlayback = continuous
	return s.saveSettings()
}

func (s *settings) GetContinuousPlayback() bool {
	return s.ContinuousPlayback
}

// ChatGPT model settings
func (s *settings) GetChatGPTModel() string {
	if s.ChatGPTModel == "" {
		return DefaultChatGPTModel
	}
	return s.ChatGPTModel
}

func (s *settings) SetChatGPTModel(_ context.Context, model string) error {
	s.ChatGPTModel = model
	return s.saveSettings()
}

// LLM provider settings
func (s *settings) GetLLMProvider() string {
	if s.LLMProvider == "" {
		return DefaultLLMProvider
	}
	return s.LLMProvider
}

func (s *settings) SetLLMProvider(_ context.Context, provider string) error {
	s.LLMProvider = provider
	return s.saveSettings()
}

// Gemini model settings
func (s *settings) GetGeminiModel() string {
	if s.GeminiModel == "" {
		return DefaultGeminiModel
	}
	return s.GeminiModel
}

func (s *settings) SetGeminiModel(_ context.Context, model string) error {
	s.GeminiModel = model
	return s.saveSettings()
}

// saveSettings persists the settings to disk
func (s *settings) saveSettings() error {
	data, err := json.Marshal(s)
	if err != nil {
		log.Printf("Failed to marshal settings: %v", err)
		return fmt.Errorf("failed to marshal settings: %w", err)
	}

	log.Printf("Saving settings to file %s: continuousPlayback=%v, chatGptModel=%s, llmProvider=%s, geminiModel=%s",
		s.path, s.ContinuousPlayback, s.ChatGPTModel, s.LLMProvider, s.GeminiModel)

	if wErr := os.WriteFile(s.path, data, 0644); wErr != nil {
		log.Printf("Failed to write settings file: %v", wErr)
		return fmt.Errorf("failed to write settings file: %w", wErr)
	}

	log.Printf("Successfully saved settings to file: %s", s.path)
	return nil
}
