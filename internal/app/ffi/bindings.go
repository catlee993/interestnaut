package ffi

/*
#include <stdlib.h>
*/
import "C"
import (
	"context"
	"encoding/json"
	"interestnaut/internal/app/bindings" // Only for Music, should be refactored later
	"interestnaut/internal/app/db"       // Add direct DB import
	"interestnaut/internal/app/eventbus"
	"interestnaut/internal/app/models"
	"interestnaut/internal/app/recommendations"
	"interestnaut/internal/app/session"
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
	musicBindings         *bindings.Music
	recommendationService *recommendations.Service // Using recommendations.Service

	// Legacy central manager - deprecated but kept for musicBindings temporarily
	centralManager session.CentralManager

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
func InitializeFFIBridge() *C.char {
	log.Println("InitializeFFIBridge called from Dart")

	// Create and initialize services here rather than waiting for Initialize call
	if !ffiInitialized {
		// Get appropriate database file path
		homeDir, err := os.UserHomeDir()
		if err != nil {
			log.Printf("CRITICAL: Failed to get user home directory: %v", err)
			return C.CString("{\"error\": \"Failed to get user home directory: " + err.Error() + "\"}")
		}
		appDataDir := filepath.Join(homeDir, ".interestnaut")

		// Create app data directory if it doesn't exist
		if err := os.MkdirAll(appDataDir, 0755); err != nil {
			log.Printf("CRITICAL: Failed to create app data directory: %v", err)
			return C.CString("{\"error\": \"Failed to create app directory: " + err.Error() + "\"}")
		}

		dbPath := filepath.Join(appDataDir, "interestnaut.db")
		log.Printf("Using database path: %s", dbPath)

		// Initialize DB
		err = db.InitDB(dbPath)
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

// Initialize is kept for backward compatibility but redirects to new initialization
func Initialize(cm session.CentralManager) {
	if ffiInitialized {
		log.Println("FFI bindings already initialized, skipping.")
		return
	}

	log.Println("WARNING: Legacy Initialize(cm) called, but we're using direct service initialization")

	// Save the central manager for music only
	centralManager = cm

	// Try to initialize the recommendation service
	if db.DB == nil {
		// Get appropriate database file path
		homeDir, err := os.UserHomeDir()
		if err != nil {
			log.Printf("CRITICAL: Failed to get user home directory: %v", err)
			return
		}
		appDataDir := filepath.Join(homeDir, ".interestnaut")

		// Create app data directory if it doesn't exist
		if err := os.MkdirAll(appDataDir, 0755); err != nil {
			log.Printf("CRITICAL: Failed to create app data directory: %v", err)
			return
		}

		dbPath := filepath.Join(appDataDir, "interestnaut.db")
		log.Printf("Using database path: %s", dbPath)

		err = db.InitDB(dbPath)
		if err != nil {
			log.Printf("CRITICAL: Failed to initialize SQLite client: %v", err)
			return
		}
	}

	if wikidataClient == nil {
		wikidataClient = wikidata.NewClient(userAgent)
	}

	if wikipediaClient == nil {
		wikipediaClient = wikipedia.NewClient(userAgent)
	}

	recommendationService = recommendations.NewService(db.DB, wikidataClient, wikipediaClient)
	if recommendationService == nil {
		log.Println("CRITICAL: recommendationService is NIL after NewService call!")
	} else {
		log.Println("SUCCESS: recommendationService initialized through compatibility layer.")
	}

	// Keep initializing music for now
	log.Println("Attempting to initialize musicBindings...")
	if cm != nil {
		musicBindings = bindings.NewMusicBinder(context.Background(), cm, "3bb48a30577342869a9ffcb176dee7d2")
		if musicBindings == nil {
			log.Println("CRITICAL: musicBindings is NIL after NewMusicBinder call!")
		} else {
			log.Println("SUCCESS: musicBindings initialized.")
		}
	} else {
		log.Println("WARNING: cm is nil, skipping musicBindings initialization")
	}

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

//export EventBusShutdown
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

	// Return success message
	result = C.CString("{\"status\": \"Spotify auth initiated successfully\"}")
	return result
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
