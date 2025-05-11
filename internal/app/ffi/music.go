package ffi

/*
#include <stdlib.h>
*/
import "C"

import (
	"interestnaut/internal/app/session"
	"log"
	"os"
	"unsafe"
)

//export Music_GetAuthStatus
func Music_GetAuthStatus() *C.char {
	if musicBindings == nil {
		return C.CString("{\"error\": \"Music bindings not initialized\"}")
	}

	status := musicBindings.GetAuthStatus()
	return returnJSON(status)
}

//export Music_GetSavedTracks
func Music_GetSavedTracks(limitC, offsetC C.int) *C.char {
	if musicBindings == nil {
		return C.CString("{\"error\": \"Music bindings not initialized\"}")
	}

	limit := int(limitC)
	offset := int(offsetC)

	tracks, err := musicBindings.GetSavedTracks(limit, offset)
	if err != nil {
		return processError(err)
	}

	return returnJSON(tracks)
}

//export Music_SaveTrack
func Music_SaveTrack(trackIDC *C.char) *C.char {
	if musicBindings == nil {
		return C.CString("{\"error\": \"Music bindings not initialized\"}")
	}

	trackID := C.GoString(trackIDC)
	defer C.free(unsafe.Pointer(trackIDC))

	err := musicBindings.SaveTrack(trackID)
	return processError(err)
}

//export Music_RemoveTrack
func Music_RemoveTrack(trackIDC *C.char) *C.char {
	if musicBindings == nil {
		return C.CString("{\"error\": \"Music bindings not initialized\"}")
	}

	trackID := C.GoString(trackIDC)
	defer C.free(unsafe.Pointer(trackIDC))

	err := musicBindings.RemoveTrack(trackID)
	return processError(err)
}

//export Music_GetCurrentUser
func Music_GetCurrentUser() *C.char {
	if musicBindings == nil {
		return C.CString("{\"error\": \"Music bindings not initialized\"}")
	}

	user, err := musicBindings.GetCurrentUser()
	if err != nil {
		return processError(err)
	}

	return returnJSON(user)
}

//export Music_RequestNewSuggestion
func Music_RequestNewSuggestion() *C.char {
	if musicBindings == nil {
		return C.CString("{\"error\": \"Music bindings not initialized\"}")
	}

	suggestion, err := musicBindings.RequestNewSuggestion()
	if err != nil {
		return processError(err)
	}

	return returnJSON(suggestion)
}

//export Music_ProvideSuggestionFeedback
func Music_ProvideSuggestionFeedback(outcomeC, titleC, artistC, albumC *C.char) *C.char {
	if musicBindings == nil {
		return C.CString("{\"error\": \"Music bindings not initialized\"}")
	}

	outcomeStr := C.GoString(outcomeC)
	title := C.GoString(titleC)
	artist := C.GoString(artistC)
	album := C.GoString(albumC)

	defer C.free(unsafe.Pointer(outcomeC))
	defer C.free(unsafe.Pointer(titleC))
	defer C.free(unsafe.Pointer(artistC))
	defer C.free(unsafe.Pointer(albumC))

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
	return processError(err)
}

//export Music_GetValidToken
func Music_GetValidToken() *C.char {
	if musicBindings == nil {
		return C.CString("{\"error\": \"Music bindings not initialized\"}")
	}

	token, err := musicBindings.GetValidToken()
	if err != nil {
		return processError(err)
	}

	return C.CString(token)
}

//export Music_ClearSpotifyCredentials
func Music_ClearSpotifyCredentials() *C.char {
	if musicBindings == nil {
		return C.CString("{\"error\": \"Music bindings not initialized\"}")
	}

	err := musicBindings.ClearSpotifyCredentials()
	return processError(err)
}

//export Music_SearchTracks
func Music_SearchTracks(queryC *C.char, limitC C.int) *C.char {
	if musicBindings == nil {
		return C.CString("{\"error\": \"Music bindings not initialized\"}")
	}

	query := C.GoString(queryC)
	limit := int(limitC)

	defer C.free(unsafe.Pointer(queryC))

	tracks, err := musicBindings.SearchTracks(query, limit)
	if err != nil {
		return processError(err)
	}

	return returnJSON(tracks)
}

//export Music_InitiateSpotifyAuth
func Music_InitiateSpotifyAuth() *C.char {
	if musicBindings == nil {
		return C.CString("{\"error\": \"Music bindings not initialized\"}")
	}

	// Just start the authorization process and return a success message
	// Since we're using the browser-based flow, there's not a lot to return
	err := musicBindings.InitiateSpotifyAuth()
	if err != nil {
		log.Printf("Error initiating Spotify auth: %v", err)
		return processError(err)
	}

	if pid := os.Getpid(); pid > 0 {
		log.Printf("Spotify auth initiated. PID is: %d", pid)
	}

	return C.CString("{\"status\": \"initiated\"}")
}

//export Music_PlayTrackOnDevice
func Music_PlayTrackOnDevice(deviceIDC, trackURIC *C.char) *C.char {
	if musicBindings == nil {
		return C.CString("{\"error\": \"Music bindings not initialized\"}")
	}

	deviceID := C.GoString(deviceIDC)
	trackURI := C.GoString(trackURIC)
	defer C.free(unsafe.Pointer(deviceIDC))
	defer C.free(unsafe.Pointer(trackURIC))

	err := musicBindings.PlayTrackOnDevice(deviceID, trackURI)
	if err != nil {
		return processError(err)
	}

	return C.CString("{\"success\": true}")
}

//export Music_PausePlaybackOnDevice
func Music_PausePlaybackOnDevice(deviceIDC *C.char) *C.char {
	if musicBindings == nil {
		return C.CString("{\"error\": \"Music bindings not initialized\"}")
	}

	deviceID := C.GoString(deviceIDC)
	defer C.free(unsafe.Pointer(deviceIDC))

	err := musicBindings.PausePlaybackOnDevice(deviceID)
	if err != nil {
		return processError(err)
	}

	return C.CString("{\"status\": \"success\"}")
}

// Note: Music_GetActivePlaybackState is removed as it causes polling issues
