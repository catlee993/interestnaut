package suggestions

import (
	"context"
	"errors"
	
	"interestnaut/internal/app/db"
)

// LLMProvider defines the interface for any LLM-based suggestion provider
type LLMProvider interface {
	// GenerateSuggestions generates media suggestions using an LLM
	GenerateSuggestions(ctx context.Context, mediaType db.MediaType, basedOnInfo map[string]string, limit int) ([]Suggestion, error)
}

// DefaultLLMProvider is a placeholder implementation that will be replaced
// with a real LLM implementation in the future
type DefaultLLMProvider struct {
	// Configuration options for the LLM provider will go here
	// For example:
	// apiKey string
	// model string
	// temperature float64
}

// NewDefaultLLMProvider creates a new default LLM provider
func NewDefaultLLMProvider() *DefaultLLMProvider {
	return &DefaultLLMProvider{}
}

// GenerateSuggestions returns an error indicating that the real LLM provider
// has not been implemented yet
func (p *DefaultLLMProvider) GenerateSuggestions(ctx context.Context, mediaType db.MediaType, basedOnInfo map[string]string, limit int) ([]Suggestion, error) {
	return nil, errors.New("LLM suggestion provider not yet implemented")
}

// LLMConfig represents the configuration for an LLM integration
type LLMConfig struct {
	// Common configuration options for any LLM
	Provider     string  // e.g., "mistral", "openai", etc.
	Model        string  // The specific model to use
	APIKey       string  // API key for the service
	Temperature  float64 // Controls randomness (0.0-1.0)
	MaxTokens    int     // Maximum response length
	TopP         float64 // Controls diversity via nucleus sampling (0.0-1.0)
	ContextLimit int     // Maximum context window size
}

// AddLLMProvider adds an LLM provider to the Suggestion Service
func (s *Service) AddLLMProvider(provider LLMProvider) {
	s.llmProvider = provider
}
