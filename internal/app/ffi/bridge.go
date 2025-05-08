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
)

// Initialize initializes all bindings for FFI use
func Initialize(cm session.CentralManager) {
	log.Println("Initializing FFI bindings")
	centralManager = cm

	// Create instances of all bindings
	authBindings = &bindings.Auth{}

	var err error

	// Create Books bindings
	bookBindings, err = bindings.NewBooks(context.Background(), cm)
	if err != nil {
		log.Printf("ERROR initializing book bindings: %v", err)
	}

	// Create Games bindings
	gameBindings, err = bindings.NewGames(context.Background(), cm)
	if err != nil {
		log.Printf("ERROR initializing game bindings: %v", err)
	}

	// Create Movies bindings
	movieBindings, err = bindings.NewMovieBinder(context.Background(), cm)
	if err != nil {
		log.Printf("ERROR initializing movie bindings: %v", err)
	}

	// Create Music bindings (using empty client ID for now)
	musicBindings = bindings.NewMusicBinder(context.Background(), cm, "")

	// Create Settings bindings
	settingsBindings = &bindings.Settings{
		ContentManager: cm,
	}

	// Create TV bindings
	tvBindings, err = bindings.NewTVShowBinder(context.Background(), cm)
	if err != nil {
		log.Printf("ERROR initializing TV bindings: %v", err)
	}

	log.Println("FFI bindings initialization complete")

	// Start the exit watcher to handle graceful shutdown
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
