package creds

import (
	"errors"
	"fmt"
	"sync"

	keyring "github.com/zalando/go-keyring"
)

const ServiceName = "com.interestnaut.app"

var (
	SpotifyRefreshTokenKey = "SPOTIFY_REFRESH_TOKEN"
	TMDBAccessToken        = "TMDB_ACCESS_TOKEN"
	OpenAIKey              = "OPEN_API_KEY"
	GeminiKey              = "GEMINI_API_KEY"
	RAWGApiKey             = "RAWG_API_KEY"
)

type CredentialType string

const (
	SpotifyCredential CredentialType = "spotify"
	TMDBCredential    CredentialType = "tmdb"
	OpenAICredential  CredentialType = "openai"
	GeminiCredential  CredentialType = "gemini"
	RAWGCredential    CredentialType = "rawg"
)

type CredentialChangeListener func(credType CredentialType, action string)

var (
	listeners []CredentialChangeListener
	mu        sync.RWMutex
)

func RegisterChangeListener(listener CredentialChangeListener) {
	mu.Lock()
	defer mu.Unlock()
	listeners = append(listeners, listener)
}

func notifyListeners(credType CredentialType, action string) {
	mu.RLock()
	defer mu.RUnlock()
	for _, listener := range listeners {
		listener(credType, action)
	}
}

func SaveSpotifyToken(token string) error {
	if err := keyring.Set(ServiceName, SpotifyRefreshTokenKey, token); err != nil {
		return fmt.Errorf("failed to set Spotify refresh token: %w", err)
	}
	notifyListeners(SpotifyCredential, "save")
	return nil
}

func GetSpotifyToken() (string, error) {
	token, err := keyring.Get(ServiceName, SpotifyRefreshTokenKey)
	if err != nil {
		return "", fmt.Errorf("failed to get Spotify refresh token: %w", err)
	}
	return token, nil
}

func ClearSpotifyToken() error {
	err := keyring.Delete(ServiceName, SpotifyRefreshTokenKey)
	if err != nil && !errors.Is(err, keyring.ErrNotFound) {
		return fmt.Errorf("failed to delete Spotify refresh token: %w", err)
	}
	notifyListeners(SpotifyCredential, "clear")
	return nil
}

func SaveOpenAIKey(apiKey string) error {
	if err := keyring.Set(ServiceName, OpenAIKey, apiKey); err != nil {
		return fmt.Errorf("failed to set OpenAI API key: %w", err)
	}
	notifyListeners(OpenAICredential, "save")
	return nil
}

func GetOpenAIKey() (string, error) {
	apiKey, err := keyring.Get(ServiceName, OpenAIKey)
	if err != nil {
		return "", fmt.Errorf("failed to get OpenAI API key: %w", err)
	}
	return apiKey, nil
}

func ClearOpenAIKey() error {
	err := keyring.Delete(ServiceName, OpenAIKey)
	if err != nil && !errors.Is(err, keyring.ErrNotFound) {
		return fmt.Errorf("failed to delete OpenAI API key: %w", err)
	}
	notifyListeners(OpenAICredential, "clear")
	return nil
}

func SaveGeminiKey(apiKey string) error {
	if err := keyring.Set(ServiceName, GeminiKey, apiKey); err != nil {
		return fmt.Errorf("failed to set Gemini API key: %w", err)
	}
	notifyListeners(GeminiCredential, "save")
	return nil
}

func GetGeminiKey() (string, error) {
	apiKey, err := keyring.Get(ServiceName, GeminiKey)
	if err != nil {
		return "", fmt.Errorf("failed to get Gemini API key: %w", err)
	}
	return apiKey, nil
}

func ClearGeminiKey() error {
	err := keyring.Delete(ServiceName, GeminiKey)
	if err != nil && !errors.Is(err, keyring.ErrNotFound) {
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
		return fmt.Errorf("failed to delete TMDB access token: %w", err)
	}
	notifyListeners(TMDBCredential, "clear")
	return nil
}

func SaveRAWGAPIKey(apiKey string) error {
	if err := keyring.Set(ServiceName, RAWGApiKey, apiKey); err != nil {
		return fmt.Errorf("failed to set RAWG API key: %w", err)
	}
	notifyListeners(RAWGCredential, "save")
	return nil
}

func GetRAWGAPIKey() (string, error) {
	apiKey, err := keyring.Get(ServiceName, RAWGApiKey)
	if err != nil {
		return "", fmt.Errorf("failed to get RAWG API key: %w", err)
	}
	return apiKey, nil
}

func ClearRAWGAPIKey() error {
	err := keyring.Delete(ServiceName, RAWGApiKey)
	if err != nil && !errors.Is(err, keyring.ErrNotFound) {
		return fmt.Errorf("failed to delete RAWG API key: %w", err)
	}
	notifyListeners(RAWGCredential, "clear")
	return nil
}
