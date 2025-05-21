package recommendations

import (
	"context"
	"log"
	"runtime"
	"sync"
	"time"

	"github.com/google/uuid"
)

// RecommendationRequest represents a work item for the recommendation worker
type RecommendationRequest struct {
	ID           string
	RawQuery     string
	MediaType    string
	BotReasoning string
}

// RecommendationResponse contains the result of a processed recommendation request
type RecommendationResponse struct {
	RequestID string
	Result    interface{}
	Error     error
}

var (
	requestQueue chan RecommendationRequest
	responseMap  map[string]chan RecommendationResponse
	responseMux  sync.RWMutex
	workerOnce   sync.Once
	isInitialized bool
	initMux       sync.Mutex
)

// InitRecommendationQueue initializes the recommendation queue and starts the worker
// This must be called from the main thread/goroutine before any FFI calls are made
func InitRecommendationQueue(service *Service) {
	initMux.Lock()
	defer initMux.Unlock()
	
	if isInitialized {
		return
	}
	
	requestQueue = make(chan RecommendationRequest, 100)
	responseMap = make(map[string]chan RecommendationResponse)
	
	workerOnce.Do(func() {
		go startRecommendationWorker(service)
	})
	
	isInitialized = true
	log.Println("Recommendation queue initialized")
}

// EnqueueRecommendationRequest adds a new recommendation request to the queue
// This is safe to call from any thread, including from Flutter FFI calls
func EnqueueRecommendationRequest(rawQuery, mediaType, botReasoning string) string {
	// Generate a unique ID for this request
	requestID := uuid.New().String()
	
	// Create a response channel for this request
	responseMux.Lock()
	responseMap[requestID] = make(chan RecommendationResponse, 1)
	responseMux.Unlock()
	
	// Create the request
	request := RecommendationRequest{
		ID:           requestID,
		RawQuery:     rawQuery,
		MediaType:    mediaType,
		BotReasoning: botReasoning,
	}
	
	// Try to enqueue the request, dropping it if the queue is full
	select {
	case requestQueue <- request:
		log.Printf("Enqueued recommendation request %s for %s", requestID, mediaType)
	default:
		log.Printf("Request queue full, dropping recommendation request for %s", mediaType)
		
		// Clean up the response channel since we're not processing this request
		responseMux.Lock()
		delete(responseMap, requestID)
		responseMux.Unlock()
		
		return ""
	}
	
	return requestID
}

// GetRecommendationResult retrieves the result of a recommendation request
// If the request hasn't been processed yet, this will block until it is or until the timeout
func GetRecommendationResult(requestID string, timeoutMs int) (interface{}, error) {
	if requestID == "" {
		return nil, nil
	}
	
	// Get the response channel for this request
	responseMux.RLock()
	responseChan, exists := responseMap[requestID]
	responseMux.RUnlock()
	
	if !exists {
		return nil, nil
	}
	
	// Wait for the response or timeout
	var response RecommendationResponse
	select {
	case response = <-responseChan:
		// Clean up the response channel
		responseMux.Lock()
		delete(responseMap, requestID)
		responseMux.Unlock()
		return response.Result, response.Error
	case <-time.After(time.Duration(timeoutMs) * time.Millisecond):
		return nil, nil
	}
}

// startRecommendationWorker processes items from the request queue on a locked OS thread
func startRecommendationWorker(service *Service) {
	// Lock this goroutine to its OS thread to satisfy Go's signal handling requirements
	runtime.LockOSThread()
	log.Println("Recommendation worker started on locked OS thread")
	
	// Process requests from the queue
	for request := range requestQueue {
		processRecommendationRequest(service, request)
	}
}

// processRecommendationRequest handles a single recommendation request
func processRecommendationRequest(service *Service, request RecommendationRequest) {
	// Create a context with timeout for the operation
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	// Do the actual work - finding and saving the suggestion
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
