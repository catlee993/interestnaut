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
