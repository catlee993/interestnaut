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

//export Games_HasValidCredentials
func Games_HasValidCredentials() *C.char {
	if gameBindings == nil {
		return C.CString("{\"error\": \"Game bindings not initialized\"}")
	}

	result := gameBindings.HasValidCredentials()
	return returnJSON(map[string]bool{"valid": result})
}

//export Games_RefreshCredentials
func Games_RefreshCredentials() *C.char {
	if gameBindings == nil {
		return C.CString("{\"error\": \"Game bindings not initialized\"}")
	}

	result := gameBindings.RefreshCredentials()
	return returnJSON(map[string]bool{"success": result})
}

//export Games_SearchGames
func Games_SearchGames(queryC *C.char) *C.char {
	if gameBindings == nil {
		return C.CString("{\"error\": \"Game bindings not initialized\"}")
	}

	query := C.GoString(queryC)
	defer C.free(unsafe.Pointer(queryC))

	games, err := gameBindings.SearchGames(query)
	if err != nil {
		return processError(err)
	}

	return returnJSON(games)
}

//export Games_GetGameDetails
func Games_GetGameDetails(gameIDC *C.char) *C.char {
	if gameBindings == nil {
		return C.CString("{\"error\": \"Game bindings not initialized\"}")
	}

	gameIDStr := C.GoString(gameIDC)
	defer C.free(unsafe.Pointer(gameIDC))

	gameID, err := strconv.Atoi(gameIDStr)
	if err != nil {
		return processError(err)
	}

	game, err := gameBindings.GetGameDetails(gameID)
	if err != nil {
		return processError(err)
	}

	return returnJSON(game)
}

//export Games_GetGameSuggestion
func Games_GetGameSuggestion() *C.char {
	if gameBindings == nil {
		return C.CString("{\"error\": \"Game bindings not initialized\"}")
	}

	suggestion, err := gameBindings.GetGameSuggestion()
	if err != nil {
		log.Printf("ERROR getting game suggestion: %v", err)
		return processError(err)
	}

	return returnJSON(suggestion)
}

//export Games_ProvideSuggestionFeedback
func Games_ProvideSuggestionFeedback(outcomeC, gameIDC *C.char) *C.char {
	if gameBindings == nil {
		return C.CString("{\"error\": \"Game bindings not initialized\"}")
	}

	outcomeStr := C.GoString(outcomeC)
	gameIDStr := C.GoString(gameIDC)
	defer C.free(unsafe.Pointer(outcomeC))
	defer C.free(unsafe.Pointer(gameIDC))

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

	gameID, err := strconv.Atoi(gameIDStr)
	if err != nil {
		return processError(err)
	}

	err = gameBindings.ProvideSuggestionFeedback(outcome, gameID)
	return processError(err)
}

//export Games_GetFavoriteGames
func Games_GetFavoriteGames() *C.char {
	if gameBindings == nil {
		return C.CString("{\"error\": \"Game bindings not initialized\"}")
	}

	games, err := gameBindings.GetFavoriteGames()
	if err != nil {
		return processError(err)
	}

	return returnJSON(games)
}

//export Games_SetFavoriteGames
func Games_SetFavoriteGames(gamesJsonC *C.char) *C.char {
	if gameBindings == nil {
		return C.CString("{\"error\": \"Game bindings not initialized\"}")
	}

	gamesJson := C.GoString(gamesJsonC)
	defer C.free(unsafe.Pointer(gamesJsonC))

	var games []session.VideoGame
	err := json.Unmarshal([]byte(gamesJson), &games)
	if err != nil {
		return processError(err)
	}

	err = gameBindings.SetFavoriteGames(games)
	return processError(err)
}

//export Games_AddToWatchlist
func Games_AddToWatchlist(gameJsonC *C.char) *C.char {
	if gameBindings == nil {
		return C.CString("{\"error\": \"Game bindings not initialized\"}")
	}

	gameJson := C.GoString(gameJsonC)
	defer C.free(unsafe.Pointer(gameJsonC))

	var game session.VideoGame
	err := json.Unmarshal([]byte(gameJson), &game)
	if err != nil {
		return processError(err)
	}

	err = gameBindings.AddToWatchlist(game)
	return processError(err)
}

//export Games_RemoveFromWatchlist
func Games_RemoveFromWatchlist(titleC *C.char) *C.char {
	if gameBindings == nil {
		return C.CString("{\"error\": \"Game bindings not initialized\"}")
	}

	title := C.GoString(titleC)
	defer C.free(unsafe.Pointer(titleC))

	err := gameBindings.RemoveFromWatchlist(title)
	return processError(err)
}

//export Games_GetWatchlist
func Games_GetWatchlist() *C.char {
	if gameBindings == nil {
		return C.CString("{\"error\": \"Game bindings not initialized\"}")
	}

	games, err := gameBindings.GetWatchlist()
	if err != nil {
		return processError(err)
	}

	return returnJSON(games)
}

//export Games_RefreshLLMClients
func Games_RefreshLLMClients() *C.char {
	if gameBindings == nil {
		return C.CString("{\"error\": \"Game bindings not initialized\"}")
	}

	gameBindings.RefreshLLMClients()
	return C.CString("{}")
}
