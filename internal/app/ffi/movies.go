package ffi

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"interestnaut/internal/app/session"
	"unsafe"
)

//export Movies_HasValidCredentials
func Movies_HasValidCredentials() C.int {
	if movieBindings == nil {
		return C.int(0)
	}

	if movieBindings.HasValidCredentials() {
		return C.int(1)
	}
	return C.int(0)
}

//export Movies_RefreshCredentials
func Movies_RefreshCredentials() C.int {
	if movieBindings == nil {
		return C.int(0)
	}

	if movieBindings.RefreshCredentials() {
		return C.int(1)
	}
	return C.int(0)
}

//export Movies_SearchMovies
func Movies_SearchMovies(queryC *C.char) *C.char {
	if movieBindings == nil {
		return C.CString("{\"error\": \"Movie bindings not initialized\"}")
	}

	query := C.GoString(queryC)
	defer C.free(unsafe.Pointer(queryC))

	movies, err := movieBindings.SearchMovies(query)
	if err != nil {
		return processError(err)
	}

	return returnJSON(movies)
}

//export Movies_GetMovieDetails
func Movies_GetMovieDetails(movieIDC C.int) *C.char {
	if movieBindings == nil {
		return C.CString("{\"error\": \"Movie bindings not initialized\"}")
	}

	movieID := int(movieIDC)

	movie, err := movieBindings.GetMovieDetails(movieID)
	if err != nil {
		return processError(err)
	}

	return returnJSON(movie)
}

//export Movies_GetMovieSuggestion
func Movies_GetMovieSuggestion() *C.char {
	if movieBindings == nil {
		return C.CString("{\"error\": \"Movie bindings not initialized\"}")
	}

	suggestion, err := movieBindings.GetMovieSuggestion()
	if err != nil {
		return processError(err)
	}

	return returnJSON(suggestion)
}

//export Movies_ProvideSuggestionFeedback
func Movies_ProvideSuggestionFeedback(outcomeC *C.char, movieIDC C.int) *C.char {
	if movieBindings == nil {
		return C.CString("{\"error\": \"Movie bindings not initialized\"}")
	}

	outcomeStr := C.GoString(outcomeC)
	movieID := int(movieIDC)

	defer C.free(unsafe.Pointer(outcomeC))

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

	err := movieBindings.ProvideSuggestionFeedback(outcome, movieID)
	return processError(err)
}

//export Movies_GetFavoriteMovies
func Movies_GetFavoriteMovies() *C.char {
	if movieBindings == nil {
		return C.CString("{\"error\": \"Movie bindings not initialized\"}")
	}

	movies, err := movieBindings.GetFavoriteMovies()
	if err != nil {
		return processError(err)
	}

	return returnJSON(movies)
}

//export Movies_SetFavoriteMovies
func Movies_SetFavoriteMovies(moviesJsonC *C.char) *C.char {
	if movieBindings == nil {
		return C.CString("{\"error\": \"Movie bindings not initialized\"}")
	}

	moviesJson := C.GoString(moviesJsonC)
	defer C.free(unsafe.Pointer(moviesJsonC))

	var movies []session.Movie
	if err := json.Unmarshal([]byte(moviesJson), &movies); err != nil {
		return C.CString("{\"error\": \"Failed to parse movies JSON\"}")
	}

	err := movieBindings.SetFavoriteMovies(movies)
	return processError(err)
}

//export Movies_AddToWatchlist
func Movies_AddToWatchlist(movieJsonC *C.char) *C.char {
	if movieBindings == nil {
		return C.CString("{\"error\": \"Movie bindings not initialized\"}")
	}

	movieJson := C.GoString(movieJsonC)
	defer C.free(unsafe.Pointer(movieJsonC))

	var movie session.Movie
	if err := json.Unmarshal([]byte(movieJson), &movie); err != nil {
		return C.CString("{\"error\": \"Failed to parse movie JSON\"}")
	}

	err := movieBindings.AddToWatchlist(movie)
	return processError(err)
}

//export Movies_RemoveFromWatchlist
func Movies_RemoveFromWatchlist(titleC *C.char) *C.char {
	if movieBindings == nil {
		return C.CString("{\"error\": \"Movie bindings not initialized\"}")
	}

	title := C.GoString(titleC)
	defer C.free(unsafe.Pointer(titleC))

	err := movieBindings.RemoveFromWatchlist(title)
	return processError(err)
}

//export Movies_GetWatchlist
func Movies_GetWatchlist() *C.char {
	if movieBindings == nil {
		return C.CString("{\"error\": \"Movie bindings not initialized\"}")
	}

	watchlist, err := movieBindings.GetWatchlist()
	if err != nil {
		return processError(err)
	}

	return returnJSON(watchlist)
}
