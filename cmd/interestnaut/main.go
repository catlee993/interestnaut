package main

import (
	"context"
	"interestnaut/internal/app/bindings"
	"interestnaut/internal/app/creds"
	"interestnaut/internal/app/ffi"
	"interestnaut/internal/app/session"
	"interestnaut/internal/app/spotify"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"sync"
	"syscall"
)

//export InitializeApp
func InitializeApp() {
	// This function can be called from FFI to initialize the app
	log.Println("Initializing app from FFI...")
	// The init logic will be called automatically when this happens
}

//export SignalGoAppShutdown
func SignalGoAppShutdown() {
	log.Println("Go app shutdown signaled from FFI")
	// This will exit the process from the FFI layer
}

var wg sync.WaitGroup

func main() {
	// Set up signal handling for graceful shutdown
	signalChan := make(chan os.Signal, 1)
	signal.Notify(signalChan, os.Interrupt, syscall.SIGTERM)

	// Create an instance of the app structure
	ctx := context.Background()
	cm, err := session.NewCentralManager(ctx, session.DefaultUserID)
	if err != nil {
		log.Fatalf("Failed to create central manager: %v", err)
	}

	// Initialize FFI bindings with the central manager
	ffi.Initialize(cm)
	log.Println("FFI bindings initialized")

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

	// Launch Flutter app in a separate goroutine
	wg.Add(1)
	go func() {
		defer wg.Done()
		launchFlutterApp()
		// When Flutter app exits, the goroutine will complete
		log.Println("Flutter app has exited")
	}()

	// Wait for either a signal or for all tasks to complete
	go func() {
		sig := <-signalChan
		log.Printf("Received signal: %v, initiating shutdown", sig)
		// Let the WaitGroup complete naturally when processes exit
	}()

	// Wait for all processes to exit
	wg.Wait()
	log.Println("All processes completed, exiting main")
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
	// Get the Flutter app path
	flutterAppPath := "internal/ui/flutter"
	absFlutterPath, err := filepath.Abs(flutterAppPath)
	if err != nil {
		log.Printf("Error getting absolute path: %v", err)
		return
	}

	log.Printf("Launching Flutter app from: %s", absFlutterPath)

	// Set up and build the shared library
	libName := "libinterestnaut.dylib"
	if runtime.GOOS == "windows" {
		libName = "interestnaut.dll"
	} else if runtime.GOOS == "linux" {
		libName = "libinterestnaut.so"
	}

	// Build the shared library
	absLibPath, err := filepath.Abs(libName)
	if err != nil {
		log.Printf("Error getting absolute path for library: %v", err)
		return
	}

	if _, err := os.Stat(absLibPath); os.IsNotExist(err) {
		log.Println("Building FFI library...")
		buildCmd := exec.Command("go", "build", "-buildmode=c-shared", "-o", absLibPath, "./cmd/interestnaut/")
		buildCmd.Stdout = os.Stdout
		buildCmd.Stderr = os.Stderr
		if err := buildCmd.Run(); err != nil {
			log.Printf("Error building library: %v", err)
			return
		}
	}

	// Copy the library to the Flutter app's Frameworks directory inside macOS app bundle
	// This allows the library to be accessible inside the app sandbox
	var targetLibPath string
	if runtime.GOOS == "darwin" {
		// On macOS, we need to put the library in the app bundle's Frameworks directory
		macOSBundlePath := filepath.Join(absFlutterPath, "build", "macos", "Build", "Products", "Debug", "interestnaut.app")
		frameworksPath := filepath.Join(macOSBundlePath, "Contents", "Frameworks")

		// Create Frameworks directory if it doesn't exist
		if err := os.MkdirAll(frameworksPath, 0755); err != nil {
			log.Printf("Error creating Frameworks directory: %v", err)
		}

		targetLibPath = filepath.Join(frameworksPath, libName)
		log.Printf("Copying library to macOS app bundle: %s", targetLibPath)
	} else {
		// For other platforms, just copy to the Flutter directory
		targetLibPath = filepath.Join(absFlutterPath, libName)
	}

	// Copy the library to the target path
	if err := copyFile(absLibPath, targetLibPath); err != nil {
		log.Printf("Error copying library: %v", err)
	} else {
		log.Printf("Copied library to: %s", targetLibPath)
	}

	// Run Flutter with the appropriate platform target and set the environment variable
	// to point to the library location
	var cmd *exec.Cmd
	if runtime.GOOS == "darwin" {
		cmd = exec.Command("flutter", "run", "-d", "macos")
	} else if runtime.GOOS == "windows" {
		cmd = exec.Command("flutter", "run", "-d", "windows")
	} else if runtime.GOOS == "linux" {
		cmd = exec.Command("flutter", "run", "-d", "linux")
	} else {
		log.Printf("Unsupported OS: %s", runtime.GOOS)
		return
	}

	// Set up the command environment
	cmd.Dir = flutterAppPath
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Env = append(os.Environ(), "FLUTTER_DYLIB_PATH="+targetLibPath)

	// Launch the Flutter app
	log.Println("Starting Flutter app...")
	if err := cmd.Run(); err != nil {
		log.Printf("Error running Flutter: %v", err)
	}
}

// Helper function to copy a file
func copyFile(src, dst string) error {
	input, err := os.ReadFile(src)
	if err != nil {
		return err
	}

	err = os.MkdirAll(filepath.Dir(dst), 0755)
	if err != nil {
		return err
	}

	return os.WriteFile(dst, input, 0644)
}
