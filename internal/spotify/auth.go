package spotify

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"interestnaut/internal/creds"
	"interestnaut/internal/server"
	"io"
	"log"
	"net/http"
	"net/url"
	"os/exec"
	"runtime"
	"strings"
	"sync"
	"time"

	request "github.com/catlee993/go-request"
	"github.com/zalando/go-keyring"
)

// Constants remain mostly unchanged
const (
	ClientID    = "3bb48a30577342869a9ffcb176dee7d2"
	authURL     = "https://accounts.spotify.com/authorize"
	redirectURI = "http://localhost:8080/callback"
	scope       = "user-read-private user-read-email user-library-read user-library-modify user-read-playback-state user-modify-playback-state streaming"
	tokenURL    = "https://accounts.spotify.com/api/token"
)

var (
	tokenMutex  sync.RWMutex
	accessToken string
	tokenExpiry time.Time

	// codeVerifier for PKCE (global so it can be referenced during token exchange)
	codeVerifier string
)

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

// RunInitialAuthFlow starts a local server, opens the browser to start OAuth with PKCE, and waits
// for callback to save credentials.
func RunInitialAuthFlow(ctx context.Context) error {
	stop := make(chan struct{})
	errChan := make(chan error, 1)

	mux := http.NewServeMux()
	mux.HandleFunc("/callback", func(w http.ResponseWriter, r *http.Request) {
		code := r.URL.Query().Get("code")
		if code == "" {
			errChan <- fmt.Errorf("missing 'code' parameter in callback")
			http.Error(w, "Missing 'code' parameter in callback", http.StatusBadRequest)
			return
		}

		// Exchange the authorization code for tokens using PKCE
		authResp, err := exchangeCodeForToken(ctx, ClientID, code)
		if err != nil {
			errChan <- fmt.Errorf("failed to exchange code for token: %w", err)
			http.Error(w, fmt.Sprintf("Failed to exchange code for token: %v", err), http.StatusInternalServerError)
			return
		}

		// Save the refresh token in the keychain
		if err := creds.SaveSpotifyToken(authResp.RefreshToken); err != nil {
			errChan <- fmt.Errorf("failed to save refresh token: %w", err)
			http.Error(w, "Failed to save refresh token", http.StatusInternalServerError)
			return
		}

		// Store the access token and its expiry in memory only
		tokenMutex.Lock()
		accessToken = authResp.AccessToken
		tokenExpiry = time.Now().Add(time.Duration(authResp.ExpiresIn) * time.Second)
		log.Printf("DEBUG (Callback): Stored initial token expiring at %s", tokenExpiry.Format(time.RFC3339))
		tokenMutex.Unlock()

		// Send success response to browser
		w.Header().Set("Content-Type", "text/html")
		successHTML := `
		<html>
			<body style="background: #1a1a1a; color: #ffffff; font-family: Arial, sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0;">
				<div style="text-align: center; padding: 20px; background: #282828; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
					<h2 style="margin-bottom: 20px;">Authentication Successful!</h2>
					<p>You can close this window and return to the application.</p>
					<script>
						setTimeout(function() {
							window.close();
						}, 2000);
					</script>
				</div>
			</body>
		</html>`
		_, _ = fmt.Fprint(w, successHTML)

		// Signal successful completion
		close(stop)
	})

	serverCtx, serverCancel := context.WithCancel(ctx)
	defer serverCancel()

	// Start server and handle errors
	serverErrChan := make(chan error, 1)
	go func() {
		if err := server.Start(serverCtx, stop, mux); err != nil {
			serverErrChan <- err
		}
	}()

	// Start auth flow in browser
	if err := startAuth(ClientID); err != nil {
		serverCancel() // Cancel server context if browser launch fails
		return fmt.Errorf("failed to start auth flow: %w", err)
	}

	// Wait for either success, error, or context cancellation
	select {
	case <-stop:
		log.Println("Authentication successful")
		serverCancel() // Ensure server is stopped
		// Wait for server to stop
		select {
		case err := <-serverErrChan:
			if err != nil && !errors.Is(err, http.ErrServerClosed) {
				return fmt.Errorf("server error during shutdown: %w", err)
			}
		case <-time.After(5 * time.Second):
			// Timeout waiting for server shutdown
		}
		return nil
	case err := <-errChan:
		serverCancel() // Ensure server is stopped
		return err
	case err := <-serverErrChan:
		return fmt.Errorf("server error: %w", err)
	case <-ctx.Done():
		serverCancel() // Ensure server is stopped
		return ctx.Err()
	}
}

// ClearSpotifyCredentials clears stored Spotify tokens and resets in-memory state.
func ClearSpotifyCredentials(ctx context.Context) error {
	log.Println("Attempting to clear Spotify credentials...")
	err := creds.ClearSpotifyToken()
	if err != nil {
		log.Printf("ERROR: Failed to clear credentials from storage: %v", err)
		return fmt.Errorf("failed to clear stored credentials %v", err)
	}
	// Also clear in-memory tokens
	tokenMutex.Lock()
	accessToken = ""
	tokenExpiry = time.Time{}
	tokenMutex.Unlock()
	log.Println("Cleared Spotify credentials from storage and memory.")

	// Start a new authentication flow
	if err := RunInitialAuthFlow(ctx); err != nil {
		log.Printf("ERROR: Failed to start new auth flow after clearing credentials: %v", err)
		return fmt.Errorf("failed to start new auth flow after clearing credentials: %w", err)
	}

	return nil
}

// GetValidToken retrieves a valid Spotify access token, refreshing if necessary.
func GetValidToken(ctx context.Context) (string, error) {
	tokenMutex.RLock() // Start with read lock
	if accessToken != "" && time.Now().Before(tokenExpiry) {
		acToken := accessToken
		tokenMutex.RUnlock()
		return acToken, nil
	}
	tokenMutex.RUnlock() // Unlock read lock before potentially taking write lock

	// If token is invalid or expired, acquire write lock to refresh
	tokenMutex.Lock()
	defer tokenMutex.Unlock()

	// Double-check expiry after acquiring write lock
	if accessToken != "" && time.Now().Before(tokenExpiry) {
		return accessToken, nil
	}

	refreshToken, err := creds.GetSpotifyToken()
	if err != nil {
		log.Printf("ERROR: Failed to get refresh token from storage: %v", err)
		return "", ErrNotAuthenticated
	}
	if refreshToken == "" {
		log.Println("ERROR: Retrieved empty refresh token from storage.")
		return "", ErrNotAuthenticated
	}

	form := url.Values{}
	form.Set("grant_type", "refresh_token")
	form.Set("refresh_token", refreshToken)
	form.Set("client_id", ClientID)

	req, err := http.NewRequestWithContext(ctx, "POST", tokenURL, strings.NewReader(form.Encode()))
	if err != nil {
		log.Printf("ERROR: Failed to create token refresh request: %v", err)
		return "", fmt.Errorf("failed to create token refresh request: %w", err)
	}

	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	httpClient := &http.Client{Timeout: 10 * time.Second}
	resp, err := httpClient.Do(req)
	if err != nil {
		log.Printf("ERROR: Token refresh request failed: %v", err)
		return "", fmt.Errorf("token refresh request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("ERROR: Failed to read token refresh response body: %v", err)
		return "", fmt.Errorf("failed to read token refresh response body: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		log.Printf("ERROR: Token refresh failed with status %d: %s", resp.StatusCode, string(body))
		if strings.Contains(string(body), "invalid_grant") {
			log.Println("ERROR: Invalid refresh token (invalid_grant). Clearing stored credentials.")
			if err := keyring.Delete(creds.ServiceName, creds.SpotifyRefreshTokenKey); err != nil {
				log.Printf("ERROR: Failed to clear invalid credentials from keyring: %v", err)
			}
			accessToken = ""
			tokenExpiry = time.Time{}
			return "", ErrNotAuthenticated
		}
		return "", fmt.Errorf("token refresh failed with status %d: %s", resp.StatusCode, string(body))
	}

	var authResp AuthResponse
	if err := json.Unmarshal(body, &authResp); err != nil {
		log.Printf("ERROR: Failed to unmarshal token refresh response: %v", err)
		return "", fmt.Errorf("failed to unmarshal token refresh response: %w", err)
	}

	if authResp.AccessToken == "" {
		log.Println("ERROR: Token refresh response did not contain an access token.")
		return "", ErrNotAuthenticated
	}

	// Update cached token and expiry
	accessToken = authResp.AccessToken
	tokenExpiry = time.Now().Add(time.Duration(authResp.ExpiresIn) * time.Second)
	log.Printf("DEBUG: Successfully refreshed token, new expiry: %s", tokenExpiry.Format(time.RFC3339))

	// If the response included a *new* refresh token, update storage
	if authResp.RefreshToken != "" && authResp.RefreshToken != refreshToken {
		if err := creds.SaveSpotifyToken(authResp.RefreshToken); err != nil {
			log.Printf("ERROR: Failed to store new refresh token: %v", err)
		}
	}

	return accessToken, nil
}

// exchangeCodeForToken exchanges an authorization code for access and refresh tokens using PKCE.
func exchangeCodeForToken(ctx context.Context, clientID, code string) (*AuthResponse, error) {
	values := url.Values{}
	values.Set("grant_type", "authorization_code")
	values.Set("code", code)
	values.Set("redirect_uri", redirectURI)
	// Add PKCE parameters
	values.Set("client_id", clientID)
	values.Set("code_verifier", codeVerifier)

	return makeTokenRequest(ctx, values)
}

// makeTokenRequest makes a request to Spotify's token endpoint.
// In this PKCE flow, we no longer send a Basic Authorization header.
func makeTokenRequest(ctx context.Context, values url.Values) (*AuthResponse, error) {
	body := values.Encode()

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Post),
		request.WithHost("accounts.spotify.com"),
		request.WithPath("api", "token"),
		request.WithBody([]byte(body)),
		request.WithHeaders(map[string][]string{
			"Content-Type": {"application/x-www-form-urlencoded"},
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create requester: %w", err)
	}

	var authResp AuthResponse
	_, rErr := req.Make(ctx, &authResp)
	if rErr != nil {
		return nil, fmt.Errorf("request failed: %w", rErr)
	}

	return &authResp, nil
}

// startAuth initiates the OAuth flow with PKCE by constructing the authorization URL (including a code challenge)
// and opening it in the default browser.
func startAuth(clientID string) error {
	var err error
	// Generate PKCE code verifier
	codeVerifier, err = generateCodeVerifier()
	if err != nil {
		return fmt.Errorf("failed to generate code verifier: %w", err)
	}

	// Compute the corresponding code challenge
	codeChallenge, err := computeCodeChallenge(codeVerifier)
	if err != nil {
		return fmt.Errorf("failed to compute code challenge: %w", err)
	}

	signinUrl := fmt.Sprintf("%s?client_id=%s&response_type=code&redirect_uri=%s&scope=%s&code_challenge=%s&code_challenge_method=S256",
		authURL,
		url.QueryEscape(clientID),
		url.QueryEscape(redirectURI),
		url.QueryEscape(scope),
		url.QueryEscape(codeChallenge),
	)
	return openBrowser(signinUrl)
}

// openBrowser opens the default browser with the given URL.
func openBrowser(url string) error {
	var cmd string
	var args []string

	switch runtime.GOOS {
	case "darwin":
		cmd = "open"
		args = []string{url}
	case "windows":
		cmd = "rundll32"
		args = []string{"url.dll,FileProtocolHandler", url}
	default: // linux, freebsd, etc.
		cmd = "xdg-open"
		args = []string{url}
	}
	return exec.Command(cmd, args...).Start()
}
