package main

import (
	"context"
	"interestnaut/internal/app/creds"
	"interestnaut/internal/app/ffi"
	"interestnaut/internal/app/mistral"
	"interestnaut/internal/app/session"
	"log"
	"os"
	"os/signal"
	"syscall"
	// Import "C" is required for CGO exports, but must be in its own block if it has comments above it.
	// Or, ensure no comments are directly above it in the import block.
)

/*
#include <stdlib.h>
*/
import "C" // This is the correct way to import C for CGO exports

//export InitializeApp
func InitializeApp() {
	log.Println("Go: (Legacy?) InitializeApp CALLED")
	// This function might need to be updated or removed if InitializeFFIBridge is the new primary init.
	// For now, it can coexist or call InitializeFFIBridge as well if it serves a distinct purpose.
}

//export SignalGoAppShutdown
func SignalGoAppShutdown() {
	log.Println("Go: SignalGoAppShutdown CALLED")
	ffi.SignalShutdown() // Assuming ffi package has a public SignalShutdown
}

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

	mistral.SetCentralManager(mistral.DefaultClient, cm)

	// Initialize FFI bindings with the central manager
	ffi.Initialize(cm)
	log.Println("FFI bindings initialized")

	// Wait for a signal using a synchronous approach instead of goroutine
	// This doesn't create a background goroutine that might be orphaned
	sig := <-signalChan
	log.Printf("Received signal: %v, initiating shutdown", sig)
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
	//_, err := creds.GetSpotifyToken()
	//if err != nil {
	//	log.Println("No valid authorization code found, starting authentication flow...")
	//	if iErr := spotify.RunInitialAuthFlow(ctx); iErr != nil {
	//		log.Printf("Authentication failed: %v", iErr)
	//	} else {
	//		log.Println("Authentication successful")
	//	}
	//} else {
	//	log.Println("Using existing authorization code")
	//}
}
