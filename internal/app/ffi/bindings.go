package ffi

/*
#include <stdlib.h>
#include <signal.h>

// Setup proper signal handling for SQLite operations
static void setup_safe_signal_handlers() {
    struct sigaction sa;
    sa.sa_handler = SIG_DFL;  // Default handler
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_ONSTACK;  // Critical flag for Go compatibility

    // Set up handlers for the signals that might be intercepted
    sigaction(SIGILL, &sa, NULL);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGABRT, &sa, NULL);
}

// Setup proper signal handling globally at init time
static void setup_global_signal_handlers() {
    struct sigaction sa;
    sa.sa_handler = SIG_DFL;  // Default handler
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_ONSTACK;  // Critical flag for Go compatibility

    // Set up handlers for all signals that might be intercepted
    sigaction(SIGILL, &sa, NULL);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGABRT, &sa, NULL);
    sigaction(SIGUSR1, &sa, NULL); // Signal 16 (SIGUSR1)
    sigaction(SIGUSR2, &sa, NULL);
    sigaction(SIGPIPE, &sa, NULL);
}
*/
import "C"
import (
	"context"
	"encoding/json"
	"fmt"
	"interestnaut/internal/app/db" // Add direct DB import
	"interestnaut/internal/app/models"
	"interestnaut/internal/app/recommendations"
	"interestnaut/internal/app/spotify"
	"interestnaut/internal/app/wikidata"  // Add direct Wikidata import
	"interestnaut/internal/app/wikipedia" // Add direct Wikipedia import
	"log"
	"os"
	"path/filepath"
	"sync"
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
	dbMutex        sync.Mutex // Mutex to protect database operations
)

// User agent to use for API requests
const userAgent = "Interestnaut/1.0"

// init function for the FFI package. This will run when the dylib is loaded.
func init() {
	// Set up global signal handlers
	C.setup_global_signal_handlers()
	
	log.Println("FFI package init() called - dylib loaded.")
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
		
		// Initialize the recommendation queue on a separate thread
		initRecommendationQueue()
		
		ffiInitialized = true
	}

	// Return success message
	return C.CString("{\"status\": \"FFI bridge initialized successfully\"}")
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
//func EventBusInit() C.int64_t {
//	return C.int64_t(eventbus.StartEventServer())
//}

//export EventBusShutdown
//func EventBusShutdown() {
//	// No-op for now, but symbol required for FFI contract
//}

func ensureRecommendationServiceInitialized() bool {
	dbMutex.Lock()
	defer dbMutex.Unlock()

	if recommendationService != nil {
		return true
	}

	if db.DB == nil {
		log.Println("Cannot initialize recommendation service: database not initialized")
		return false
	}

	// Initialize Wikidata client
	wikidataClient := wikidata.NewClient("interestnaut")


	// Initialize Wikipedia client
	wikipediaClient = wikipedia.NewClient("interestnaut")

	// Create and initialize the recommendation service
	recommendationService = recommendations.NewService(db.DB, wikidataClient, wikipediaClient)
	log.Println("Recommendation service initialized")
	
	// Initialize the recommendation queue on a separate thread
	initRecommendationQueue()
	
	return true
}

func initRecommendationQueue() {
	if recommendationService != nil {
		recommendations.InitRecommendationQueue(recommendationService)
		log.Println("Recommendation queue initialized in FFI bindings")
	} else {
		log.Println("Cannot initialize recommendation queue: service not initialized")
	}
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

// initSafeSignalHandlers ensures signals are properly handled for SQLite operations
func initSafeSignalHandlers() {
	// Set up signal handlers with SA_ONSTACK flag
	C.setup_safe_signal_handlers()
}

// Recommendation FFI Functions

//export Recommendation_FindAndSaveSuggestion
func Recommendation_FindAndSaveSuggestion(rawQueryC *C.char, mediaTypeC *C.char, botReasoningC *C.char) *C.char {
	// Ensure service is initialized (this will also initialize the queue)
	if !ensureRecommendationServiceInitialized() {
		return returnJSON(map[string]string{"error": "Recommendation service not initialized"})
	}

	// Safe conversion of C strings to Go strings - this is fast and non-blocking
	rawQuery := C.GoString(rawQueryC)
	mediaType := C.GoString(mediaTypeC)
	botReasoning := C.GoString(botReasoningC)

	// Enqueue the request - this is non-blocking and safe to call from any thread
	requestID := recommendations.EnqueueRecommendationRequest(rawQuery, mediaType, botReasoning)
	if requestID == "" {
		return returnJSON(map[string]string{"error": "Failed to enqueue recommendation request (queue full)"})
	}

	// Wait for the result with a reasonable timeout (30 seconds)
	result, err := recommendations.GetRecommendationResult(requestID, 30000)
	if err != nil {
		return processError(err)
	}
	
	// If no result was returned within the timeout
	if result == nil {
		return returnJSON(map[string]string{"error": "Timed out waiting for recommendation processing"})
	}
	
	// Return the result as JSON
	return returnJSON(result)
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
		if !models.IsValidStatus(statusFilterStr) {
			return returnJSON(map[string]string{"error": "Invalid status filter: " + statusFilterStr})
		}
		statusFilter = models.SuggestionStatus(statusFilterStr)
	}

	// Set up proper signal handling before DB operations
	dbMutex.Lock()
	initSafeSignalHandlers()
	defer dbMutex.Unlock()

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

	if !models.IsValidStatus(statusStr) {
		return returnJSON(map[string]string{"error": "Invalid status value: " + statusStr})
	}

	// Set up proper signal handling before DB operations
	dbMutex.Lock()
	initSafeSignalHandlers()
	defer dbMutex.Unlock()

	status := models.SuggestionStatus(statusStr)
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

	// Set up proper signal handling before DB operations
	dbMutex.Lock()
	initSafeSignalHandlers()
	defer dbMutex.Unlock()

	count, err := recommendationService.GetPendingSuggestionsCount(context.Background(), mediaType)
	if err != nil {
		return processError(err)
	}
	return returnJSON(map[string]int{"count": count})
}

//export Recommendation_InitQueue
func Recommendation_InitQueue() *C.char {
	if !ensureRecommendationServiceInitialized() {
		return returnJSON(map[string]string{"error": "Recommendation service not initialized"})
	}
	
	// The queue should already be initialized by ensureRecommendationServiceInitialized,
	// but we'll call it explicitly here to be safe
	initRecommendationQueue()
	
	return returnJSON(map[string]string{"status": "success", "message": "Recommendation queue initialized"})
}
