package spotify

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"interestnaut/internal/creds"
	"interestnaut/internal/server"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"sync"
	"time"

	request "github.com/catlee993/go-request"
	"github.com/zalando/go-keyring"
)

// const variables remain unchanged
const (
	authURL     = "https://accounts.spotify.com/authorize"
	redirectURI = "http://localhost:8080/callback"
	scope       = "user-read-private user-read-email user-library-read user-read-playback-state user-modify-playback-state"
	tokenURL    = "https://accounts.spotify.com/api/token"
)

var (
	// In-memory storage for the current access token and its expiry
	currentToken    string
	currentTokenExp time.Time
	tokenMutex      sync.RWMutex
	accessToken     string
	tokenExpiry     time.Time
)

// RunInitialAuthFlow starts a local server, opens the browser to start OAuth, and waits for callback to save credentials.
func RunInitialAuthFlow(ctx context.Context) error {
	stop := make(chan struct{})

	clientID := os.Getenv("SPOTIFY_CLIENT_ID")
	clientSecret := os.Getenv("SPOTIFY_CLIENT_SECRET")
	if clientID == "" || clientSecret == "" {
		return fmt.Errorf("SPOTIFY_CLIENT_ID or SPOTIFY_CLIENT_SECRET not set in environment")
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/callback", func(w http.ResponseWriter, r *http.Request) {
		code := r.URL.Query().Get("code")
		if code == "" {
			http.Error(w, "Missing 'code' parameter in callback", http.StatusBadRequest)
			return
		}

		// Exchange the authorization code for tokens
		authResp, err := exchangeCodeForToken(ctx, clientID, clientSecret, code)
		if err != nil {
			http.Error(w, fmt.Sprintf("Failed to exchange code for token: %v", err), http.StatusInternalServerError)
			return
		}

		// Save the refresh token in the keychain
		if err := creds.SaveSpotifyCreds(authResp.RefreshToken); err != nil {
			http.Error(w, "Failed to save refresh token", http.StatusInternalServerError)
			return
		}

		// Store the access token and its expiry in memory only
		tokenMutex.Lock()
		accessToken = authResp.AccessToken
		tokenExpiry = time.Now().Add(time.Duration(authResp.ExpiresIn) * time.Second)
		currentToken = authResp.AccessToken
		currentTokenExp = tokenExpiry
		log.Printf("DEBUG (Callback): Stored initial token expiring at %s", tokenExpiry.Format(time.RFC3339))
		tokenMutex.Unlock()

		_, _ = fmt.Fprintln(w, "Authentication successful. You can close this window.")
		close(stop)
	})

	go server.Start(ctx, stop, mux)

	if err := startAuth(clientID); err != nil {
		return fmt.Errorf("failed to start auth flow: %w", err)
	}

	<-stop
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

	refreshToken, err := creds.GetSpotifyCreds()
	if err != nil {
		log.Printf("ERROR: Failed to get refresh token from storage: %v", err)
		return "", ErrNotAuthenticated
	}
	if refreshToken == "" {
		log.Println("ERROR: Retrieved empty refresh token from storage.")
		return "", ErrNotAuthenticated
	}

	// Perform the refresh using the refresh token
	clientID := os.Getenv("SPOTIFY_CLIENT_ID")
	clientSecret := os.Getenv("SPOTIFY_CLIENT_SECRET")
	if clientID == "" || clientSecret == "" {
		log.Println("ERROR: Spotify client ID or secret not found in env for token refresh.")
		return "", ErrNotAuthenticated
	}

	form := url.Values{}
	form.Set("grant_type", "refresh_token")
	form.Set("refresh_token", refreshToken)

	req, err := http.NewRequestWithContext(ctx, "POST", "https://accounts.spotify.com/api/token", strings.NewReader(form.Encode()))
	if err != nil {
		log.Printf("ERROR: Failed to create token refresh request: %v", err)
		return "", fmt.Errorf("failed to create token refresh request: %w", err)
	}

	authHeader := base64.StdEncoding.EncodeToString([]byte(clientID + ":" + clientSecret))
	req.Header.Set("Authorization", "Basic "+authHeader)
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

	// If the response included a *new* refresh token, update storage
	if authResp.RefreshToken != "" && authResp.RefreshToken != refreshToken {
		if err := creds.SaveSpotifyCreds(authResp.RefreshToken); err != nil {
			log.Printf("ERROR: Failed to store new refresh token: %v", err)
		}
	}

	return accessToken, nil
}

// exchangeCodeForToken exchanges an authorization code for access and refresh tokens
func exchangeCodeForToken(ctx context.Context, clientID, clientSecret, code string) (*AuthResponse, error) {
	values := url.Values{}
	values.Set("grant_type", "authorization_code")
	values.Set("code", code)
	values.Set("redirect_uri", redirectURI)

	return makeTokenRequest(ctx, clientID, clientSecret, values)
}

// makeTokenRequest makes a request to the Spotify token endpoint
func makeTokenRequest(ctx context.Context, clientID, clientSecret string, values url.Values) (*AuthResponse, error) {
	body := values.Encode()

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Post),
		request.WithHost("accounts.spotify.com"),
		request.WithPath("api", "token"),
		request.WithBody([]byte(body)),
		request.WithHeaders(map[string][]string{
			"Content-Type":  {"application/x-www-form-urlencoded"},
			"Authorization": {"Basic " + creds.BasicAuth(clientID, clientSecret)},
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

// startAuth initiates the OAuth flow by constructing the authorization URL and opening it in the default browser.
func startAuth(clientID string) error {
	signinUrl := fmt.Sprintf("%s?client_id=%s&response_type=code&redirect_uri=%s&scope=%s",
		authURL, clientID, url.QueryEscape(redirectURI), url.QueryEscape(scope))

	return openBrowser(signinUrl)
}

// openBrowser opens the default browser with the given URL
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
