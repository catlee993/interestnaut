package main

import (
	"context"
	"embed"
	"fmt"
	"interestnaut/internal/bindings"
	"interestnaut/internal/session"
	"log"

	"github.com/joho/godotenv"
	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"

	"interestnaut/internal/creds"
	"interestnaut/internal/spotify"
)

//go:embed all:frontend/dist
var assets embed.FS

func main() {
	// Load environment variables from .env file, dev only
	if err := godotenv.Load(); err != nil {
		log.Printf("Warning: Error loading .env file: %v", err)
	}

	// Create an instance of the app structure
	ctx := context.Background()
	cm, err := session.NewCentralManager(ctx, session.DefaultUserID)
	if err != nil {
		log.Fatalf("Failed to create central manager: %v", err)
	}

	var suggestionOutcome = []struct {
		Value  session.Outcome
		TSName string
	}{
		{session.Liked, "liked"},
		{session.Disliked, "disliked"},
		{session.Skipped, "skipped"},
		{session.Added, "added"},
		{session.Pending, "pending"},
	}

	// Create new instances of your binders
	music := bindings.NewMusicBinder(ctx, cm)
	movies, err := bindings.NewMovieBinder(ctx, cm)
	if err != nil {
		log.Fatalf("Failed to create movies binder: %v", err)
	}

	// Create application with options
	rErr := wails.Run(&options.App{
		Title:  "Interestnaut",
		Width:  1024,
		Height: 768,
		AssetServer: &assetserver.Options{
			Assets: assets,
		},
		BackgroundColour: &options.RGBA{R: 27, G: 38, B: 54, A: 1},
		OnStartup: func(ctx context.Context) {
			onStartup(ctx)
		},
		Bind: []interface{}{
			&bindings.Auth{},
			&bindings.Settings{ContentManager: cm},
			music,
			movies,
		},
		EnumBind: []interface{}{
			suggestionOutcome,
		},
	})

	if rErr != nil {
		fmt.Println("Error:", rErr.Error())
	}
}

func onStartup(ctx context.Context) {
	log.Println("Starting application...")

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
