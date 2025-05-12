package ffi

/*
#include <stdlib.h>
*/
import "C"

import (
	"context"
	"interestnaut/internal/app/bindings"
	"interestnaut/internal/app/bridge"
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
	
	bridge.ExecuteOnFFIThread(func() {
		if !ensureMusicBindingsInitialized() {
			result = C.CString("{\"error\": \"Music bindings not initialized\"}")
			return
		}
	
		status := musicBindings.GetAuthStatus()
		result = returnJSON(status)
	})
	
	return result
}

//export Music_GetSavedTracks
func Music_GetSavedTracks(limitC, offsetC C.int) *C.char {
	var result *C.char
	
	bridge.ExecuteOnFFIThread(func() {
		if !ensureMusicBindingsInitialized() {
			result = C.CString("{\"error\": \"Music bindings not initialized\"}")
			return
		}
	
		limit := int(limitC)
		offset := int(offsetC)
	
		tracks, err := musicBindings.GetSavedTracks(limit, offset)
		if err != nil {
			result = processError(err)
			return
		}
	
		result = returnJSON(tracks)
	})
	
	return result
}

//export Music_SaveTrack
func Music_SaveTrack(trackIDC *C.char) *C.char {
	var result *C.char
	trackID := C.GoString(trackIDC)
	defer C.free(unsafe.Pointer(trackIDC))
	
	bridge.ExecuteOnFFIThread(func() {
		if !ensureMusicBindingsInitialized() {
			result = C.CString("{\"error\": \"Music bindings not initialized\"}")
			return
		}
	
		err := musicBindings.SaveTrack(trackID)
		result = processError(err)
	})
	
	return result
}

//export Music_RemoveTrack
func Music_RemoveTrack(trackIDC *C.char) *C.char {
	var result *C.char
	trackID := C.GoString(trackIDC)
	defer C.free(unsafe.Pointer(trackIDC))
	
	bridge.ExecuteOnFFIThread(func() {
		if !ensureMusicBindingsInitialized() {
			result = C.CString("{\"error\": \"Music bindings not initialized\"}")
			return
		}
	
		err := musicBindings.RemoveTrack(trackID)
		result = processError(err)
	})
	
	return result
}

//export Music_GetCurrentUser
func Music_GetCurrentUser() *C.char {
	var result *C.char
	
	bridge.ExecuteOnFFIThread(func() {
		if !ensureMusicBindingsInitialized() {
			result = C.CString("{\"error\": \"Music bindings not initialized\"}")
			return
		}
	
		user, err := musicBindings.GetCurrentUser()
		if err != nil {
			result = processError(err)
			return
		}
	
		result = returnJSON(user)
	})
	
	return result
}

//export Music_RequestNewSuggestion
func Music_RequestNewSuggestion() *C.char {
	var result *C.char
	
	bridge.ExecuteOnFFIThread(func() {
		if !ensureMusicBindingsInitialized() {
			result = C.CString("{\"error\": \"Music bindings not initialized\"}")
			return
		}
	
		suggestion, err := musicBindings.RequestNewSuggestion()
		if err != nil {
			result = processError(err)
			return
		}
	
		result = returnJSON(suggestion)
	})
	
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
	
	bridge.ExecuteOnFFIThread(func() {
		if !ensureMusicBindingsInitialized() {
			result = C.CString("{\"error\": \"Music bindings not initialized\"}")
			return
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
	})
	
	return result
}

//export Music_GetValidToken
func Music_GetValidToken() *C.char {
	var result *C.char
	
	bridge.ExecuteOnFFIThread(func() {
		if !ensureMusicBindingsInitialized() {
			result = C.CString("{\"error\": \"Music bindings not initialized\"}")
			return
		}
	
		token, err := musicBindings.GetValidToken()
		if err != nil {
			result = processError(err)
			return
		}
	
		result = C.CString(token)
	})
	
	return result
}

//export Music_ClearSpotifyCredentials
func Music_ClearSpotifyCredentials() *C.char {
	var result *C.char
	
	bridge.ExecuteOnFFIThread(func() {
		if !ensureMusicBindingsInitialized() {
			result = C.CString("{\"error\": \"Music bindings not initialized\"}")
			return
		}
	
		err := musicBindings.ClearSpotifyCredentials()
		result = processError(err)
	})
	
	return result
}

//export Music_SearchTracks
func Music_SearchTracks(queryC *C.char, limitC C.int) *C.char {
	var result *C.char
	
	query := C.GoString(queryC)
	limit := int(limitC)
	defer C.free(unsafe.Pointer(queryC))
	
	bridge.ExecuteOnFFIThread(func() {
		if !ensureMusicBindingsInitialized() {
			result = C.CString("{\"error\": \"Music bindings not initialized\"}")
			return
		}
	
		tracks, err := musicBindings.SearchTracks(query, limit)
		if err != nil {
			result = processError(err)
			return
		}
	
		result = returnJSON(tracks)
	})
	
	return result
}

//export Music_InitiateSpotifyAuth
func Music_InitiateSpotifyAuth() *C.char {
	var result *C.char
	
	// Execute on the dedicated FFI thread
	bridge.ExecuteOnFFIThread(func() {
		// Ensure music bindings are initialized
		if !ensureMusicBindingsInitialized() {
			result = C.CString("{\"error\": \"Failed to initialize music bindings\"}")
			return
		}

		// Just start the authorization process and return a success message
		// Since we're using the browser-based flow, there's not a lot to return
		err := musicBindings.InitiateSpotifyAuth()
		if err != nil {
			log.Printf("Error initiating Spotify auth: %v", err)
			result = processError(err)
			return
		}

		if pid := os.Getpid(); pid > 0 {
			log.Printf("Spotify auth initiated. PID is: %d", pid)
		}

		// Return authentication status to allow the UI to update
		authStatus := musicBindings.GetAuthStatus()
		result = returnJSON(authStatus)
	})
	
	return result
}

//export Music_PlayTrackOnDevice
func Music_PlayTrackOnDevice(deviceIDC, trackURIC *C.char) *C.char {
	var result *C.char
	
	deviceID := C.GoString(deviceIDC)
	trackURI := C.GoString(trackURIC)

	defer C.free(unsafe.Pointer(deviceIDC))
	defer C.free(unsafe.Pointer(trackURIC))
	
	bridge.ExecuteOnFFIThread(func() {
		if !ensureMusicBindingsInitialized() {
			result = C.CString("{\"error\": \"Music bindings not initialized\"}")
			return
		}
	
		err := musicBindings.PlayTrackOnDevice(deviceID, trackURI)
		result = processError(err)
	})
	
	return result
}

//export Music_PausePlaybackOnDevice
func Music_PausePlaybackOnDevice(deviceIDC *C.char) *C.char {
	var result *C.char
	
	deviceID := C.GoString(deviceIDC)
	defer C.free(unsafe.Pointer(deviceIDC))
	
	bridge.ExecuteOnFFIThread(func() {
		if !ensureMusicBindingsInitialized() {
			result = C.CString("{\"error\": \"Music bindings not initialized\"}")
			return
		}
	
		err := musicBindings.PausePlaybackOnDevice(deviceID)
		result = processError(err)
	})
	
	return result
}

// Note: Music_GetActivePlaybackState is removed as it causes polling issues
