package ffi

/*
#include <stdlib.h>
#include <signal.h>

// We need to modify our signal handling approach to avoid conflicts with Go runtime
// Instead of handling signals ourselves, we'll use Go's signal handling

// This is a no-op function that will be called from Go
static void setup_safe_signal_handlers() {
    // Do nothing - Go will handle signals properly
}

// This is a no-op function that will be called from Go
static void setup_global_signal_handlers() {
    // Do nothing - Go will handle signals properly
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

	ffiInitialized bool       // Flag to ensure Initialize is called only once
	dbMutex        sync.Mutex // Mutex to protect database operations
)

// User agent to use for API requests
const userAgent = "Interestnaut/1.0"

// init function for the FFI package. This will run when the dylib is loaded.
func init() {
	// Let Go runtime handle signals instead of setting up custom handlers
	// C.setup_global_signal_handlers() - removed to prevent signal conflicts

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

		// Initialize API clients with proper user agent
		wikidataClient = wikidata.NewClient(userAgent)
		wikipediaClient = wikipedia.NewClient(userAgent)

		// Initialize the recommendation queue FIRST, before any DB operations
		// This ensures the worker thread is locked and ready for signal-sensitive operations
		initRecommendationQueue()

		// Create a channel to receive the DB initialization result
		dbInitCh := make(chan error, 1)

		// Enqueue a special request to initialize the database on the locked worker thread
		initRequestID := recommendations.EnqueueDBInitRequest(dbPath, dbInitCh)

		// DO NOT WAIT for initialization to complete - return immediately with the request ID
		// The Flutter app will need to poll for completion using Recommendation_GetInitResult
		ffiInitialized = true

		return returnJSON(map[string]interface{}{
			"status":     "initializing",
			"message":    "FFI bridge initialization started, database setup in progress",
			"request_id": initRequestID,
		})
	}

	// Return success message if already initialized
	return C.CString("{\"status\": \"already_initialized\", \"message\": \"FFI bridge was already initialized\"}")
}

//export Recommendation_GetInitResult
func Recommendation_GetInitResult(requestIDC *C.char) *C.char {
	requestID := C.GoString(requestIDC)

	// Get the DB initialization result with a non-blocking check (timeoutMs=0)
	completed, err := recommendations.GetDBInitResult(requestID, 0)

	// If there was an error during initialization
	if err != nil {
		// If the error is that the initialization is still in progress,
		// return a "pending" status
		if err.Error() == "request is still processing" {
			return returnJSON(map[string]string{
				"request_id": requestID,
				"status":     "pending",
				"message":    "Database initialization is still in progress",
			})
		}

		// Otherwise, there was a real error during initialization
		return returnJSON(map[string]string{
			"status":  "error",
			"message": fmt.Sprintf("Database initialization failed: %v", err),
		})
	}

	// If initialization completed successfully
	if completed {
		// Now that database is initialized, create the recommendation service
		// and update the worker with the service
		if recommendationService == nil {
			recommendationService = createRecommendationService()
			if recommendationService != nil {
				// Update the worker to use this service for all future operations
				recommendations.UpdateWorkerService(recommendationService)
			} else {
				return returnJSON(map[string]string{
					"status":  "error",
					"message": "Database initialized but failed to create recommendation service",
				})
			}
		}

		return returnJSON(map[string]string{
			"status":  "ready",
			"message": "Database initialized successfully and service is ready",
		})
	}

	// This should never happen, but just in case
	return returnJSON(map[string]string{
		"status":  "unknown",
		"message": "Unknown state in database initialization",
	})
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

	// Initialize Wikipedia client
	if wikipediaClient == nil {
		wikipediaClient = wikipedia.NewClient("interestnaut")
	}

	// Create and initialize the recommendation service
	recommendationService = createRecommendationService()
	log.Println("Recommendation service initialized")

	// Initialize the recommendation queue on a separate thread
	initRecommendationQueue()

	return true
}

// initRecommendationQueue sets up the recommendation worker queue
func initRecommendationQueue() {
	log.Println("Initializing recommendation queue...")

	// Initialize the recommendation queue
	// This queue uses a worker thread that's permanently locked with runtime.LockOSThread()
	// to ensure all signal-sensitive operations (HTTP, JSON, SQLite) run on a prepared thread
	recommendations.InitRecommendationQueue(nil) // Pass nil service, it will be set later
	log.Println("Recommendation queue initialized successfully")
}

// createRecommendationService creates a recommendation service with our direct connection
// IMPORTANT: This MUST be called after database is initialized via the queue
func createRecommendationService() *recommendations.Service {
	log.Println("Creating recommendation service...")

	// Create the service using the global DB instance
	// DB is a global variable in the db package that implements the Database interface
	if db.DB == nil {
		log.Println("ERROR: db.DB is nil - database not properly initialized")
		return nil
	}

	// Create and return the service with all required dependencies
	service := recommendations.NewService(db.DB, wikidataClient, wikipediaClient)

	log.Println("Recommendation service created successfully")
	return service
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
	// Let Go runtime handle signals instead
	// C.setup_safe_signal_handlers() - removed to prevent signal conflicts

	// Note: We're letting Go's runtime handle signals to avoid conflicts
	// with the mixed Go/C/Dart environment
}

// Recommendation FFI Functions

//export Recommendation_FindAndSaveSuggestion
func Recommendation_FindAndSaveSuggestion(rawQueryC *C.char, mediaTypeC *C.char, botReasoningC *C.char) *C.char {
	// Ensure service is initialized (this will also initialize the queue)
	if !ensureRecommendationServiceInitialized() {
		return returnJSON(map[string]string{"error": "Recommendation service not initialized"})
	}

	// Safe conversion of parameters - non-blocking
	rawQuery := C.GoString(rawQueryC)
	mediaType := C.GoString(mediaTypeC)
	botReasoning := C.GoString(botReasoningC)

	// Create a request ID for this operation
	requestID := recommendations.EnqueueRecommendationRequest(rawQuery, mediaType, botReasoning)
	if requestID == "" {
		return returnJSON(map[string]string{"error": "Failed to enqueue recommendation request (queue full)"})
	}

	// Return the request ID immediately instead of waiting for the result
	// Flutter will need to call Recommendation_GetSuggestionResult later to get the actual result
	return returnJSON(map[string]string{
		"request_id": requestID,
		"status":     "processing",
		"message":    "Recommendation request queued successfully",
	})
}

//export Recommendation_GetSuggestionResult
func Recommendation_GetSuggestionResult(requestIDC *C.char, timeoutMsC C.int) *C.char {
	requestID := C.GoString(requestIDC)

	// Always use non-blocking mode (timeoutMs=0) to prevent blocking the Flutter thread
	// The timeoutMs parameter is ignored to ensure we never block

	// Get the result with the specified timeout
	suggestion, err := recommendations.GetRecommendationResult(requestID, 0)
	if err != nil {
		// Check if the request is still processing
		if err.Error() == "request is still processing" {
			return returnJSON(map[string]string{
				"request_id": requestID,
				"status":     "pending",
				"message":    "Request is still being processed",
			})
		}
		return processError(err)
	}

	// Convert the suggestion to JSON
	result := map[string]interface{}{
		"id":            suggestion.ID,
		"title":         suggestion.Title,
		"description":   suggestion.Description,
		"media_type":    suggestion.MediaType,
		"status":        string(suggestion.Status),
		"created_at":    suggestion.CreatedAt,
		"query":         suggestion.Query,
		"bot_reasoning": suggestion.BotReasoning,
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

	// Default status filter is empty (all statuses)
	var statusFilter models.SuggestionStatus
	if statusFilterStr != "" {
		statusFilter = models.SuggestionStatus(statusFilterStr)
	}

	// Create a request ID for this operation
	requestID := recommendations.EnqueueGetAllSuggestionsRequest(mediaType, statusFilter, limit, offset)
	if requestID == "" {
		return returnJSON(map[string]string{"error": "Failed to enqueue GetAllSuggestions request (queue full)"})
	}

	// Return the request ID immediately
	return returnJSON(map[string]string{
		"request_id": requestID,
		"status":     "processing",
		"message":    "GetAllSuggestions request queued successfully",
	})
}

//export Recommendation_GetAllSuggestionsResult
func Recommendation_GetAllSuggestionsResult(requestIDC *C.char, timeoutMsC C.int) *C.char {
	requestID := C.GoString(requestIDC)

	// Always use non-blocking mode (timeoutMs=0) to prevent blocking the Flutter thread
	// The timeoutMs parameter is ignored to ensure we never block

	// Get the result with the specified timeout
	suggestions, err := recommendations.GetGetAllSuggestionsResult(requestID, 0)
	if err != nil {
		// Check if the request is still processing
		if err.Error() == "request is still processing" {
			return returnJSON(map[string]string{
				"request_id": requestID,
				"status":     "pending",
				"message":    "Request is still being processed",
			})
		}
		return processError(err)
	}

	// Convert the suggestions to a JSON-friendly format
	result := make([]map[string]interface{}, len(suggestions))
	for i, suggestion := range suggestions {
		result[i] = map[string]interface{}{
			"id":            suggestion.ID,
			"title":         suggestion.Title,
			"description":   suggestion.Description,
			"media_type":    suggestion.MediaType,
			"status":        string(suggestion.Status),
			"created_at":    suggestion.CreatedAt,
			"query":         suggestion.Query,
			"bot_reasoning": suggestion.BotReasoning,
		}
	}

	// Return the result as JSON
	return returnJSON(result)
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

	status := models.SuggestionStatus(statusStr)

	// Create a request ID for this operation
	requestID := recommendations.EnqueueUpdateStatusRequest(suggestionID, status)
	if requestID == "" {
		return returnJSON(map[string]string{"error": "Failed to enqueue UpdateStatus request (queue full)"})
	}

	// Return the request ID immediately
	return returnJSON(map[string]string{
		"request_id": requestID,
		"status":     "processing",
		"message":    "UpdateStatus request queued successfully",
	})
}

//export Recommendation_UpdateSuggestionStatusResult
func Recommendation_UpdateSuggestionStatusResult(requestIDC *C.char, timeoutMsC C.int) *C.char {
	requestID := C.GoString(requestIDC)

	// Always use non-blocking mode (timeoutMs=0) to prevent blocking the Flutter thread
	// The timeoutMs parameter is ignored to ensure we never block

	// Get the result with the specified timeout
	processed, err := recommendations.GetUpdateStatusResult(requestID, 0)
	if err != nil {
		// Check if the request is still processing
		if err.Error() == "request is still processing" {
			return returnJSON(map[string]string{
				"request_id": requestID,
				"status":     "pending",
				"message":    "Request is still being processed",
			})
		}
		return processError(err)
	}

	// If the request was processed successfully
	if processed {
		return returnJSON(map[string]string{
			"success": "true",
			"message": "Status updated successfully",
		})
	} else {
		return returnJSON(map[string]string{
			"success": "false",
			"message": "Failed to update status",
		})
	}
}

//export Recommendation_GetPendingSuggestionsCount
func Recommendation_GetPendingSuggestionsCount(mediaTypeC *C.char) *C.char {
	if !ensureRecommendationServiceInitialized() {
		return returnJSON(map[string]string{"error": "Recommendation service not initialized"})
	}

	mediaType := C.GoString(mediaTypeC)

	// Create a request ID for this operation
	requestID := recommendations.EnqueueGetPendingCountRequest(mediaType)
	if requestID == "" {
		return returnJSON(map[string]string{"error": "Failed to enqueue GetPendingCount request (queue full)"})
	}

	// Return the request ID immediately
	return returnJSON(map[string]string{
		"request_id": requestID,
		"status":     "processing",
		"message":    "GetPendingCount request queued successfully",
	})
}

//export Recommendation_GetPendingSuggestionsCountResult
func Recommendation_GetPendingSuggestionsCountResult(requestIDC *C.char, timeoutMsC C.int) *C.char {
	requestID := C.GoString(requestIDC)

	// Always use non-blocking mode (timeoutMs=0) to prevent blocking the Flutter thread
	// The timeoutMs parameter is ignored to ensure we never block

	// Get the result with the specified timeout
	count, err := recommendations.GetPendingCountResult(requestID, 0)
	if err != nil {
		// If the error is that the request is still processing, return a pending status
		if err.Error() == "request is still processing" {
			return returnJSON(map[string]string{
				"request_id": requestID,
				"status":     "pending",
				"message":    "Request is still being processed",
			})
		}
		return processError(err)
	}

	// Return the result as JSON
	return returnJSON(map[string]interface{}{
		"count": count,
	})
}
