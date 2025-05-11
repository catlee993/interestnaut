package ffi

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"interestnaut/internal/app/session"
	"log"
	"strconv"
	"unsafe"
)

//export TV_HasValidCredentials
func TV_HasValidCredentials() *C.char {
	if tvBindings == nil {
		return C.CString("{\"error\": \"TV bindings not initialized\"}")
	}

	result := tvBindings.HasValidCredentials()
	return returnJSON(map[string]bool{"valid": result})
}

//export TV_RefreshCredentials
func TV_RefreshCredentials() *C.char {
	if tvBindings == nil {
		return C.CString("{\"error\": \"TV bindings not initialized\"}")
	}

	result := tvBindings.RefreshCredentials()
	return returnJSON(map[string]bool{"success": result})
}

//export TV_SearchTVShows
func TV_SearchTVShows(queryC *C.char) *C.char {
	if tvBindings == nil {
		return C.CString("{\"error\": \"TV bindings not initialized\"}")
	}

	query := C.GoString(queryC)
	defer C.free(unsafe.Pointer(queryC))

	shows, err := tvBindings.SearchTVShows(query)
	if err != nil {
		return processError(err)
	}

	return returnJSON(shows)
}

//export TV_GetTVShowDetails
func TV_GetTVShowDetails(showIDC *C.char) *C.char {
	if tvBindings == nil {
		return C.CString("{\"error\": \"TV bindings not initialized\"}")
	}

	showIDStr := C.GoString(showIDC)
	defer C.free(unsafe.Pointer(showIDC))

	showID, err := strconv.Atoi(showIDStr)
	if err != nil {
		return processError(err)
	}

	show, err := tvBindings.GetTVShowDetails(showID)
	if err != nil {
		return processError(err)
	}

	return returnJSON(show)
}

//export TV_GetTVShowSuggestion
func TV_GetTVShowSuggestion() *C.char {
	if tvBindings == nil {
		return C.CString("{\"error\": \"TV bindings not initialized\"}")
	}

	suggestion, err := tvBindings.GetTVShowSuggestion()
	if err != nil {
		log.Printf("ERROR getting TV show suggestion: %v", err)
		return processError(err)
	}

	return returnJSON(suggestion)
}

//export TV_ProvideSuggestionFeedback
func TV_ProvideSuggestionFeedback(outcomeC, showIDC *C.char) *C.char {
	if tvBindings == nil {
		return C.CString("{\"error\": \"TV bindings not initialized\"}")
	}

	outcomeStr := C.GoString(outcomeC)
	showIDStr := C.GoString(showIDC)
	defer C.free(unsafe.Pointer(outcomeC))
	defer C.free(unsafe.Pointer(showIDC))

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

	showID, err := strconv.Atoi(showIDStr)
	if err != nil {
		return processError(err)
	}

	err = tvBindings.ProvideSuggestionFeedback(outcome, showID)
	return processError(err)
}

//export TV_GetFavoriteTVShows
func TV_GetFavoriteTVShows() *C.char {
	if tvBindings == nil {
		return C.CString("{\"error\": \"TV bindings not initialized\"}")
	}

	shows, err := tvBindings.GetFavoriteTVShows()
	if err != nil {
		return processError(err)
	}

	return returnJSON(shows)
}

//export TV_SetFavoriteTVShows
func TV_SetFavoriteTVShows(showsJsonC *C.char) *C.char {
	if tvBindings == nil {
		return C.CString("{\"error\": \"TV bindings not initialized\"}")
	}

	showsJson := C.GoString(showsJsonC)
	defer C.free(unsafe.Pointer(showsJsonC))

	var shows []session.TVShow
	err := json.Unmarshal([]byte(showsJson), &shows)
	if err != nil {
		return processError(err)
	}

	err = tvBindings.SetFavoriteTVShows(shows)
	return processError(err)
}

//export TV_AddToWatchlist
func TV_AddToWatchlist(showJsonC *C.char) *C.char {
	if tvBindings == nil {
		return C.CString("{\"error\": \"TV bindings not initialized\"}")
	}

	showJson := C.GoString(showJsonC)
	defer C.free(unsafe.Pointer(showJsonC))

	var show session.TVShow
	err := json.Unmarshal([]byte(showJson), &show)
	if err != nil {
		return processError(err)
	}

	err = tvBindings.AddToWatchlist(show)
	return processError(err)
}

//export TV_RemoveFromWatchlist
func TV_RemoveFromWatchlist(titleC *C.char) *C.char {
	if tvBindings == nil {
		return C.CString("{\"error\": \"TV bindings not initialized\"}")
	}

	title := C.GoString(titleC)
	defer C.free(unsafe.Pointer(titleC))

	err := tvBindings.RemoveFromWatchlist(title)
	return processError(err)
}

//export TV_GetWatchlist
func TV_GetWatchlist() *C.char {
	if tvBindings == nil {
		return C.CString("{\"error\": \"TV bindings not initialized\"}")
	}

	shows, err := tvBindings.GetWatchlist()
	if err != nil {
		return processError(err)
	}

	return returnJSON(shows)
}

//export TV_RefreshLLMClients
func TV_RefreshLLMClients() *C.char {
	if tvBindings == nil {
		return C.CString("{\"error\": \"TV bindings not initialized\"}")
	}

	tvBindings.RefreshLLMClients()
	return C.CString("{}")
}
