package main

import (
	"context"
	"embed"
	"fmt"
	"interestnaut/internal/bindings"
	"interestnaut/internal/db"
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
	music := bindings.NewMusicBinder(ctx, cm, spotify.ClientID)
	movies, mErr := bindings.NewMovieBinder(ctx, cm)
	if mErr != nil {
		log.Fatalf("Failed to create movies binder: %v", mErr)
	}

	// Create the TV Shows binder
	tvShows, tErr := bindings.NewTVShowBinder(ctx, cm)
	if tErr != nil {
		log.Fatalf("Failed to create TV shows binder: %v", tErr)
	}

	// Create games binder
	games, gErr := bindings.NewGames(ctx, cm)
	if gErr != nil {
		log.Fatalf("Failed to create games binder: %v", gErr)
	}

	// Create settings binder
	settings := &bindings.Settings{ContentManager: cm}

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
			settings,
			music,
			movies,
			tvShows,
			games,
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

	// Initialize the local database
	if err := db.Initialize(); err != nil {
		log.Printf("Failed to initialize database: %v", err)
	} else {
		log.Println("Database initialized successfully")
	}

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
