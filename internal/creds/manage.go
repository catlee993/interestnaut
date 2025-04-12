package creds

import (
	"errors"
	"fmt"

	keyring "github.com/zalando/go-keyring"
)

// ServiceName is the identifier used for the OS keyring service.
const ServiceName = "com.interestnaut.app"

var (
	// SpotifyRefreshTokenKey is the key used for storing the refresh token.
	SpotifyRefreshTokenKey = "SPOTIFY_REFRESH_TOKEN"
	openaiApiKey           string
)

// SaveSpotifyToken saves Spotify refresh token to the OS keychain.
func SaveSpotifyToken(token string) error {
	if err := keyring.Set(ServiceName, SpotifyRefreshTokenKey, token); err != nil {
		return fmt.Errorf("failed to set Spotify refresh token: %w", err)
	}
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
	return nil
}

// SaveOpenAICreds saves the OpenAI API key to the OS keychain.
func SaveOpenAICreds(apiKey string) error {
	if err := keyring.Set(ServiceName, "OPENAI_API_KEY", apiKey); err != nil {
		return fmt.Errorf("failed to set OpenAI API key: %w", err)
	}
	return nil
}

// GetOpenAICreds retrieves the OpenAI API key from the OS keychain.
func GetOpenAICreds() (string, error) {
	apiKey, err := keyring.Get(ServiceName, "OPENAI_API_KEY")
	if err != nil {
		return "", fmt.Errorf("failed to get OpenAI API key: %w", err)
	}
	return apiKey, nil
}

// ClearOpenAICreds removes the OpenAI API key from the OS keychain.
func ClearOpenAICreds() error {
	err := keyring.Delete(ServiceName, "OPENAI_API_KEY")
	if err != nil && !errors.Is(err, keyring.ErrNotFound) {
		// Ignore 'not found' errors, but return others
		return fmt.Errorf("failed to delete OpenAI API key: %w", err)
	}
	return nil
}
