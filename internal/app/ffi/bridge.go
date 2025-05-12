package ffi

// This file provides the bridge between Go and Dart using CGO

/*
#cgo CFLAGS: -x objective-c
#cgo LDFLAGS: -framework Foundation -framework Security
#include <stdlib.h>
#include <signal.h>
#include <string.h>
#include <stdio.h>
#include <pthread.h>
#include <sched.h>

// Signal handling approach - properly handle signals at process level
static void interestnaut_configureSignals() {
    // Ignore SIGPIPE which commonly occurs with network/audio operations
    signal(SIGPIPE, SIG_IGN);
    
    // For SIGUSR1 and SIGUSR2, we must use sigaction with SA_ONSTACK
    // to ensure proper coordination with Go's runtime signal handling
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = SIG_IGN;  // Ignore the signal
    sa.sa_flags = SA_ONSTACK; // Important: use the signal stack!
    
    // Apply to SIGUSR1 (signal 16)
    sigaction(SIGUSR1, &sa, NULL);
    // Apply to SIGUSR2 (signal 17)
    sigaction(SIGUSR2, &sa, NULL);
    
    fprintf(stderr, "Configured app to ignore SIGPIPE and properly handle SIGUSR signals\n");
}

// Additional safeguards for GC stability
static void set_thread_priority_high() {
    #ifdef __APPLE__
    // On macOS, use sched_param to set high priority
    struct sched_param param;
    param.sched_priority = sched_get_priority_max(SCHED_RR);
    pthread_setschedparam(pthread_self(), SCHED_RR, &param);
    fprintf(stderr, "Set thread priority to high for FFI thread\n");
    #endif
}
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
	
	// Configure signal handling to avoid conflicts with Flutter
	// This must happen as early as possible, before any goroutines are created
	C.interestnaut_configureSignals()
	
	// We can't fully initialize here if we need CentralManager passed from a main context.
	// However, this confirms the package level init is working.
}

//export InitializeFFIBridge
func InitializeFFIBridge() *C.char {
	log.Println("InitializeFFIBridge called from Dart")

	// Only initialize if not already done
	if !ffiInitialized {
		// Create a central manager for the FFI context
		ctx := context.Background()
		cm, err := session.NewCentralManager(ctx, session.DefaultUserID)
		if err != nil {
			log.Printf("Failed to create central manager in InitializeFFIBridge: %v", err)
			return C.CString("{\"error\": \"Failed to initialize central manager\"}")
		}

		// Initialize all the bindings
		Initialize(cm)
	}

	// Check if music bindings were properly initialized
	if musicBindings == nil {
		return C.CString("{\"error\": \"Music bindings initialization failed\"}")
	}

	return C.CString("{\"status\": \"success\"}")
}

// Initialize initializes all bindings for FFI use
func Initialize(cm session.CentralManager) {
	if ffiInitialized {
		log.Println("FFI bindings already initialized, skipping.")
		return
	}
	log.Println("FFI bridge Initialize() CALLED")

	// Commenting out high thread priority since we're no longer polling
	// This was primarily needed for continuous polling operations
	// If no performance issues are observed, this can be permanently removed
	// C.set_thread_priority_high()
	
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
