package spotify

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"log"
	"net/url"
	"os/exec"
	"runtime"
	"syscall"
)

// Constants remain mostly unchanged
const (
	ClientID     = "3bb48a30577342869a9ffcb176dee7d2"
	authURL      = "https://accounts.spotify.com/authorize"
	scope        = "user-read-private user-read-email user-library-read user-library-modify user-read-playback-state user-modify-playback-state streaming"
	authCallback = "http://localhost:%d/callback"
)

var (
	// codeVerifier for PKCE (global so it can be referenced during token exchange)
	codeVerifier string

	// dynamicPort stores the port used during OpenSpotifyAuthBrowser
	dynamicPort int

	// registeredPorts contains all the ports that have been registered in the Spotify Dashboard
	registeredPorts = []int{8080, 6789, 7575, 8821, 9432, 5723}
)

// IsRegisteredPort checks if the given port is registered in the Spotify Dashboard
func IsRegisteredPort(port int) bool {
	for _, p := range registeredPorts {
		if p == port {
			return true
		}
	}
	return false
}

// generateCodeVerifier returns a cryptographically random string for PKCE
func generateCodeVerifier() (string, error) {
	b := make([]byte, 64)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	// Base64 URL-encode without padding
	return base64.RawURLEncoding.EncodeToString(b), nil
}

// computeCodeChallenge returns the SHA256 hash of the verifier, Base64 URL-encoded (no padding)
func computeCodeChallenge(verifier string) (string, error) {
	hash := sha256.Sum256([]byte(verifier))
	return base64.RawURLEncoding.EncodeToString(hash[:]), nil
}

// openBrowser opens the default browser with the given URL.
func openBrowser(url string) error {
	var cmd string
	var args []string

	switch runtime.GOOS {
	case "darwin":
		cmd = "open"
		args = []string{url}
	case "linux":
		cmd = "xdg-open"
		args = []string{url}
	case "windows":
		cmd = "rundll32"
		args = []string{"url.dll,FileProtocolHandler", url}
	default:
		return fmt.Errorf("unsupported platform")
	}

	// Create a new process group to isolate signal handling
	command := exec.Command(cmd, args...)
	// Set the process to run in its own process group
	command.SysProcAttr = &syscall.SysProcAttr{
		Setpgid: true, // Use a new process group
	}
	// Start the command detached from our process
	return command.Start()
}

// OpenSpotifyAuthBrowser generates the auth URL with PKCE and opens the browser
// but doesn't wait for or handle the callback - that will be done by Flutter
// It now accepts a port parameter to use in the redirect URI
func OpenSpotifyAuthBrowser(ctx context.Context, port int) error {
	log.Printf("Opening browser for Spotify authentication with port %d", port)

	// Generate PKCE code verifier
	var err error
	codeVerifier, err = generateCodeVerifier()
	if err != nil {
		return fmt.Errorf("failed to generate code verifier: %w", err)
	}

	// Compute the corresponding code challenge
	codeChallenge, err := computeCodeChallenge(codeVerifier)
	if err != nil {
		return fmt.Errorf("failed to compute code challenge: %w", err)
	}

	// Build dynamic redirect URI with specified port
	dynamicRedirectURI := fmt.Sprintf(authCallback, port)

	// Build auth URL with PKCE
	signinURL := fmt.Sprintf("%s?client_id=%s&response_type=code&redirect_uri=%s&scope=%s&code_challenge=%s&code_challenge_method=S256",
		authURL,
		url.QueryEscape(ClientID),
		url.QueryEscape(dynamicRedirectURI),
		url.QueryEscape(scope),
		url.QueryEscape(codeChallenge),
	)

	// Open the browser to the auth URL
	err = openBrowser(signinURL)
	if err != nil {
		return fmt.Errorf("failed to open browser: %w", err)
	}

	log.Printf("Browser opened with Spotify auth URL, code verifier: %s...", codeVerifier[:10])
	dynamicPort = port
	return nil
}
