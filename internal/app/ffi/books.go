package ffi

/*
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"interestnaut/internal/app/session"
	"log"
	"unsafe"
)

//export Books_SetFavoriteBooks
func Books_SetFavoriteBooks(booksJsonC *C.char) *C.char {
	if bookBindings == nil {
		return C.CString("{\"error\": \"Book bindings not initialized\"}")
	}

	booksJson := C.GoString(booksJsonC)
	defer C.free(unsafe.Pointer(booksJsonC))

	var books []session.Book
	err := json.Unmarshal([]byte(booksJson), &books)
	if err != nil {
		return processError(err)
	}

	err = bookBindings.SetFavoriteBooks(books)
	return processError(err)
}

//export Books_GetFavoriteBooks
func Books_GetFavoriteBooks() *C.char {
	if bookBindings == nil {
		return C.CString("{\"error\": \"Book bindings not initialized\"}")
	}

	books, err := bookBindings.GetFavoriteBooks()
	if err != nil {
		return processError(err)
	}

	return returnJSON(books)
}

//export Books_AddToReadList
func Books_AddToReadList(bookJsonC *C.char) *C.char {
	if bookBindings == nil {
		return C.CString("{\"error\": \"Book bindings not initialized\"}")
	}

	bookJson := C.GoString(bookJsonC)
	defer C.free(unsafe.Pointer(bookJsonC))

	var book session.Book
	err := json.Unmarshal([]byte(bookJson), &book)
	if err != nil {
		return processError(err)
	}

	err = bookBindings.AddToReadList(book)
	return processError(err)
}

//export Books_RemoveFromReadList
func Books_RemoveFromReadList(titleC, authorC *C.char) *C.char {
	if bookBindings == nil {
		return C.CString("{\"error\": \"Book bindings not initialized\"}")
	}

	title := C.GoString(titleC)
	author := C.GoString(authorC)
	defer C.free(unsafe.Pointer(titleC))
	defer C.free(unsafe.Pointer(authorC))

	err := bookBindings.RemoveFromReadList(title, author)
	return processError(err)
}

//export Books_GetReadList
func Books_GetReadList() *C.char {
	if bookBindings == nil {
		return C.CString("{\"error\": \"Book bindings not initialized\"}")
	}

	books, err := bookBindings.GetReadList()
	if err != nil {
		return processError(err)
	}

	return returnJSON(books)
}

//export Books_SearchBooks
func Books_SearchBooks(queryC *C.char) *C.char {
	if bookBindings == nil {
		return C.CString("{\"error\": \"Book bindings not initialized\"}")
	}

	query := C.GoString(queryC)
	defer C.free(unsafe.Pointer(queryC))

	books, err := bookBindings.SearchBooks(query)
	if err != nil {
		return processError(err)
	}

	return returnJSON(books)
}

//export Books_GetBookDetails
func Books_GetBookDetails(workKeyC *C.char) *C.char {
	if bookBindings == nil {
		return C.CString("{\"error\": \"Book bindings not initialized\"}")
	}

	workKey := C.GoString(workKeyC)
	defer C.free(unsafe.Pointer(workKeyC))

	book, err := bookBindings.GetBookDetails(workKey)
	if err != nil {
		return processError(err)
	}

	return returnJSON(book)
}

//export Books_GetBookSuggestion
func Books_GetBookSuggestion() *C.char {
	if bookBindings == nil {
		return C.CString("{\"error\": \"Book bindings not initialized\"}")
	}

	suggestion, err := bookBindings.GetBookSuggestion()
	if err != nil {
		log.Printf("ERROR getting book suggestion: %v", err)
		return processError(err)
	}

	return returnJSON(suggestion)
}

//export Books_ProvideSuggestionFeedback
func Books_ProvideSuggestionFeedback(outcomeC, titleC, authorC *C.char) *C.char {
	if bookBindings == nil {
		return C.CString("{\"error\": \"Book bindings not initialized\"}")
	}

	outcomeStr := C.GoString(outcomeC)
	title := C.GoString(titleC)
	author := C.GoString(authorC)
	defer C.free(unsafe.Pointer(outcomeC))
	defer C.free(unsafe.Pointer(titleC))
	defer C.free(unsafe.Pointer(authorC))

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

	err := bookBindings.ProvideSuggestionFeedback(outcome, title, author)
	return processError(err)
}

//export Books_RefreshLLMClients
func Books_RefreshLLMClients() *C.char {
	if bookBindings == nil {
		return C.CString("{\"error\": \"Book bindings not initialized\"}")
	}

	bookBindings.RefreshLLMClients()
	return C.CString("{}")
}
