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
	log.Println("Music_InitiateSpotifyAuth CALLED (stdout)")
	f, errFile := os.OpenFile("/tmp/interestnaut_go.log", os.O_RDWR|os.O_CREATE|os.O_APPEND, 0666)
	if errFile != nil {
		log.Printf("Error opening log file: %v", errFile)
	} else {
		log.SetOutput(f)
		defer f.Close()
	}
	log.Println("Music_InitiateSpotifyAuth CALLED (log output)")

	if musicBindings == nil {
		log.Println("musicBindings is nil!")
		return C.CString("{\"error\": \"Music bindings not initialized\"}")
	}
	err := musicBindings.InitiateSpotifyAuth()
	if err != nil {
		log.Printf("InitiateSpotifyAuth error: %v", err)
	}
	log.SetOutput(os.Stdout)
	return processError(err)
}
