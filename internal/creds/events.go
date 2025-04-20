package creds

import (
	"context"

	"github.com/wailsapp/wails/v2/pkg/runtime"
)

// EventsContext holds the Wails context for emitting events
var EventsContext context.Context

// SetupEvents initializes the events context
func SetupEvents(ctx context.Context) {
	EventsContext = ctx
	// Register a listener that will emit events to the frontend
	RegisterChangeListener(emitCredentialChangeEvent)
}

// emitCredentialChangeEvent sends credential change events to the frontend
func emitCredentialChangeEvent(credType CredentialType, action string) {
	if EventsContext != nil {
		// Create an event payload
		payload := map[string]interface{}{
			"type":   string(credType),
			"action": action,
		}

		// Emit the event
		runtime.EventsEmit(EventsContext, "credential-change", payload)

		// Also emit a specific event for the credential type
		specificEvent := "credential-" + string(credType)
		runtime.EventsEmit(EventsContext, specificEvent, payload)
	}
}

// LLMCredentialChangeHandler is a function that refreshes LLM clients when OpenAI or Gemini credentials change
type LLMCredentialChangeHandler interface {
	RefreshLLMClients()
}

// TMDBCredentialChangeHandler is a function that refreshes TMDB clients when TMDB credentials change
type TMDBCredentialChangeHandler interface {
	RefreshCredentials() bool
}

// RAWGCredentialChangeHandler is a function that refreshes RAWG clients when RAWG credentials change
type RAWGCredentialChangeHandler interface {
	RefreshCredentials() bool
}

// RegisterLLMClientRefreshHandler registers handlers that will refresh LLM clients when OpenAI or Gemini credentials change
func RegisterLLMClientRefreshHandler(handler LLMCredentialChangeHandler) {
	// Register a listener that will call RefreshLLMClients on the handler when OpenAI or Gemini credentials change
	RegisterChangeListener(func(credType CredentialType, action string) {
		// Only refresh for OpenAI or Gemini credential changes
		if credType == OpenAICredential || credType == GeminiCredential {
			// Log the credential change and refresh action
			runtime.LogInfo(EventsContext, "Refreshing LLM clients due to "+string(credType)+" credential "+action)

			// Refresh the LLM clients
			handler.RefreshLLMClients()
		}
	})
}

// RegisterTMDBClientRefreshHandler registers handlers that will refresh TMDB clients when TMDB credentials change
func RegisterTMDBClientRefreshHandler(handler TMDBCredentialChangeHandler) {
	// Register a listener that will call RefreshCredentials on the handler when TMDB credentials change
	RegisterChangeListener(func(credType CredentialType, action string) {
		// Only refresh for TMDB credential changes
		if credType == TMDBCredential {
			// Log the credential change and refresh action
			runtime.LogInfo(EventsContext, "Refreshing TMDB client due to credential "+action)

			// Refresh the TMDB client
			handler.RefreshCredentials()
		}
	})
}

// RegisterRAWGClientRefreshHandler registers handlers that will refresh RAWG clients when RAWG credentials change
func RegisterRAWGClientRefreshHandler(handler RAWGCredentialChangeHandler) {
	// Register a listener that will call RefreshCredentials on the handler when RAWG credentials change
	RegisterChangeListener(func(credType CredentialType, action string) {
		// Only refresh for RAWG credential changes
		if credType == RAWGCredential {
			// Log the credential change and refresh action
			runtime.LogInfo(EventsContext, "Refreshing RAWG client due to credential "+action)

			// Refresh the RAWG client
			handler.RefreshCredentials()
		}
	})
}
