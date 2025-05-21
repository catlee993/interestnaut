package ffi

/*
#include <stdlib.h>
*/
import "C"
import (
	"context"
	"encoding/json"
	"fmt"
	"interestnaut/internal/app/db" // Add direct DB import
	"interestnaut/internal/app/eventbus"
	"interestnaut/internal/app/models"
	"interestnaut/internal/app/recommendations"
	"interestnaut/internal/app/spotify"
	"interestnaut/internal/app/wikidata"  // Add direct Wikidata import
	"interestnaut/internal/app/wikipedia" // Add direct Wikipedia import
	"log"
	"os"
	"path/filepath"
	"sync"
	"time"
	"unsafe"
)

// Global instances of our bindings to avoid recreating them
var (
	recommendationService *recommendations.Service // Using recommendations.Service

	// Direct service dependencies
	wikidataClient  *wikidata.Client
	wikipediaClient *wikipedia.Client

	// Exit handling
	exitChan      = make(chan struct{})
	exitWaitGroup sync.WaitGroup

	ffiInitialized bool // Flag to ensure Initialize is called only once
)

// User agent to use for API requests
const userAgent = "Interestnaut/1.0"

// init function for the FFI package. This will run when the dylib is loaded.
func init() {
	log.Println("FFI package init() called - dylib loaded.")
	eventbus.StartEventServer()
}

//export InitializeFFIBridge
func InitializeFFIBridge(storagePathC *C.char) *C.char {
	log.Println("InitializeFFIBridge called from Dart")

	// Create and initialize services here rather than waiting for Initialize call
	if !ffiInitialized {
		// Get the storage path from Flutter instead of using a hardcoded path
		storagePath := C.GoString(storagePathC)
		if storagePath == "" {
			// Fallback to default path if no path provided
			homeDir, err := os.UserHomeDir()
			if err != nil {
				log.Printf("CRITICAL: Failed to get user home directory: %v", err)
				return C.CString("{\"error\": \"Failed to get user home directory: " + err.Error() + "\"}")
			}
			storagePath = filepath.Join(homeDir, ".interestnaut")
			log.Printf("Using default storage path: %s", storagePath)
		} else {
			log.Printf("Using Flutter-provided storage path: %s", storagePath)
		}

		// Create app data directory if it doesn't exist
		if err := os.MkdirAll(storagePath, 0755); err != nil {
			log.Printf("CRITICAL: Failed to create app storage directory: %v", err)
			return C.CString("{\"error\": \"Failed to create app directory: " + err.Error() + "\"}")
		}

		dbPath := filepath.Join(storagePath, "interestnaut.db")
		log.Printf("Using database path: %s", dbPath)

		// Initialize DB
		err := db.InitDB(dbPath)
		if err != nil {
			log.Printf("CRITICAL: Failed to initialize database: %v", err)
			return C.CString("{\"error\": \"Failed to initialize SQLite: " + err.Error() + "\"}")
		}

		// Initialize API clients with proper user agent
		wikidataClient = wikidata.NewClient(userAgent)
		wikipediaClient = wikipedia.NewClient(userAgent)

		// Initialize recommendation service directly without central manager
		// using the global db.DB instance
		recommendationService = recommendations.NewService(db.DB, wikidataClient, wikipediaClient)
		if recommendationService == nil {
			log.Println("CRITICAL: recommendationService is NIL after NewService call!")
			return C.CString("{\"error\": \"Failed to initialize recommendation service\"}")
		}
		log.Println("SUCCESS: recommendationService initialized directly.")

		ffiInitialized = true
		startExitWatcher()
	}

	// Return success message
	return C.CString("{\"status\": \"FFI bridge initialized successfully\"}")
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

//export EventBusShutdown
func EventBusShutdown() {
	// No-op for now, but symbol required for FFI contract
}

func ensureRecommendationServiceInitialized() bool {
	if recommendationService != nil {
		return true
	}
	log.Println("Recommendation service not initialized. Creating it now...")

	// Initialize core services if needed
	if db.DB == nil {
		// Get appropriate database file path
		homeDir, err := os.UserHomeDir()
		if err != nil {
			log.Printf("CRITICAL: Failed to get user home directory: %v", err)
			return false
		}
		appDataDir := filepath.Join(homeDir, ".interestnaut")

		// Create app data directory if it doesn't exist
		if err := os.MkdirAll(appDataDir, 0755); err != nil {
			log.Printf("CRITICAL: Failed to create app data directory: %v", err)
			return false
		}

		dbPath := filepath.Join(appDataDir, "interestnaut.db")
		log.Printf("Using database path: %s", dbPath)

		err = db.InitDB(dbPath)
		if err != nil {
			log.Printf("CRITICAL: Failed to initialize SQLite client: %v", err)
			return false
		}
	}

	if wikidataClient == nil {
		wikidataClient = wikidata.NewClient(userAgent)
	}

	if wikipediaClient == nil {
		wikipediaClient = wikipedia.NewClient(userAgent)
	}

	recommendationService = recommendations.NewService(db.DB, wikidataClient, wikipediaClient)
	if recommendationService != nil {
		log.Println("SUCCESS: recommendationService initialized on-demand.")
		return true
	}

	log.Println("CRITICAL: Failed to initialize recommendation service on-demand.")
	return false
}

//export Music_InitiateSpotifyAuth
func Music_InitiateSpotifyAuth(port C.int) *C.char {
	var result *C.char

	// Call the simplified version that just opens the browser, passing the port
	err := initiateSpotifyAuth(int(port))
	if err != nil {
		log.Printf("Music_InitiateSpotifyAuth failed: %v", err)
		errorJson, _ := json.Marshal(map[string]interface{}{
			"error": err.Error(),
		})
		result = C.CString(string(errorJson))
		return result
	}

	// Return success message
	result = C.CString("{\"status\": \"Spotify auth initiated successfully\"}")
	return result
}

func initiateSpotifyAuth(port int) error {
	log.Printf("Explicitly initiating Spotify authentication flow with port %d", port)

	// Validate that the port is one of the registered ports
	if !spotify.IsRegisteredPort(port) {
		return fmt.Errorf("port %d is not registered in the Spotify Developer Dashboard", port)
	}

	// Open the browser with the auth URL but don't set up a server or handle callback
	err := spotify.OpenSpotifyAuthBrowser(context.Background(), port)
	if err != nil {
		log.Printf("ERROR: Failed to open Spotify auth browser: %v", err)
		return err
	}

	log.Println("Browser opened with Spotify auth URL - Flutter will handle the callback")

	// No need to return anything, the code verifier is stored in the spotify package
	return nil
}

// Recommendation FFI Functions

//export Recommendation_FindAndSaveSuggestion
func Recommendation_FindAndSaveSuggestion(rawQueryC *C.char, mediaTypeC *C.char, botReasoningC *C.char) *C.char {
	if !ensureRecommendationServiceInitialized() {
		return returnJSON(map[string]string{"error": "Recommendation service not initialized"})
	}

	rawQuery := C.GoString(rawQueryC)
	mediaType := C.GoString(mediaTypeC)
	botReasoning := C.GoString(botReasoningC)

	suggestion, err := recommendationService.FindAndSaveSuggestion(context.Background(), rawQuery, mediaType, botReasoning)
	if err != nil {
		return processError(err)
	}
	return returnJSON(suggestion)
}

//export Recommendation_GetAllSuggestions
func Recommendation_GetAllSuggestions(mediaTypeC *C.char, statusFilterC *C.char, limitC C.int, offsetC C.int) *C.char {
	if !ensureRecommendationServiceInitialized() {
		return returnJSON(map[string]string{"error": "Recommendation service not initialized"})
	}

	mediaType := C.GoString(mediaTypeC)
	statusFilterStr := C.GoString(statusFilterC)
	limit := int(limitC)
	offset := int(offsetC)

	var statusFilter models.SuggestionStatus
	if statusFilterStr != "" {
		statusFilter = models.SuggestionStatus(statusFilterStr)
		if !models.IsValidStatus(statusFilterStr) {
			return returnJSON(map[string]string{"error": "Invalid status filter value: " + statusFilterStr})
		}
	}

	suggestions, err := recommendationService.GetAllSuggestions(context.Background(), mediaType, statusFilter, limit, offset)
	if err != nil {
		return processError(err)
	}
	return returnJSON(suggestions)
}

//export Recommendation_UpdateSuggestionStatus
func Recommendation_UpdateSuggestionStatus(suggestionIDC *C.char, statusC *C.char) *C.char {
	if !ensureRecommendationServiceInitialized() {
		return returnJSON(map[string]string{"error": "Recommendation service not initialized"})
	}

	suggestionID := C.GoString(suggestionIDC)
	statusStr := C.GoString(statusC)

	status := models.SuggestionStatus(statusStr)
	if !models.IsValidStatus(statusStr) {
		return returnJSON(map[string]string{"error": "Invalid status value: " + statusStr})
	}

	err := recommendationService.UpdateSuggestionStatus(context.Background(), suggestionID, status)
	if err != nil {
		return processError(err)
	}
	return returnJSON(map[string]string{"status": "success"})
}

//export Recommendation_GetPendingSuggestionsCount
func Recommendation_GetPendingSuggestionsCount(mediaTypeC *C.char) *C.char {
	if !ensureRecommendationServiceInitialized() {
		return returnJSON(map[string]string{"error": "Recommendation service not initialized"})
	}

	mediaType := C.GoString(mediaTypeC)

	count, err := recommendationService.GetPendingSuggestionsCount(context.Background(), mediaType)
	if err != nil {
		return processError(err)
	}
	return returnJSON(map[string]int{"count": count})
}
