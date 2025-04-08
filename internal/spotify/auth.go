package spotify

import (
	"context"
	"fmt"
	"interestnaut/internal/creds"
	"interestnaut/internal/server"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"runtime"
	"sync"
	"time"

	request "github.com/catlee993/go-request"
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
		currentToken = authResp.AccessToken
		currentTokenExp = time.Now().Add(time.Duration(authResp.ExpiresIn) * time.Second)
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

// GetValidToken returns a valid access token, getting a new one if necessary
func GetValidToken(ctx context.Context) (string, error) {
	tokenMutex.RLock()
	token := currentToken
	expiry := currentTokenExp
	tokenMutex.RUnlock()

	// If we have a valid token in memory, return it
	if token != "" && time.Now().Before(expiry) {
		return token, nil
	}

	// Get the saved refresh token from keychain
	refreshToken, err := creds.GetSpotifyCreds()
	if err != nil {
		return "", ErrNotAuthenticated
	}

	// Get client credentials from environment
	clientID := os.Getenv("SPOTIFY_CLIENT_ID")
	clientSecret := os.Getenv("SPOTIFY_CLIENT_SECRET")
	if clientID == "" || clientSecret == "" {
		return "", fmt.Errorf("SPOTIFY_CLIENT_ID or SPOTIFY_CLIENT_SECRET not set in environment")
	}

	// Use the refresh token to get a new access token
	authResp, err := refreshAccessToken(ctx, clientID, clientSecret, refreshToken)
	if err != nil {
		// If the refresh token is invalid, we need to re-authenticate
		if err.Error() == "request failed: request failed: response not OK, status: 400, body: {\"error\":\"invalid_grant\",\"error_description\":\"Invalid refresh token\"}" {
			// Clear the invalid refresh token from keychain
			_ = creds.SaveSpotifyCreds("")
			return "", ErrNotAuthenticated
		}
		return "", fmt.Errorf("failed to refresh token: %w", err)
	}

	// Store the new access token and its expiry in memory
	tokenMutex.Lock()
	currentToken = authResp.AccessToken
	currentTokenExp = time.Now().Add(time.Duration(authResp.ExpiresIn) * time.Second)
	tokenMutex.Unlock()

	return currentToken, nil
}

// refreshAccessToken uses a refresh token to get a new access token
func refreshAccessToken(ctx context.Context, clientID, clientSecret, refreshToken string) (*AuthResponse, error) {
	values := url.Values{}
	values.Set("grant_type", "refresh_token")
	values.Set("refresh_token", refreshToken)

	return makeTokenRequest(ctx, clientID, clientSecret, values)
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
