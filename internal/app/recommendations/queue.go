package recommendations

/*
#include <stdlib.h>
#include <signal.h>

// We need to modify our signal handling approach to avoid conflicts with Go runtime
// Instead of handling signals ourselves, we'll use Go's signal handling

// This is a no-op function that will be called from Go
static void setup_safe_signal_handlers() {
    // Do nothing - Go will handle signals properly
}
*/
import "C"
import (
	"context"
	"fmt"
	"log"
	"runtime"
	"sync"
	"time"

	"interestnaut/internal/app/db"
	"interestnaut/internal/app/models"

	"github.com/google/uuid"
)

// RequestType defines the type of request to be processed
type RequestType int

const (
	RequestTypeRecommendation RequestType = iota
	RequestTypeGetAllSuggestions
	RequestTypeUpdateStatus
	RequestTypeGetPendingCount
	RequestTypeDBInit
)

// RecommendationRequest represents a request to be processed by the worker
type RecommendationRequest struct {
	ID              string                 // Unique ID for this request
	Type            RequestType            // Type of request
	RawQuery        string                 // Raw query string (for recommendations)
	MediaType       string                 // Media type (for recommendations and get pending count)
	BotReasoning    string                 // Bot reasoning (for recommendations)
	SuggestionID    string                 // Suggestion ID (for updating status)
	SuggestionStatus models.SuggestionStatus // Suggestion status (for updating status)
	StatusFilter    models.SuggestionStatus // Status filter (for get all suggestions)
	Limit           int                    // Limit (for get all suggestions)
	Offset          int                    // Offset (for get all suggestions)
	DBPath          string                 // Database path (for DB initialization)
	ResultChan      chan error             // Result channel for DB initialization
}

// RecommendationResponse represents a response from the worker
type RecommendationResponse struct {
	RequestID string      // ID of the request this is a response to
	Result    interface{} // Result data, can be different types depending on the request
	Error     error       // Error, if any
}

var (
	requestQueue  chan RecommendationRequest
	responseMap   map[string]chan RecommendationResponse
	responseMux   sync.RWMutex
	workerOnce    sync.Once
	isInitialized bool
	initMux       sync.Mutex
	worker        *workerState
	queueSize     = 100
)

type workerState struct {
	service *Service
	active  bool
}

// InitRecommendationQueue initializes the recommendation queue and starts the worker
// This must be called from the main thread/goroutine before any FFI calls are made
func InitRecommendationQueue(service *Service) {
	initMux.Lock()
	defer initMux.Unlock()

	if isInitialized {
		return
	}

	// Initialize the request queue and response map if not already done
	if requestQueue == nil {
		log.Println("Creating recommendation queue and response map")
		requestQueue = make(chan RecommendationRequest, queueSize)
		responseMap = make(map[string]chan RecommendationResponse)
	} else {
		log.Println("Recommendation queue already initialized")
	}

	// Start the worker goroutine that processes requests
	// This is the ONLY goroutine that will perform signal-sensitive operations
	// The service is initially nil and will be set when the first request comes in
	if worker == nil {
		log.Println("Starting recommendation worker")
		worker = &workerState{
			service: service,
			active:  true,
		}
		workerOnce.Do(func() {
			go startRecommendationWorker(worker.service)
		})
	} else {
		if service != nil && worker.service == nil {
			log.Println("Updating worker with service instance")
			worker.service = service
		}
		log.Println("Recommendation worker already running")
	}

	isInitialized = true
	log.Println("Recommendation queue initialized")
}

// UpdateWorkerService updates the service used by the worker
// This should be called after the database is initialized and service is created
func UpdateWorkerService(service *Service) {
	if worker != nil {
		worker.service = service
		log.Println("Updated worker with new service instance")
	} else {
		log.Println("WARNING: Cannot update worker service - worker not initialized")
	}
}

// EnqueueRecommendationRequest adds a new recommendation request to the queue.
// It returns a unique request ID that can be used to retrieve the result later.
// This function is safe to call from any thread, including the Flutter thread.
func EnqueueRecommendationRequest(rawQuery string, mediaType string, botReasoning string) string {
	// Generate a unique ID for this request
	requestID := generateRequestID()

	// Create a new request object
	request := RecommendationRequest{
		ID:           requestID,
		Type:         RequestTypeRecommendation,
		RawQuery:     rawQuery,
		MediaType:    mediaType,
		BotReasoning: botReasoning,
	}

	return enqueueRequest(request)
}

// EnqueueGetAllSuggestionsRequest adds a new GetAllSuggestions request to the queue.
// It returns a unique request ID that can be used to retrieve the result later.
func EnqueueGetAllSuggestionsRequest(mediaType string, statusFilter models.SuggestionStatus, limit int, offset int) string {
	// Generate a unique ID for this request
	requestID := generateRequestID()

	// Create a new request object
	request := RecommendationRequest{
		ID:          requestID,
		Type:        RequestTypeGetAllSuggestions,
		MediaType:   mediaType,
		StatusFilter: statusFilter,
		Limit:       limit,
		Offset:      offset,
	}

	return enqueueRequest(request)
}

// EnqueueUpdateStatusRequest adds a new UpdateStatus request to the queue.
// It returns a unique request ID that can be used to retrieve the result later.
func EnqueueUpdateStatusRequest(suggestionID string, status models.SuggestionStatus) string {
	// Generate a unique ID for this request
	requestID := generateRequestID()

	// Create a new request object
	request := RecommendationRequest{
		ID:               requestID,
		Type:             RequestTypeUpdateStatus,
		SuggestionID:     suggestionID,
		SuggestionStatus: status,
	}

	return enqueueRequest(request)
}

// EnqueueGetPendingCountRequest adds a new GetPendingCount request to the queue.
// It returns a unique request ID that can be used to retrieve the result later.
func EnqueueGetPendingCountRequest(mediaType string) string {
	// Generate a unique ID for this request
	requestID := generateRequestID()

	// Create a new request object
	request := RecommendationRequest{
		ID:        requestID,
		Type:      RequestTypeGetPendingCount,
		MediaType: mediaType,
	}

	return enqueueRequest(request)
}

// EnqueueDBInitRequest adds a new DB initialization request to the queue
// This allows database initialization to happen on the locked worker thread
func EnqueueDBInitRequest(dbPath string, resultChan chan error) string {
	// Create a new request object for DB initialization
	request := RecommendationRequest{
		ID:         generateRequestID(),
		Type:       RequestTypeDBInit,
		DBPath:     dbPath,
		ResultChan: resultChan,
	}

	// Send the request to the queue
	select {
	case requestQueue <- request:
		log.Printf("Enqueued DB initialization request %s", request.ID)
		return request.ID
	default:
		// Queue is full, return error through the result channel
		log.Printf("Failed to enqueue DB initialization request - queue is full")
		resultChan <- fmt.Errorf("queue is full, cannot initialize database")
		return ""
	}
}

// Common function to enqueue a request and set up response channel
func enqueueRequest(request RecommendationRequest) string {
	// Create a response channel for this request
	responseMux.Lock()
	responseMap[request.ID] = make(chan RecommendationResponse, 1)
	responseMux.Unlock()

	// Add the request to the queue
	select {
	case requestQueue <- request:
		log.Printf("Enqueued request %s of type %d", request.ID, request.Type)
		return request.ID
	default:
		// Queue is full, clean up the response channel and return empty ID
		responseMux.Lock()
		delete(responseMap, request.ID)
		responseMux.Unlock()
		log.Printf("Failed to enqueue request - queue is full")
		return ""
	}
}

// generateRequestID creates a unique ID for a request
func generateRequestID() string {
	return uuid.New().String()
}

// getRequestResult gets the result for any request type with the given timeout
func getRequestResult(requestID string, timeoutMs int) (interface{}, error) {
	// Get the response channel for this request
	responseMux.RLock()
	responseChan, exists := responseMap[requestID]
	responseMux.RUnlock()

	if !exists {
		return nil, fmt.Errorf("no response channel found for request ID: %s", requestID)
	}

	// If timeout is 0, check if result is already available without waiting
	if timeoutMs <= 0 {
		select {
		case response := <-responseChan:
			// Clean up the response channel
			responseMux.Lock()
			delete(responseMap, requestID)
			responseMux.Unlock()

			if response.Error != nil {
				return nil, response.Error
			}
			return response.Result, nil
		default:
			// No result available yet - return a special error
			return nil, fmt.Errorf("request is still processing")
		}
	}

	// Wait for the response with timeout
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutMs)*time.Millisecond)
	defer cancel()

	select {
	case response := <-responseChan:
		// Clean up the response channel
		responseMux.Lock()
		delete(responseMap, requestID)
		responseMux.Unlock()

		if response.Error != nil {
			return nil, response.Error
		}
		return response.Result, nil
	case <-ctx.Done():
		// Timeout reached, return a specific error for "still processing"
		return nil, fmt.Errorf("request is still processing")
	}
}

// GetRecommendationResult retrieves the result for a given request ID.
// Set timeoutMs to 0 for non-blocking behavior.
func GetRecommendationResult(requestID string, timeoutMs int) (*models.MediaSuggestion, error) {
	// Non-blocking check first
	if timeoutMs == 0 {
		// First check if the request exists in our response map
		responseMux.RLock()
		respChan, exists := responseMap[requestID]
		responseMux.RUnlock()
		
		if !exists {
			return nil, fmt.Errorf("invalid request ID or request already completed")
		}
		
		// Non-blocking check
		select {
		case resp := <-respChan:
			if resp.Error != nil {
				return nil, resp.Error
			}
			
			// Type assertion
			suggestion, ok := resp.Result.(*models.MediaSuggestion)
			if !ok {
				return nil, fmt.Errorf("unexpected result type: %T", resp.Result)
			}
			
			return suggestion, nil
		default:
			// Still processing
			return nil, fmt.Errorf("request is still processing")
		}
	}
	
	// If timeout > 0, use the original blocking implementation
	result, err := getRequestResult(requestID, timeoutMs)
	if err != nil {
		return nil, err
	}
	
	// If result is nil, it means the request hasn't been processed yet
	if result == nil {
		return nil, nil
	}
	
	// Type assertion
	suggestion, ok := result.(*models.MediaSuggestion)
	if !ok {
		return nil, fmt.Errorf("unexpected result type: %T", result)
	}
	
	return suggestion, nil
}

// GetGetAllSuggestionsResult retrieves the result for a get all suggestions request.
// Set timeoutMs to 0 for non-blocking behavior.
func GetGetAllSuggestionsResult(requestID string, timeoutMs int) ([]*models.MediaSuggestion, error) {
	// Non-blocking check first
	if timeoutMs == 0 {
		// First check if the request exists in our response map
		responseMux.RLock()
		respChan, exists := responseMap[requestID]
		responseMux.RUnlock()
		
		if !exists {
			return nil, fmt.Errorf("invalid request ID or request already completed")
		}
		
		// Non-blocking check
		select {
		case resp := <-respChan:
			if resp.Error != nil {
				return nil, resp.Error
			}
			
			// Type assertion
			suggestions, ok := resp.Result.([]*models.MediaSuggestion)
			if !ok {
				return nil, fmt.Errorf("unexpected result type: %T", resp.Result)
			}
			
			return suggestions, nil
		default:
			// Still processing
			return nil, fmt.Errorf("request is still processing")
		}
	}
	
	// If timeout > 0, use the original blocking implementation
	result, err := getRequestResult(requestID, timeoutMs)
	if err != nil {
		return nil, err
	}
	
	// If result is nil, it means the request hasn't been processed yet
	if result == nil {
		return nil, nil
	}
	
	// Type assertion
	suggestions, ok := result.([]*models.MediaSuggestion)
	if !ok {
		return nil, fmt.Errorf("unexpected result type: %T", result)
	}
	
	return suggestions, nil
}

// GetUpdateStatusResult retrieves the result for an update status request.
// Set timeoutMs to 0 for non-blocking behavior.
func GetUpdateStatusResult(requestID string, timeoutMs int) (bool, error) {
	// Non-blocking check first
	if timeoutMs == 0 {
		// First check if the request exists in our response map
		responseMux.RLock()
		respChan, exists := responseMap[requestID]
		responseMux.RUnlock()
		
		if !exists {
			return false, fmt.Errorf("invalid request ID or request already completed")
		}
		
		// Non-blocking check
		select {
		case resp := <-respChan:
			if resp.Error != nil {
				return false, resp.Error
			}
			
			// Type assertion
			processed, ok := resp.Result.(bool)
			if !ok {
				return false, fmt.Errorf("unexpected result type: %T", resp.Result)
			}
			
			return processed, nil
		default:
			// Still processing
			return false, fmt.Errorf("request is still processing")
		}
	}
	
	// If timeout > 0, use the original blocking implementation
	result, err := getRequestResult(requestID, timeoutMs)
	if err != nil {
		return false, err
	}
	
	// If result is nil, it means the request hasn't been processed yet
	if result == nil {
		return false, nil
	}
	
	// Type assertion
	processed, ok := result.(bool)
	if !ok {
		return false, fmt.Errorf("unexpected result type: %T", result)
	}
	
	return processed, nil
}

// GetPendingCountResult retrieves the result for a get pending count request.
// Set timeoutMs to 0 for non-blocking behavior.
func GetPendingCountResult(requestID string, timeoutMs int) (int, error) {
	// Non-blocking check first
	if timeoutMs == 0 {
		// First check if the request exists in our response map
		responseMux.RLock()
		respChan, exists := responseMap[requestID]
		responseMux.RUnlock()
		
		if !exists {
			return 0, fmt.Errorf("invalid request ID or request already completed")
		}
		
		// Non-blocking check
		select {
		case resp := <-respChan:
			if resp.Error != nil {
				return 0, resp.Error
			}
			
			// Type assertion
			count, ok := resp.Result.(int)
			if !ok {
				return 0, fmt.Errorf("unexpected result type: %T", resp.Result)
			}
			
			return count, nil
		default:
			// Still processing
			return 0, fmt.Errorf("request is still processing")
		}
	}
	
	// If timeout > 0, use the original blocking implementation
	result, err := getRequestResult(requestID, timeoutMs)
	if err != nil {
		return 0, err
	}
	
	// If result is nil, it means the request hasn't been processed yet
	if result == nil {
		return 0, nil
	}
	
	// Type assertion
	count, ok := result.(int)
	if !ok {
		return 0, fmt.Errorf("unexpected result type: %T", result)
	}
	
	return count, nil
}

// GetDBInitResult checks if a DB initialization request has completed.
// This is a non-blocking check (when timeoutMs is 0).
func GetDBInitResult(requestID string, timeoutMs int) (bool, error) {
	// First check if the request exists in our response map
	responseMux.RLock()
	respChan, exists := responseMap[requestID]
	responseMux.RUnlock()
	
	if !exists {
		return false, fmt.Errorf("invalid request ID or request already completed")
	}
	
	// If timeout is 0, do a non-blocking check
	if timeoutMs == 0 {
		select {
		case resp := <-respChan:
			if resp.Error != nil {
				return false, resp.Error
			}
			return true, nil
		default:
			// Still processing
			return false, fmt.Errorf("request is still processing")
		}
	}
	
	// Otherwise, wait for the specified timeout
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutMs)*time.Millisecond)
	defer cancel()
	
	select {
	case resp := <-respChan:
		if resp.Error != nil {
			return false, resp.Error
		}
		return true, nil
	case <-ctx.Done():
		return false, fmt.Errorf("request is still processing")
	}
}

// startRecommendationWorker processes items from the request queue on a locked OS thread
func startRecommendationWorker(service *Service) {
	// Lock this goroutine to its current operating system thread.
	// This ensures signal handling will work correctly with the goroutine's stack.
	runtime.LockOSThread()
	log.Println("Worker thread locked to OS thread for safe signal handling")

	// Setup context for graceful shutdowns
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Ensure signal handlers are set up properly
	C.setup_safe_signal_handlers()
	
	// Process items from the queue
	for {
		select {
		case <-ctx.Done():
			log.Println("Recommendation worker shutting down due to context cancellation")
			return
			
		case request := <-requestQueue:
			log.Printf("Processing request %s of type %d", request.ID, request.Type)
			
			// Setup panic recovery for this request
			defer func() {
				if r := recover(); r != nil {
					// Log the panic and create an error response
					errMsg := fmt.Sprintf("Panic processing request %s: %v", request.ID, r)
					log.Printf(errMsg)
					
					// Create a stack trace
					buf := make([]byte, 4096)
					n := runtime.Stack(buf, false)
					log.Printf("Stack trace: %s", buf[:n])

					// Send error response
					responseMux.RLock()
					respChan, exists := responseMap[request.ID]
					responseMux.RUnlock()

					if exists {
						respChan <- RecommendationResponse{
							RequestID: request.ID,
							Result:    nil,
							Error:     fmt.Errorf(errMsg),
						}
					}
				}
			}()
			
			// Process the request directly on this locked thread
			// Do NOT spawn a new goroutine here as it would defeat the thread locking
			switch request.Type {
			case RequestTypeRecommendation:
				processRecommendationRequest(ctx, worker.service, request)
			case RequestTypeGetAllSuggestions:
				processGetAllSuggestionsRequest(ctx, worker.service, request)
			case RequestTypeUpdateStatus:
				processUpdateStatusRequest(ctx, worker.service, request)
			case RequestTypeGetPendingCount:
				processGetPendingCountRequest(ctx, worker.service, request)
			case RequestTypeDBInit:
				processDBInitRequest(ctx, worker.service, request)
			default:
				log.Printf("Unknown request type: %d", request.Type)
					
				// Send error response
				responseMux.RLock()
				respChan, exists := responseMap[request.ID]
				responseMux.RUnlock()
					
				if exists {
					respChan <- RecommendationResponse{
						RequestID: request.ID,
						Error:     fmt.Errorf("unknown request type: %d", request.Type),
					}
				} else {
					log.Printf("No response channel found for request %s", request.ID)
				}
			}
		}
	}
}

// processRecommendationRequest processes a single recommendation request.
// This function is only called from the worker goroutine that has been locked to a specific OS thread.
func processRecommendationRequest(ctx context.Context, service *Service, request RecommendationRequest) {
	log.Printf("Processing recommendation request %s for %s", request.ID, request.MediaType)

	// Execute the blocking operations on the locked thread
	result, err := service.FindAndSaveSuggestion(
		ctx,
		request.RawQuery,
		request.MediaType,
		request.BotReasoning,
	)

	// Create the response
	response := RecommendationResponse{
		RequestID: request.ID,
		Result:    result,
		Error:     err,
	}

	// Send the response back through the channel
	responseMux.RLock()
	responseChan, exists := responseMap[request.ID]
	responseMux.RUnlock()

	if exists {
		select {
		case responseChan <- response:
			log.Printf("Processed recommendation request %s for %s", request.ID, request.MediaType)
		default:
			log.Printf("Response channel for request %s is full, dropping response", request.ID)
		}
	} else {
		log.Printf("No response channel found for request %s, dropping response", request.ID)
	}
}

// processGetAllSuggestionsRequest processes a single GetAllSuggestions request.
// This function is only called from the worker goroutine that has been locked to a specific OS thread.
func processGetAllSuggestionsRequest(ctx context.Context, service *Service, request RecommendationRequest) {
	log.Printf("Processing GetAllSuggestions request %s for %s", request.ID, request.MediaType)

	// Execute the blocking operations on the locked thread
	result, err := service.GetAllSuggestions(
		ctx,
		request.MediaType,
		request.StatusFilter,
		request.Limit,
		request.Offset,
	)

	// Create the response
	response := RecommendationResponse{
		RequestID: request.ID,
		Result:    result,
		Error:     err,
	}

	// Send the response back through the channel
	responseMux.RLock()
	responseChan, exists := responseMap[request.ID]
	responseMux.RUnlock()

	if exists {
		select {
		case responseChan <- response:
			log.Printf("Processed GetAllSuggestions request %s for %s", request.ID, request.MediaType)
		default:
			log.Printf("Response channel for request %s is full, dropping response", request.ID)
		}
	} else {
		log.Printf("No response channel found for request %s, dropping response", request.ID)
	}
}

// processUpdateStatusRequest processes a single UpdateStatus request.
// This function is only called from the worker goroutine that has been locked to a specific OS thread.
func processUpdateStatusRequest(ctx context.Context, service *Service, request RecommendationRequest) {
	log.Printf("Processing UpdateStatus request %s for %s", request.ID, request.SuggestionID)

	// Execute the blocking operations on the locked thread
	err := service.UpdateSuggestionStatus(
		ctx,
		request.SuggestionID,
		request.SuggestionStatus,
	)

	// Create the response
	response := RecommendationResponse{
		RequestID: request.ID,
		Result:    true, // Just return true on success
		Error:     err,
	}

	// Send the response back through the channel
	responseMux.RLock()
	responseChan, exists := responseMap[request.ID]
	responseMux.RUnlock()

	if exists {
		select {
		case responseChan <- response:
			log.Printf("Processed UpdateStatus request %s for %s", request.ID, request.SuggestionID)
		default:
			log.Printf("Response channel for request %s is full, dropping response", request.ID)
		}
	} else {
		log.Printf("No response channel found for request %s, dropping response", request.ID)
	}
}

// processGetPendingCountRequest processes a single GetPendingCount request.
// This function is only called from the worker goroutine that has been locked to a specific OS thread.
func processGetPendingCountRequest(ctx context.Context, service *Service, request RecommendationRequest) {
	log.Printf("Processing GetPendingCount request %s for %s", request.ID, request.MediaType)

	// Execute the blocking operations on the locked thread
	result, err := service.GetPendingSuggestionsCount(
		ctx,
		request.MediaType,
	)

	// Create the response
	response := RecommendationResponse{
		RequestID: request.ID,
		Result:    result,
		Error:     err,
	}

	// Send the response back through the channel
	responseMux.RLock()
	responseChan, exists := responseMap[request.ID]
	responseMux.RUnlock()

	if exists {
		select {
		case responseChan <- response:
			log.Printf("Processed GetPendingCount request %s for %s", request.ID, request.MediaType)
		default:
			log.Printf("Response channel for request %s is full, dropping response", request.ID)
		}
	} else {
		log.Printf("No response channel found for request %s, dropping response", request.ID)
	}
}

// processDBInitRequest processes a single DB initialization request.
// This function is only called from the worker goroutine that has been locked to a specific OS thread.
func processDBInitRequest(ctx context.Context, service *Service, request RecommendationRequest) {
	log.Printf("Processing DB initialization request %s", request.ID)

	// Initialize the database with our direct connection approach
	// This runs on the locked thread, ensuring all SQLite operations
	// happen on the same thread with properly set up signal handlers
	err := db.InitDB(request.DBPath)

	// Send the result back through the result channel
	request.ResultChan <- err
}
