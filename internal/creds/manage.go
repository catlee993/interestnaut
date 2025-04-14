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
	TMDBAccessToken        = "TMDB_ACCESS_TOKEN"
	OpenAIKey              = "OPEN_API_KEY"
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

// SaveOpenAIKey saves the OpenAI API key to the OS keychain.
func SaveOpenAIKey(apiKey string) error {
	if err := keyring.Set(ServiceName, OpenAIKey, apiKey); err != nil {
		return fmt.Errorf("failed to set OpenAI API key: %w", err)
	}
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
	return nil
}

func SaveTMDBAccessToken(token string) error {
	if err := keyring.Set(ServiceName, TMDBAccessToken, token); err != nil {
		return fmt.Errorf("failed to set TMDB access token: %w", err)
	}
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
	return nil
}
