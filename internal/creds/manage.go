package creds

import (
	"errors"
	"fmt"
	"sync"

	keyring "github.com/zalando/go-keyring"
)

// ServiceName is the identifier used for the OS keyring service.
const ServiceName = "com.interestnaut.app"

var (
	// SpotifyRefreshTokenKey is the key used for storing the refresh token.
	SpotifyRefreshTokenKey = "SPOTIFY_REFRESH_TOKEN"
	TMDBAccessToken        = "TMDB_ACCESS_TOKEN"
	OpenAIKey              = "OPEN_API_KEY"
	GeminiKey              = "GEMINI_API_KEY"
)

// CredentialType identifies the type of credential
type CredentialType string

const (
	SpotifyCredential CredentialType = "spotify"
	TMDBCredential    CredentialType = "tmdb"
	OpenAICredential  CredentialType = "openai"
	GeminiCredential  CredentialType = "gemini"
)

// CredentialChangeListener is a function that will be called when a credential changes
type CredentialChangeListener func(credType CredentialType, action string)

var (
	listeners []CredentialChangeListener
	mu        sync.RWMutex
)

// RegisterChangeListener registers a function to be called when credentials change
func RegisterChangeListener(listener CredentialChangeListener) {
	mu.Lock()
	defer mu.Unlock()
	listeners = append(listeners, listener)
}

// notifyListeners notifies all registered listeners of a credential change
func notifyListeners(credType CredentialType, action string) {
	mu.RLock()
	defer mu.RUnlock()
	for _, listener := range listeners {
		listener(credType, action)
	}
}

// SaveSpotifyToken saves Spotify refresh token to the OS keychain.
func SaveSpotifyToken(token string) error {
	if err := keyring.Set(ServiceName, SpotifyRefreshTokenKey, token); err != nil {
		return fmt.Errorf("failed to set Spotify refresh token: %w", err)
	}
	notifyListeners(SpotifyCredential, "save")
	return nil
}

// GetSpotifyToken retrieves Spotify refresh token from the OS keychain.
func GetSpotifyToken() (string, error) {
	token, err := keyring.Get(ServiceName, SpotifyRefreshTokenKey)
	if err != nil {
		return "", fmt.Errorf("failed to get Spotify refresh token: %w", err)
	}
	return token, nil
}

// ClearSpotifyToken removes the Spotify refresh token from the OS keychain.
func ClearSpotifyToken() error {
	err := keyring.Delete(ServiceName, SpotifyRefreshTokenKey)
	if err != nil && !errors.Is(err, keyring.ErrNotFound) {
		// Ignore 'not found' errors, but return others
		return fmt.Errorf("failed to delete Spotify refresh token: %w", err)
	}
	notifyListeners(SpotifyCredential, "clear")
	return nil
}

// SaveOpenAIKey saves the OpenAI API key to the OS keychain.
func SaveOpenAIKey(apiKey string) error {
	if err := keyring.Set(ServiceName, OpenAIKey, apiKey); err != nil {
		return fmt.Errorf("failed to set OpenAI API key: %w", err)
	}
	notifyListeners(OpenAICredential, "save")
	return nil
}

// GetOpenAIKey retrieves the OpenAI API key from the OS keychain.
func GetOpenAIKey() (string, error) {
	apiKey, err := keyring.Get(ServiceName, OpenAIKey)
	if err != nil {
		return "", fmt.Errorf("failed to get OpenAI API key: %w", err)
	}
	return apiKey, nil
}

// ClearOpenAIKey removes the OpenAI API key from the OS keychain.
func ClearOpenAIKey() error {
	err := keyring.Delete(ServiceName, OpenAIKey)
	if err != nil && !errors.Is(err, keyring.ErrNotFound) {
		// Ignore 'not found' errors, but return others
		return fmt.Errorf("failed to delete OpenAI API key: %w", err)
	}
	notifyListeners(OpenAICredential, "clear")
	return nil
}

// SaveGeminiKey saves the Gemini API key to the OS keychain.
func SaveGeminiKey(apiKey string) error {
	if err := keyring.Set(ServiceName, GeminiKey, apiKey); err != nil {
		return fmt.Errorf("failed to set Gemini API key: %w", err)
	}
	notifyListeners(GeminiCredential, "save")
	return nil
}

// GetGeminiKey retrieves the Gemini API key from the OS keychain.
func GetGeminiKey() (string, error) {
	apiKey, err := keyring.Get(ServiceName, GeminiKey)
	if err != nil {
		return "", fmt.Errorf("failed to get Gemini API key: %w", err)
	}
	return apiKey, nil
}

// ClearGeminiKey removes the Gemini API key from the OS keychain.
func ClearGeminiKey() error {
	err := keyring.Delete(ServiceName, GeminiKey)
	if err != nil && !errors.Is(err, keyring.ErrNotFound) {
		// Ignore 'not found' errors, but return others
		return fmt.Errorf("failed to delete Gemini API key: %w", err)
	}
	notifyListeners(GeminiCredential, "clear")
	return nil
}

func SaveTMDBAccessToken(token string) error {
	if err := keyring.Set(ServiceName, TMDBAccessToken, token); err != nil {
		return fmt.Errorf("failed to set TMDB access token: %w", err)
	}
	notifyListeners(TMDBCredential, "save")
	return nil
}

func GetTMDBAccessToken() (string, error) {
	token, err := keyring.Get(ServiceName, TMDBAccessToken)
	if err != nil {
		return "", fmt.Errorf("failed to get TMDB access token: %w", err)
	}
	return token, nil
}

func ClearTMDBAccessToken() error {
	err := keyring.Delete(ServiceName, TMDBAccessToken)
	if err != nil && !errors.Is(err, keyring.ErrNotFound) {
		// Ignore 'not found' errors, but return others
		return fmt.Errorf("failed to delete TMDB access token: %w", err)
	}
	notifyListeners(TMDBCredential, "clear")
	return nil
}
