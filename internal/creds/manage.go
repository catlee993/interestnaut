package creds

import (
	"encoding/base64"
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

// SaveSpotifyCreds saves Spotify refresh token to the OS keychain.
func SaveSpotifyCreds(token string) error {
	if err := keyring.Set(ServiceName, SpotifyRefreshTokenKey, token); err != nil {
		return fmt.Errorf("failed to set Spotify refresh token: %w", err)
	}
	return nil
}

// GetSpotifyCreds retrieves Spotify refresh token from the OS keychain.
func GetSpotifyCreds() (string, error) {
	token, err := keyring.Get(ServiceName, SpotifyRefreshTokenKey)
	if err != nil {
		return "", fmt.Errorf("failed to get Spotify refresh token: %w", err)
	}
	return token, nil
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

// BasicAuth returns a base64 encoded string of "id:secret"
func BasicAuth(id string, secret string) string {
	return base64.StdEncoding.EncodeToString([]byte(id + ":" + secret))
}
