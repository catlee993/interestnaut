package ffi

// This file provides the bridge between Go and Dart using CGO

/*
#include <stdlib.h>
*/
import "C"

import (
	"context"
	"encoding/json"
	"interestnaut/internal/app/bindings"
	"interestnaut/internal/app/session"
	"log"
	"os"
	"sync"
	"time"
	"unsafe"
)

// Global instances of our bindings to avoid recreating them
var (
	authBindings     *bindings.Auth
	bookBindings     *bindings.Books
	gameBindings     *bindings.Games
	movieBindings    *bindings.Movies
	musicBindings    *bindings.Music
	settingsBindings *bindings.Settings
	tvBindings       *bindings.TVShows

	// Central manager for all content
	centralManager session.CentralManager

	// Exit handling
	exitChan      = make(chan struct{})
	exitWaitGroup sync.WaitGroup

	ffiInitialized bool // Flag to ensure Initialize is called only once
)

// init function for the FFI package. This will run when the dylib is loaded.
func init() {
	log.Println("FFI package init() called - dylib loaded.")
	// We can't fully initialize here if we need CentralManager passed from a main context.
	// However, this confirms the package level init is working.
}

// Initialize initializes all bindings for FFI use
func Initialize(cm session.CentralManager) {
	if ffiInitialized {
		log.Println("FFI bindings already initialized, skipping.")
		return
	}
	log.Println("FFI bridge Initialize() CALLED")
	centralManager = cm
	if centralManager == nil {
		log.Println("CRITICAL: CentralManager is nil in Initialize()")
		// Handle this error appropriately, maybe panic or return an error
		// For now, just log and continue to see other errors
	}

	authBindings = &bindings.Auth{}
	var err error

	bookBindings, err = bindings.NewBooks(context.Background(), cm)
	if err != nil {
		log.Printf("ERROR initializing book bindings: %v", err)
	}

	gameBindings, err = bindings.NewGames(context.Background(), cm)
	if err != nil {
		log.Printf("ERROR initializing game bindings: %v", err)
	}

	movieBindings, err = bindings.NewMovieBinder(context.Background(), cm)
	if err != nil {
		log.Printf("ERROR initializing movie bindings: %v", err)
	}

	log.Println("Attempting to initialize musicBindings...")
	musicBindings = bindings.NewMusicBinder(context.Background(), cm, "3bb48a30577342869a9ffcb176dee7d2")
	if musicBindings == nil {
		log.Println("CRITICAL: musicBindings is NIL after NewMusicBinder call!")
	} else {
		log.Println("SUCCESS: musicBindings initialized.")
	}

	settingsBindings = &bindings.Settings{ContentManager: cm}
	tvBindings, err = bindings.NewTVShowBinder(context.Background(), cm)
	if err != nil {
		log.Printf("ERROR initializing TV bindings: %v", err)
	}

	log.Println("FFI bindings initialization process complete.")
	ffiInitialized = true
	startExitWatcher()
}

// Start a goroutine to watch for exit signals
func startExitWatcher() {
	exitWaitGroup.Add(1)
	go func() {
		defer exitWaitGroup.Done()
		<-exitChan
		log.Println("Exit signal received, shutting down Go process")

		// Allow some time for cleanup
		time.Sleep(time.Second)
		os.Exit(0)
	}()
}

// Helper function to handle C string return values
func returnCString(value string) *C.char {
	return C.CString(value)
}

// Helper function to handle JSON return values
func returnJSON(value interface{}) *C.char {
	data, err := json.Marshal(value)
	if err != nil {
		log.Printf("ERROR marshaling JSON: %v", err)
		return C.CString("{\"error\": \"Failed to marshal JSON\"}")
	}
	return C.CString(string(data))
}

// Helper function to process errors
func processError(err error) *C.char {
	if err != nil {
		errJSON := map[string]string{"error": err.Error()}
		data, _ := json.Marshal(errJSON)
		return C.CString(string(data))
	}
	return C.CString("{}")
}

//export FreeString
func FreeString(str *C.char) {
	C.free(unsafe.Pointer(str))
}

//export SignalShutdown
func SignalShutdown() {
	log.Println("Shutdown signal received from Flutter")
	close(exitChan)

	// Wait for exit watcher to complete (with timeout)
	waitChan := make(chan struct{})
	go func() {
		exitWaitGroup.Wait()
		close(waitChan)
	}()

	select {
	case <-waitChan:
		// Normal exit
	case <-time.After(3 * time.Second):
		// Forced exit after timeout
		log.Println("Exit timeout, forcing termination")
		os.Exit(0)
	}
}
