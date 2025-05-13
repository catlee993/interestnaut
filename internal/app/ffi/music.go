package ffi

/*
#include <stdlib.h>
*/
import "C"

import (
	"context"
	"encoding/json"
	"interestnaut/internal/app/bindings"
	"interestnaut/internal/app/eventbus"
	"interestnaut/internal/app/session"
	"log"
	"os"
	"unsafe"
)

// ensureMusicBindingsInitialized makes sure music bindings are initialized
// Returns true if initialization was successful (either already done or newly initialized)
func ensureMusicBindingsInitialized() bool {
	if musicBindings != nil {
		return true
	}

	log.Println("Music bindings not initialized, attempting to initialize...")

	// Create a central manager if needed
	if centralManager == nil {
		ctx := context.Background()
		cm, err := session.NewCentralManager(ctx, session.DefaultUserID)
		if err != nil {
			log.Printf("Failed to create central manager: %v", err)
			return false
		}
		centralManager = cm
	}

	// Initialize music bindings
	musicBindings = bindings.NewMusicBinder(context.Background(), centralManager, "3bb48a30577342869a9ffcb176dee7d2")

	if musicBindings == nil {
		log.Println("CRITICAL: Failed to initialize music bindings")
		return false
	}

	log.Println("Music bindings initialized successfully on-demand")
	return true
}

//export Music_GetAuthStatus
func Music_GetAuthStatus() *C.char {
	var result *C.char

	if !ensureMusicBindingsInitialized() {
		result = C.CString("{\"error\": \"Music bindings not initialized\"}")
		return result
	}

	status := musicBindings.GetAuthStatus()
	jsonBytes, _ := json.Marshal(status)
	result = C.CString(string(jsonBytes))

	return result
}

//export Music_GetSavedTracks
func Music_GetSavedTracks(limitC, offsetC C.int) *C.char {
	var result *C.char

	if !ensureMusicBindingsInitialized() {
		result = C.CString("{\"error\": \"Music bindings not initialized\"}")
		return result
	}

	limit := int(limitC)
	offset := int(offsetC)

	tracks, err := musicBindings.GetSavedTracks(limit, offset)
	if err != nil {
		result = processError(err)
		return result
	}

	jsonBytes, _ := json.Marshal(tracks)
	result = C.CString(string(jsonBytes))

	return result
}

//export Music_SaveTrack
func Music_SaveTrack(trackIDC *C.char) *C.char {
	var result *C.char
	trackID := C.GoString(trackIDC)
	defer C.free(unsafe.Pointer(trackIDC))

	if !ensureMusicBindingsInitialized() {
		result = C.CString("{\"error\": \"Music bindings not initialized\"}")
		return result
	}

	err := musicBindings.SaveTrack(trackID)
	result = processError(err)

	return result
}

//export Music_RemoveTrack
func Music_RemoveTrack(trackIDC *C.char) *C.char {
	var result *C.char
	trackID := C.GoString(trackIDC)
	defer C.free(unsafe.Pointer(trackIDC))

	if !ensureMusicBindingsInitialized() {
		result = C.CString("{\"error\": \"Music bindings not initialized\"}")
		return result
	}

	err := musicBindings.RemoveTrack(trackID)
	result = processError(err)

	return result
}

//export Music_GetCurrentUser
func Music_GetCurrentUser() *C.char {
	var result *C.char

	if !ensureMusicBindingsInitialized() {
		result = C.CString("{\"error\": \"Music bindings not initialized\"}")
		return result
	}

	user, err := musicBindings.GetCurrentUser()
	if err != nil {
		result = processError(err)
		return result
	}

	jsonBytes, _ := json.Marshal(user)
	result = C.CString(string(jsonBytes))

	return result
}

//export Music_RequestNewSuggestion
func Music_RequestNewSuggestion() *C.char {
	var result *C.char

	if !ensureMusicBindingsInitialized() {
		result = C.CString("{\"error\": \"Music bindings not initialized\"}")
		return result
	}

	suggestion, err := musicBindings.RequestNewSuggestion()
	if err != nil {
		result = processError(err)
		return result
	}

	jsonBytes, _ := json.Marshal(suggestion)
	result = C.CString(string(jsonBytes))

	return result
}

//export Music_ProvideSuggestionFeedback
func Music_ProvideSuggestionFeedback(outcomeC, titleC, artistC, albumC *C.char) *C.char {
	var result *C.char

	outcomeStr := C.GoString(outcomeC)
	title := C.GoString(titleC)
	artist := C.GoString(artistC)
	album := C.GoString(albumC)

	defer C.free(unsafe.Pointer(outcomeC))
	defer C.free(unsafe.Pointer(titleC))
	defer C.free(unsafe.Pointer(artistC))
	defer C.free(unsafe.Pointer(albumC))

	if !ensureMusicBindingsInitialized() {
		result = C.CString("{\"error\": \"Music bindings not initialized\"}")
		return result
	}

	// Convert outcome string to session.Outcome enum
	var outcome session.Outcome
	switch outcomeStr {
	case "liked":
		outcome = session.Liked
	case "disliked":
		outcome = session.Disliked
	case "added":
		outcome = session.Added
	default:
		outcome = session.Pending
	}

	err := musicBindings.ProvideSuggestionFeedback(outcome, title, artist, album)
	result = processError(err)

	return result
}

//export Music_GetValidToken
func Music_GetValidToken() *C.char {
	var result *C.char

	if !ensureMusicBindingsInitialized() {
		result = C.CString("{\"error\": \"Music bindings not initialized\"}")
		return result
	}

	token, err := musicBindings.GetValidToken()
	if err != nil {
		result = processError(err)
		return result
	}

	result = C.CString(token)

	return result
}

//export Music_ClearSpotifyCredentials
func Music_ClearSpotifyCredentials() *C.char {
	var result *C.char

	if !ensureMusicBindingsInitialized() {
		result = C.CString("{\"error\": \"Music bindings not initialized\"}")
		return result
	}

	err := musicBindings.ClearSpotifyCredentials()
	if err == nil {
		eventbus.Emit(eventbus.Event{
			Type: "spotify_auth_status_changed",
			Payload: map[string]interface{}{
				"isAuthenticated": false,
				"userProfile":     nil,
			},
		})
	}
	result = processError(err)

	return result
}

//export Music_SearchTracks
func Music_SearchTracks(queryC *C.char, limitC C.int) *C.char {
	var result *C.char

	query := C.GoString(queryC)
	limit := int(limitC)
	defer C.free(unsafe.Pointer(queryC))

	if !ensureMusicBindingsInitialized() {
		result = C.CString("{\"error\": \"Music bindings not initialized\"}")
		return result
	}

	tracks, err := musicBindings.SearchTracks(query, limit)
	if err != nil {
		result = processError(err)
		return result
	}

	jsonBytes, _ := json.Marshal(tracks)
	result = C.CString(string(jsonBytes))

	return result
}

//export Music_InitiateSpotifyAuth
func Music_InitiateSpotifyAuth() *C.char {
	var result *C.char

	if !ensureMusicBindingsInitialized() {
		result = C.CString("{\"error\": \"Failed to initialize music bindings\"}")
		return result
	}

	err := musicBindings.InitiateSpotifyAuth()
	if err != nil {
		log.Printf("Music_InitiateSpotifyAuth failed: %v", err)
	}

	if pid := os.Getpid(); pid > 0 {
		log.Printf("Spotify auth initiated. PID is: %d", pid)
	}

	authStatus := musicBindings.GetAuthStatus()
	jsonBytes, _ := json.Marshal(authStatus)
	result = C.CString(string(jsonBytes))

	return result
}

//export Music_PlayTrackOnDevice
func Music_PlayTrackOnDevice(deviceIDC, trackURIC *C.char) *C.char {
	var result *C.char

	deviceID := C.GoString(deviceIDC)
	trackURI := C.GoString(trackURIC)

	defer C.free(unsafe.Pointer(deviceIDC))
	defer C.free(unsafe.Pointer(trackURIC))

	if !ensureMusicBindingsInitialized() {
		result = C.CString("{\"error\": \"Music bindings not initialized\"}")
		return result
	}

	err := musicBindings.PlayTrackOnDevice(deviceID, trackURI)
	result = processError(err)

	return result
}

//export Music_PausePlaybackOnDevice
func Music_PausePlaybackOnDevice(deviceIDC *C.char) *C.char {
	var result *C.char

	deviceID := C.GoString(deviceIDC)
	defer C.free(unsafe.Pointer(deviceIDC))

	if !ensureMusicBindingsInitialized() {
		result = C.CString("{\"error\": \"Music bindings not initialized\"}")
		return result
	}

	err := musicBindings.PausePlaybackOnDevice(deviceID)
	result = processError(err)

	return result
}

// Note: Music_GetActivePlaybackState is removed as it causes polling issues
