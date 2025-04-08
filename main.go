package main

import (
	"context"
	"embed"
	"fmt"
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
	// Load environment variables from .env file
	if err := godotenv.Load(); err != nil {
		log.Printf("Warning: Error loading .env file: %v", err)
	}

	wailsClient := spotify.NewWailsClient()

	// Create application with options
	err := wails.Run(&options.App{
		Title:  "Interestnaut",
		Width:  1024,
		Height: 768,
		AssetServer: &assetserver.Options{
			Assets: assets,
		},
		BackgroundColour: &options.RGBA{R: 27, G: 38, B: 54, A: 1},
		OnStartup: func(ctx context.Context) {
			onStartup(ctx, wailsClient)
		},
		Bind: []interface{}{
			wailsClient,
		},
	})

	if err != nil {
		fmt.Println("Error:", err.Error())
	}
}

func onStartup(ctx context.Context, wailsClient *spotify.WailsClient) {
	log.Println("Starting application...")

	// Check if we have a valid authorization code
	_, err := creds.GetSpotifyCreds()
	if err != nil {
		log.Println("No valid authorization code found, starting authentication flow...")
		if iErr := spotify.RunInitialAuthFlow(ctx); iErr != nil {
			log.Printf("Authentication failed: %v", iErr)
		} else {
			log.Println("Authentication successful")
			wailsClient.SetSpotifyClient(spotify.NewClient())
		}
	} else {
		log.Println("Using existing authorization code")
		wailsClient.SetSpotifyClient(spotify.NewClient())
	}
}
