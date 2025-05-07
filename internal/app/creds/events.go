package creds

import (
	"context"

	"github.com/wailsapp/wails/v2/pkg/runtime"
)

var EventsContext context.Context

func SetupEvents(ctx context.Context) {
	EventsContext = ctx
	RegisterChangeListener(emitCredentialChangeEvent)
}

func emitCredentialChangeEvent(credType CredentialType, action string) {
	if EventsContext != nil {
		payload := map[string]interface{}{
			"type":   string(credType),
			"action": action,
		}

		runtime.EventsEmit(EventsContext, "credential-change", payload)

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

func RegisterLLMClientRefreshHandler(handler LLMCredentialChangeHandler) {
	RegisterChangeListener(func(credType CredentialType, action string) {
		if credType == OpenAICredential || credType == GeminiCredential {
			runtime.LogInfo(EventsContext, "Refreshing LLM clients due to "+string(credType)+" credential "+action)
			handler.RefreshLLMClients()
		}
	})
}

func RegisterTMDBClientRefreshHandler(handler TMDBCredentialChangeHandler) {
	RegisterChangeListener(func(credType CredentialType, action string) {
		if credType == TMDBCredential {
			runtime.LogInfo(EventsContext, "Refreshing TMDB client due to credential "+action)
			handler.RefreshCredentials()
		}
	})
}

func RegisterRAWGClientRefreshHandler(handler RAWGCredentialChangeHandler) {
	RegisterChangeListener(func(credType CredentialType, action string) {
		if credType == RAWGCredential {
			runtime.LogInfo(EventsContext, "Refreshing RAWG client due to credential "+action)
			handler.RefreshCredentials()
		}
	})
}
