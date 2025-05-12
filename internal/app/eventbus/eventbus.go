package eventbus

import (
	"C"
	"encoding/json"
	"log"
	"net"
	"os"
	"os/signal"
	"sync"
	"syscall"
)

// Event represents a typed event with a payload
type Event struct {
	Type    string                 `json:"type"`
	Payload map[string]interface{} `json:"payload"`
}

var (
	// Global singleton event bus
	globalBus      *EventBus
	globalListener net.Listener
	globalPort     int
	initOnce       sync.Once
	eventsMu       sync.RWMutex
	subscribers    = make(map[net.Conn]bool)
	// Signal handling
	signalChan     chan os.Signal
	shutdownChan   chan struct{}
)

// EventBus is a simple event bus for publishing events
type EventBus struct {
	events chan Event
}

// NewEventBus creates a new event bus
func NewEventBus() *EventBus {
	return &EventBus{
		events: make(chan Event, 100), // Buffered channel to avoid blocking
	}
}

// Emit publishes an event to all subscribers
func (b *EventBus) Emit(event Event) {
	// Non-blocking send on the events channel
	select {
	case b.events <- event:
		log.Printf("Emitted event: %s", event.Type)
	default:
		log.Printf("WARNING: Event bus buffer full, dropping event: %s", event.Type)
	}
}

// handleConnection processes events for a single client connection
func handleConnection(conn net.Conn, eb *EventBus) {
	defer func() {
		conn.Close()
		eventsMu.Lock()
		delete(subscribers, conn)
		eventsMu.Unlock()
		log.Printf("Client disconnected from event bus")
	}()

	eventsMu.Lock()
	subscribers[conn] = true
	eventsMu.Unlock()
	log.Printf("New client connected to event bus")

	// Create a JSON encoder for this connection
	encoder := json.NewEncoder(conn)

	// Create a client-specific buffer of events
	clientEvents := make(chan Event, 10)

	// Start a goroutine to forward global events to this client
	go func() {
		for event := range eb.events {
			// Non-blocking send to client's event channel
			select {
			case clientEvents <- event:
				// Successfully queued
			default:
				log.Printf("WARNING: Client event buffer full, dropping event: %s", event.Type)
			}
		}
	}()

	// Process events for this client
	for event := range clientEvents {
		if err := encoder.Encode(event); err != nil {
			log.Printf("Error encoding event: %v", err)
			return
		}
	}
}

// startEventServer starts a TCP server for the event bus
func startEventServer(eb *EventBus) (int, error) {
	// Set up proper signal handling to avoid FFI issues
	signalChan = make(chan os.Signal, 1)
	shutdownChan = make(chan struct{})
	
	// Configure signal handling to ensure signals are properly handled on the signal stack
	signal.Notify(signalChan, syscall.SIGUSR1, syscall.SIGUSR2, syscall.SIGINT)
	
	// Handle signals in a dedicated goroutine
	go func() {
		for {
			select {
			case sig := <-signalChan:
				log.Printf("Event bus received signal: %v", sig)
				// Just log the signal but continue running
			case <-shutdownChan:
				// Exit signal handler when shutting down
				return
			}
		}
	}()
	
	// Listen on a random port
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return 0, err
	}

	// Save the listener to prevent garbage collection
	globalListener = listener

	// Get the chosen port
	addr := listener.Addr().(*net.TCPAddr)
	chosenPort := addr.Port
	log.Printf("Event bus listening on port %d", chosenPort)

	// Accept connections in background
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				// Check if this is because the listener was closed
				if opErr, ok := err.(*net.OpError); ok && opErr.Err.Error() == "use of closed network connection" {
					log.Printf("Event bus listener closed")
					return
				}
				log.Printf("Error accepting connection: %v", err)
				continue
			}

			// Handle each connection in its own goroutine
			go handleConnection(conn, eb)
		}
	}()

	return chosenPort, nil
}

// InitEventBus initializes the global event bus and returns the port number
//export InitEventBus
func InitEventBus() C.int {
	var port int
	var err error

	initOnce.Do(func() {
		globalBus = NewEventBus()
		port, err = startEventServer(globalBus)
		if err != nil {
			log.Printf("Failed to start event server: %v", err)
			port = -1
			return
		}
		globalPort = port
	})

	if err != nil {
		return C.int(-1)
	}
	return C.int(port)
}

// GetGlobalBus returns the global event bus instance
func GetGlobalBus() *EventBus {
	if globalBus == nil {
		initOnce.Do(func() {
			globalBus = NewEventBus()
			var err error
			globalPort, err = startEventServer(globalBus)
			if err != nil {
				log.Printf("Failed to start event server: %v", err)
				globalPort = -1
			}
		})
	}
	return globalBus
}

// ShutdownEventBus closes the global event bus
//export ShutdownEventBus
func ShutdownEventBus() {
	log.Println("Shutting down event bus from FFI")
	
	// Stop signal handling
	if signalChan != nil {
		signal.Stop(signalChan)
		close(shutdownChan)
	}
	
	if globalListener != nil {
		globalListener.Close()
	}
	
	// Close all subscriber connections
	eventsMu.Lock()
	for conn := range subscribers {
		conn.Close()
	}
	subscribers = make(map[net.Conn]bool)
	eventsMu.Unlock()
	
	// Reset global state
	globalBus = nil
	globalListener = nil
	globalPort = 0
}
