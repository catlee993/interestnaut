package spotify

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"interestnaut/internal/app/creds"
	"interestnaut/internal/app/eventbus"
	"io"
	"log"
	"net/http"
	"net/url"
	"os/exec"
	"runtime"
	"strings"
	"sync"
	"syscall"
	"time"
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

// RunInitialAuthFlow runs the Spotify authentication flow synchronously, blocking until
// the auth process completes. This is safe to call from FFI because it doesn't
// spawn any background goroutines that outlive the function call.
func RunInitialAuthFlow(ctx context.Context) error {
	log.Println("Starting blocking Spotify authentication...")
	
	// Set up signal handling for this process
	// This helps prevent signal-related crashes when called through FFI
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	
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
	
	// Build auth URL with PKCE
	signinURL := fmt.Sprintf("%s?client_id=%s&response_type=code&redirect_uri=%s&scope=%s&code_challenge=%s&code_challenge_method=S256",
		authURL,
		url.QueryEscape(ClientID),
		url.QueryEscape(redirectURI),
		url.QueryEscape(scope),
		url.QueryEscape(codeChallenge),
	)
	
	// Channel for receiving the authorization code
	codeChan := make(chan string, 1)
	errChan := make(chan error, 1)
	
	// Create a server mux for the callback
	mux := http.NewServeMux()
	mux.HandleFunc("/callback", func(w http.ResponseWriter, r *http.Request) {
		code := r.URL.Query().Get("code")
		if code == "" {
			errChan <- fmt.Errorf("missing code parameter")
			http.Error(w, "Missing code parameter", http.StatusBadRequest)
			return
		}
		
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
		w.Write([]byte(successHTML))
		
		// Send the code to the channel
		codeChan <- code
	})
	
	// Create the server with a timeout handler to prevent hanging connections
	server := &http.Server{
		Addr:    ":8080",
		Handler: mux,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  30 * time.Second,
	}
	
	// Create a single channel to signal when we're done with the server
	serverDone := make(chan struct{})
	
	// Run server in a single goroutine that also handles cleanup
	go func() {
		defer close(serverDone)
		
		// Lock OS thread to isolate signal handling within this goroutine
		runtime.LockOSThread()
		defer runtime.UnlockOSThread()
		
		log.Println("Starting auth server on port 8080...")
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			// Only report errors other than expected server closure
			errChan <- err
		}
	}()
	
	// Open the browser first to get the auth flow started
	log.Println("Opening browser for authentication...")
	if err := openBrowser(signinURL); err != nil {
		return fmt.Errorf("failed to open browser: %w", err)
	}
	
	// Wait for an auth code, server error, or timeout
	var code string
	select {
	case code = <-codeChan:
		log.Println("Got authorization code")
	case err := <-errChan:
		return fmt.Errorf("authorization error: %w", err)
	case <-ctx.Done():
		return fmt.Errorf("context canceled: %w", ctx.Err())
	case <-time.After(5 * time.Minute):
		return fmt.Errorf("authentication timed out after 5 minutes")
	}
	
	// Exchange the code for a token
	authResp, err := exchangeCodeForToken(ctx, ClientID, code)
	if err != nil {
		return fmt.Errorf("failed to exchange code for token: %w", err)
	}
	
	// Save the refresh token
	if err := creds.SaveSpotifyToken(authResp.RefreshToken); err != nil {
		return fmt.Errorf("failed to save refresh token: %w", err)
	}
	
	// Store the access token in memory
	tokenMutex.Lock()
	accessToken = authResp.AccessToken
	tokenExpiry = time.Now().Add(time.Duration(authResp.ExpiresIn) * time.Second)
	tokenMutex.Unlock()
	
	// Shut down the server in a background goroutine
	// Don't wait for it to complete, as it can sometimes hang
	shutdownDone := make(chan struct{})
	go func() {
		defer close(shutdownDone)
		
		// Lock the OS thread for signal handling isolation
		runtime.LockOSThread()
		defer runtime.UnlockOSThread()
		
		log.Println("Shutting down auth server...")
		
		// Disable keep-alives to prevent new connections
		server.SetKeepAlivesEnabled(false)
		
		// Create context with a reasonable timeout
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		
		// Attempt graceful shutdown
		if err := server.Shutdown(shutdownCtx); err != nil {
			log.Printf("Graceful shutdown failed: %v - forcing close", err)
			// Force close if graceful shutdown fails
			server.Close()
		} else {
			log.Println("Server gracefully shut down")
		}
	}()
	
	// Wait a short time for server shutdown to complete
	select {
	case <-shutdownDone:
		log.Println("Server shutdown completed")
	case <-time.After(500 * time.Millisecond):
		log.Println("Continuing without waiting for full server shutdown")
	}
	
	// Get user profile for the event if possible
	profile, err := fetchCurrentUser()
	payload := map[string]interface{}{
		"isAuthenticated": true,
	}
	
	if err == nil && profile != nil {
		payload["userProfile"] = profile
	}
	
	// Emit authentication status event using EmitSafe for FFI boundary safety
	bus := eventbus.GetGlobalBus()
	bus.EmitSafe(eventbus.Event{
		Type:    "spotify_auth_status_changed",
		Payload: payload,
	})
	log.Println("Emitted auth success event safely with EmitSafe")
	
	log.Println("Authentication completed successfully")
	return nil
}

// ClearSpotifyCredentials clears stored Spotify tokens and resets in-memory state.
func ClearSpotifyCredentials(ctx context.Context) error {
	// Since this function is called directly through FFI, we need to be
	// especially careful about signal handling
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	
	log.Println("Attempting to clear Spotify credentials...")
	err := creds.ClearSpotifyToken()
	if err != nil {
		log.Printf("ERROR: Failed to clear credentials from storage: %v", err)
		return fmt.Errorf("failed to clear stored credentials %v", err)
	}
	
	// Clear in-memory tokens
	tokenMutex.Lock()
	accessToken = ""
	tokenExpiry = time.Time{}
	tokenMutex.Unlock()
	
	// Emit authentication status event using EmitSafe
	bus := eventbus.GetGlobalBus()
	bus.EmitSafe(eventbus.Event{
		Type: "spotify_auth_status_changed",
		Payload: map[string]interface{}{
			"isAuthenticated": false,
			"userProfile":     nil,
		},
	})
	log.Println("Emitted auth status change: logged out safely with EmitSafe")
	
	log.Println("Cleared Spotify credentials from storage and memory.")
	return nil
}

// GetValidToken retrieves a valid Spotify access token, refreshing if necessary.
func GetValidToken(ctx context.Context) (string, error) {
	// Since this function is called through FFI, use thread locking for signal safety
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	
	tokenMutex.RLock()
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

	// Attempt to refresh using stored refresh token
	refreshToken, err := creds.GetSpotifyToken()
	if err != nil || refreshToken == "" {
		log.Printf("ERROR: No refresh token found: %v", err)
		return "", fmt.Errorf("no refresh token available")
	}

	// Use refresh token to get a new access token
	log.Println("Refreshing access token...")
	values := url.Values{}
	values.Set("grant_type", "refresh_token")
	values.Set("refresh_token", refreshToken)
	values.Set("client_id", ClientID)

	authResp, err := makeTokenRequest(ctx, values)
	if err != nil {
		log.Printf("ERROR: Failed to refresh token: %v", err)
		return "", fmt.Errorf("failed to refresh token: %w", err)
	}

	// Update access token in memory
	accessToken = authResp.AccessToken
	tokenExpiry = time.Now().Add(time.Duration(authResp.ExpiresIn) * time.Second)
	log.Printf("Refreshed token, expires at %s", tokenExpiry.Format(time.RFC3339))

	// If a new refresh token was provided, update it in storage
	if authResp.RefreshToken != "" {
		if err := creds.SaveSpotifyToken(authResp.RefreshToken); err != nil {
			log.Printf("WARNING: Failed to save new refresh token: %v", err)
			// This is not a fatal error, we can continue with the access token
		}
	}

	// Emit authentication status event using EmitSafe for FFI boundary safety
	bus := eventbus.GetGlobalBus()
	bus.EmitSafe(eventbus.Event{
		Type: "spotify_auth_status_changed",
		Payload: map[string]interface{}{
			"isAuthenticated": true,
		},
	})
	log.Println("Emitted auth status change: refreshed token with EmitSafe")
	
	return accessToken, nil
}

// exchangeCodeForToken exchanges an authorization code for access and refresh tokens using PKCE.
func exchangeCodeForToken(ctx context.Context, clientID, code string) (*AuthResponse, error) {
	values := url.Values{}
	values.Set("grant_type", "authorization_code")
	values.Set("code", code)
	values.Set("redirect_uri", redirectURI)
	values.Set("client_id", clientID)
	values.Set("code_verifier", codeVerifier) // Send the original code verifier

	return makeTokenRequest(ctx, values)
}

// makeTokenRequest makes a request to Spotify's token endpoint.
func makeTokenRequest(ctx context.Context, values url.Values) (*AuthResponse, error) {
	// Lock the thread for the duration of this network operation
	// This prevents signal handling issues when called through FFI
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	
	client := &http.Client{Timeout: 10 * time.Second}
	req, err := http.NewRequestWithContext(ctx, "POST", tokenURL, strings.NewReader(values.Encode()))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("token request failed with status %d: %s", resp.StatusCode, string(body))
	}

	var authResp AuthResponse
	if err := json.Unmarshal(body, &authResp); err != nil {
		return nil, err
	}

	return &authResp, nil
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
		Setpgid: true,  // Use a new process group
	}
	// Start the command detached from our process
	return command.Start()
}

// fetchCurrentUser gets the current user's profile
func fetchCurrentUser() (map[string]interface{}, error) {
	// Create a client to fetch the user profile
	c := NewClient()
	
	// Get the user profile
	profile, err := c.GetCurrentUser(context.Background())
	if err != nil {
		return nil, fmt.Errorf("failed to get current user: %w", err)
	}
	
	// Convert to map[string]interface{} for the event payload
	profileJSON, err := json.Marshal(profile)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal profile: %w", err)
	}
	
	var profileMap map[string]interface{}
	if err := json.Unmarshal(profileJSON, &profileMap); err != nil {
		return nil, fmt.Errorf("failed to unmarshal profile: %w", err)
	}
	
	return profileMap, nil
}
