package ffi

/*
#include <stdlib.h>
*/
import "C"
import (
	"context"
	"encoding/json"
	"interestnaut/internal/app/bindings"
	"interestnaut/internal/app/eventbus"
	"interestnaut/internal/app/session"
	"interestnaut/internal/app/spotify"
	"log"
	"os"
	"sync"
	"time"
	"unsafe"
)

// Global instances of our bindings to avoid recreating them
var (
	musicBindings *bindings.Music

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
	eventbus.StartEventServer()
}

//export InitializeFFIBridge
func InitializeFFIBridge() *C.char {
	log.Println("InitializeFFIBridge called from Dart")

	// Return success message
	return C.CString("{\"status\": \"FFI bridge initialized successfully\"}")
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

	log.Println("Attempting to initialize musicBindings...")
	musicBindings = bindings.NewMusicBinder(context.Background(), cm, "3bb48a30577342869a9ffcb176dee7d2")
	if musicBindings == nil {
		log.Println("CRITICAL: musicBindings is NIL after NewMusicBinder call!")
	} else {
		log.Println("SUCCESS: musicBindings initialized.")
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
func FreeString(s *C.char) {
	if s != nil {
		C.free(unsafe.Pointer(s))
	}
}

// FFI glue for Flutter event bus contract
//
//export EventBusInit
func EventBusInit() C.int64_t {
	return C.int64_t(eventbus.StartEventServer())
}

//export EventBus_Shutdown
func EventBusShutdown() {
	// No-op for now, but symbol required for FFI contract
}

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

//export Music_InitiateSpotifyAuth
func Music_InitiateSpotifyAuth(port C.int) *C.char {
	var result *C.char

	if !ensureMusicBindingsInitialized() {
		result = C.CString("{\"error\": \"Failed to initialize music bindings\"}")
		return result
	}

	// Call the simplified version that just opens the browser, passing the port
	err := musicBindings.InitiateSpotifyAuth(int(port))
	if err != nil {
		log.Printf("Music_InitiateSpotifyAuth failed: %v", err)
		errorJson, _ := json.Marshal(map[string]interface{}{
			"error": err.Error(),
		})
		result = C.CString(string(errorJson))
		return result
	}

	if pid := os.Getpid(); pid > 0 {
		log.Printf("Spotify auth browser opened with port %d. PID is: %d", int(port), pid)
	}

	// Return the auth status and indicate that the browser was opened
	// This is critical for Flutter to know if it should handle the callback
	authStatus := make(map[string]interface{})

	// Add a browserOpened flag to let Flutter know the browser was opened
	authStatus["browserOpened"] = true

	// Add port number to response so Flutter knows what port was used
	authStatus["port"] = int(port)

	// Add the code verifier so Flutter can use it for token exchange
	codeVerifier := spotify.GetCodeVerifier()
	log.Printf("DEBUG: Code verifier in Music_InitiateSpotifyAuth: '%s'", codeVerifier)
	authStatus["codeVerifier"] = codeVerifier

	jsonBytes, _ := json.Marshal(authStatus)
	result = C.CString(string(jsonBytes))

	return result
}
