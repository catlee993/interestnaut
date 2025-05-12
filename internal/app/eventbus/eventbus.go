package eventbus

import (
	"C"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net"
	"strings"
	"sync"
)

// Event represents a typed event with a payload
type Event struct {
	Type    string                 `json:"type"`
	Payload map[string]interface{} `json:"payload"`
}

var (
	// Global singleton event bus
	globalBus      *EventBus
	globalPort     int
	globalListener net.Listener
	initOnce       sync.Once
	connCounter    int32

	// Track active connections with a mutex
	connectionsMu sync.Mutex
	connections   = make(map[net.Conn]bool)
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
	// Add connection to the tracking map
	connectionsMu.Lock()
	connections[conn] = true
	connectionsMu.Unlock()

	defer func() {
		conn.Close()

		// Remove connection from tracking map
		connectionsMu.Lock()
		delete(connections, conn)
		connectionsMu.Unlock()

		log.Printf("Client disconnected from event bus")
	}()

	log.Printf("New client connected to event bus")

	// Create a JSON encoder for this connection
	encoder := json.NewEncoder(conn)

	// Create channel for events specific to this client
	clientEvents := make(chan Event)

	// Subscribe to events
	go func() {
		for event := range eb.events {
			select {
			case clientEvents <- event:
				// Event sent to client
			default:
				// Client not keeping up, skip this event
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
func startEventServer(bus *EventBus) (int, error) {
	// Signal handling was causing conflicts with non-Go signal handlers
	// Removing explicit signal handling to prevent crashes

	// If there's an existing listener, close it first
	if globalListener != nil {
		globalListener.Close()
		globalListener = nil
	}

	// Try to start on a random port
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return -1, fmt.Errorf("failed to start event server: %w", err)
	}

	// Store the listener globally so we can close it if needed
	globalListener = listener

	addr, ok := listener.Addr().(*net.TCPAddr)
	if !ok {
		listener.Close()
		return -1, errors.New("failed to get TCP address")
	}

	port := addr.Port
	log.Printf("Event bus listening on port %d", port)

	// Start accepting connections in a goroutine
	go func() {
		for {
			conn, err := listener.Accept()
			if err != nil {
				// Check if this is because the listener was closed
				if strings.Contains(err.Error(), "use of closed network connection") {
					log.Println("Event server listener closed")
					return
				}

				log.Printf("Error accepting connection: %v", err)
				continue
			}

			log.Println("New client connected to event bus")

			// Handle each client connection in a separate goroutine
			go handleConnection(conn, bus)
		}
	}()

	return port, nil
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
			} else {
				log.Printf("Event bus listening on port %d", globalPort)
			}
		})
	} else if globalPort <= 0 {
		// If bus exists but port is invalid, try to restart the server
		var err error
		globalPort, err = startEventServer(globalBus)
		if err != nil {
			log.Printf("Failed to restart event server: %v", err)
		} else {
			log.Printf("Event bus restarted and listening on port %d", globalPort)
		}
	}
	return globalBus
}

// InitEventBus initializes the global event bus and returns the port number
//
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

// ShutdownEventBus closes the global event bus
//
//export ShutdownEventBus
func ShutdownEventBus() {
	// First close the listener to prevent new connections
	if globalListener != nil {
		globalListener.Close()
		globalListener = nil
	}

	// Close all connections
	connectionsMu.Lock()
	for conn := range connections {
		conn.Close()
	}
	connections = make(map[net.Conn]bool)
	connectionsMu.Unlock()

	log.Println("Event bus shut down successfully")
}
