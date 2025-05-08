package main

import (
	"context"
	"interestnaut/internal/app/bindings"
	"interestnaut/internal/app/creds"
	"interestnaut/internal/app/session"
	"interestnaut/internal/app/spotify"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
)

// Server port for local communication
const serverPort = 50051

func main() {
	// Create an instance of the app structure
	ctx := context.Background()
	cm, err := session.NewCentralManager(ctx, session.DefaultUserID)
	if err != nil {
		log.Fatalf("Failed to create central manager: %v", err)
	}

	// binders map client to backend API
	music := bindings.NewMusicBinder(ctx, cm, spotify.ClientID)
	movies, mErr := bindings.NewMovieBinder(ctx, cm)
	if mErr != nil {
		log.Fatalf("Failed to create movies binder: %v", mErr)
	}

	tvShows, tErr := bindings.NewTVShowBinder(ctx, cm)
	if tErr != nil {
		log.Fatalf("Failed to create TV shows binder: %v", tErr)
	}

	games, gErr := bindings.NewGames(ctx, cm)
	if gErr != nil {
		log.Fatalf("Failed to create games binder: %v", gErr)
	}

	books, bErr := bindings.NewBooks(ctx, cm)
	if bErr != nil {
		log.Fatalf("Failed to create books binder: %v", bErr)
	}

	// Collect all LLM handlers for credential change registration
	llmHandlers := []creds.LLMCredentialChangeHandler{
		music,
		movies,
		tvShows,
		games,
		books,
	}

	// Collect TMDB handlers for credential change registration
	tmdbHandlers := []creds.TMDBCredentialChangeHandler{
		movies,
		tvShows,
	}

	// Collect RAWG handlers for credential change registration
	rawgHandlers := []creds.RAWGCredentialChangeHandler{
		games,
	}

	// Run startup processes
	onStartup(ctx, llmHandlers, tmdbHandlers, rawgHandlers)

	// Write service info to a file that Flutter app can read
	// This is a temporary approach until we set up proper communication
	writeServiceInfo()

	// Launch Flutter app
	launchFlutterApp()

	// Keep main thread alive
	select {}
}

// writeServiceInfo writes information about our services to a file
// This is a temporary approach until we set up proper gRPC or other communication
func writeServiceInfo() {
	// Create a directory for communication files if it doesn't exist
	commsDir := filepath.Join(os.TempDir(), "interestnaut")
	if err := os.MkdirAll(commsDir, 0755); err != nil {
		log.Printf("Failed to create communication directory: %v", err)
		return
	}

	// Write the server port to a file
	portFile := filepath.Join(commsDir, "server_port")
	if err := os.WriteFile(portFile, []byte(strconv.Itoa(serverPort)), 0644); err != nil {
		log.Printf("Failed to write server port file: %v", err)
	}

	log.Printf("Service info written to %s", commsDir)
}

func onStartup(ctx context.Context,
	llmHandlers []creds.LLMCredentialChangeHandler,
	tmdbHandlers []creds.TMDBCredentialChangeHandler,
	rawgHandlers []creds.RAWGCredentialChangeHandler) {
	log.Println("Starting application...")

	// Initialize credential events system
	creds.SetupEvents(ctx)
	log.Println("Credential events system initialized")

	// Register LLM client refresh handlers for all media bindings
	// These will automatically refresh LLM clients when OpenAI or Gemini credentials change
	for _, handler := range llmHandlers {
		creds.RegisterLLMClientRefreshHandler(handler)
	}
	log.Println("LLM credential change handlers registered")

	// Register TMDB client refresh handlers
	// These will automatically refresh TMDB clients when TMDB credentials change
	for _, handler := range tmdbHandlers {
		creds.RegisterTMDBClientRefreshHandler(handler)
	}
	log.Println("TMDB credential change handlers registered")

	// Register RAWG client refresh handlers
	// These will automatically refresh RAWG clients when RAWG credentials change
	for _, handler := range rawgHandlers {
		creds.RegisterRAWGClientRefreshHandler(handler)
	}
	log.Println("RAWG credential change handlers registered")

	// Check if we have a valid authorization code
	_, err := creds.GetSpotifyToken()
	if err != nil {
		log.Println("No valid authorization code found, starting authentication flow...")
		if iErr := spotify.RunInitialAuthFlow(ctx); iErr != nil {
			log.Printf("Authentication failed: %v", iErr)
		} else {
			log.Println("Authentication successful")
		}
	} else {
		log.Println("Using existing authorization code")
	}
}

func launchFlutterApp() {
	executableDir, err := filepath.Abs(filepath.Dir(os.Args[0]))
	if err != nil {
		log.Printf("Error getting executable directory: %v", err)
		return
	}

	// Adjust path based on development or production environment
	flutterAppPath := "internal/ui/flutter"
	if _, err := os.Stat(flutterAppPath); os.IsNotExist(err) {
		flutterAppPath = filepath.Join(executableDir, "flutter")
	}

	log.Printf("Launching Flutter app from: %s", flutterAppPath)

	// Pass service info directory to Flutter app
	commsDir := filepath.Join(os.TempDir(), "interestnaut")
	os.Setenv("INTERESTNAUT_COMMS_DIR", commsDir)

	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "darwin":
		// For macOS, we'll run the Flutter app directly during development
		// In production, we'd launch the bundled macOS app
		cmd = exec.Command("flutter", "run", "-d", "macos")
		cmd.Dir = flutterAppPath
	case "windows":
		// For Windows, similar approach
		cmd = exec.Command("flutter", "run", "-d", "windows")
		cmd.Dir = flutterAppPath
	case "linux":
		// For Linux
		cmd = exec.Command("flutter", "run", "-d", "linux")
		cmd.Dir = flutterAppPath
	default:
		log.Printf("Unsupported OS: %s", runtime.GOOS)
		return
	}

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Start(); err != nil {
		log.Printf("Error starting Flutter app: %v", err)
		return
	}

	log.Println("Flutter app launched successfully")
}
