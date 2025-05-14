package main

import (
	"context"
	"embed"
	"fmt"
	"interestnaut/internal/app/bindings"
	"interestnaut/internal/app/session"
	"log"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"

	"interestnaut/internal/app/creds"
	"interestnaut/internal/app/spotify"
)

//go:embed all:frontend/dist
var assets embed.FS

func main() {
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

	// binders map client to backend, see frontend/wailsjs/go/bindings
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

	settings := &bindings.Settings{ContentManager: cm}

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
			onStartup(ctx, llmHandlers, tmdbHandlers, rawgHandlers)
		},
		Bind: []interface{}{
			&bindings.Auth{},
			settings,
			music,
			movies,
			tvShows,
			games,
			books,
		},
		EnumBind: []interface{}{
			suggestionOutcome,
		},
	})

	if rErr != nil {
		fmt.Println("Error:", rErr.Error())
	}
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
}
