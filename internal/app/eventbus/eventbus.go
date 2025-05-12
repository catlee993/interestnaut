package eventbus

import (
	"C"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"interestnaut/internal/app/bridge"
	"log"
	"net"
	"runtime"
	"strings"
	"sync"
	"time"
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

	// Global context and cancellation for the event bus
	globalCtx       context.Context
	globalCtxCancel context.CancelFunc

	// Global notification channel for shutdown
	shutdownChMu sync.Mutex
	shutdownCh   = make(chan struct{})
	shutdownFlag bool
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

// EmitSafe is a thread-safe version of Emit specifically designed for FFI boundary crossing
// It properly isolates signal handling to avoid FFI boundary crashes
func (b *EventBus) EmitSafe(event Event) {
	// Make a copy of the event to prevent race conditions
	eventCopy := Event{
		Type:    event.Type,
		Payload: event.Payload,
	}
	
	// Execute the emit on the dedicated FFI thread
	bridge.ExecuteOnFFIThreadAsync(func() {
		b.Emit(eventCopy)
	})
}

// handleConnection processes events for a single client connection
func handleConnection(ctx context.Context, conn net.Conn, eb *EventBus) {
	// Add connection to the tracking map
	connectionsMu.Lock()
	connections[conn] = true
	connectionsMu.Unlock()

	defer func() {
		// Recover from any panics
		if r := recover(); r != nil {
			log.Printf("Recovered from panic in handleConnection: %v", r)
		}

		// Close connection and clean up
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

	// Create a done channel for this client
	clientDone := make(chan struct{})

	// Start a goroutine to listen for context cancellation with thread isolation
	go func() {
		// Lock the OS thread for this goroutine to isolate signal handling
		runtime.LockOSThread()
		defer runtime.UnlockOSThread()
		
		defer close(clientDone)
		<-ctx.Done()
	}()

	// Create a channel for forwarding events
	clientEvents := make(chan Event, 10)

	// Create a WaitGroup to ensure all goroutines exit
	var wg sync.WaitGroup
	wg.Add(1)

	// Start goroutine to forward events to this client with thread isolation
	go func() {
		// Lock the OS thread for this goroutine to isolate signal handling
		runtime.LockOSThread()
		defer runtime.UnlockOSThread()
		
		defer wg.Done()
		defer func() {
			if r := recover(); r != nil {
				log.Printf("Recovered from panic in event forwarding goroutine: %v", r)
			}
		}()

		for {
			select {
			case <-ctx.Done():
				return
			case <-clientDone:
				return
			case event, ok := <-eb.events:
				if !ok {
					return
				}

				// Forward event to client's channel, or drop if client is slow
				select {
				case clientEvents <- event:
					// Successfully sent
				case <-ctx.Done():
					return
				case <-clientDone:
					return
				default:
					// Client channel is full, drop the event
					log.Printf("Client queue full, dropping event: %s", event.Type)
				}
			}
		}
	}()

	// Process events for this client
processEvents:
	for {
		select {
		case <-ctx.Done():
			break processEvents
		case <-clientDone:
			break processEvents
		case event, ok := <-clientEvents:
			if !ok {
				break processEvents
			}

			// Set a write deadline to prevent blocking forever
			conn.SetWriteDeadline(time.Now().Add(5 * time.Second))

			if err := encoder.Encode(event); err != nil {
				log.Printf("Error encoding event: %v", err)
				break processEvents
			}
		}
	}

	// Wait for forwarding goroutine to exit
	wg.Wait()
}

// startEventServer starts a TCP server for the event bus
func startEventServer(bus *EventBus) (int, error) {
	// Create a context with cancellation for this server
	ctx, cancel := context.WithCancel(context.Background())
	globalCtx = ctx
	globalCtxCancel = cancel

	// IMPORTANT: We deliberately avoid using signal handling here
	// as it can conflict with Go's runtime signal handling and
	// cause "non-Go code set up signal handler without SA_ONSTACK flag" errors.
	// Instead, we use a notification channel that can be triggered from our shutdown function.
	go func() {
		// Lock the OS thread for this goroutine to isolate signal handling
		runtime.LockOSThread()
		defer runtime.UnlockOSThread()
		
		defer func() {
			if r := recover(); r != nil {
				log.Printf("Recovered from panic in shutdown listener: %v", r)
			}
		}()

		select {
		case <-shutdownCh:
			log.Printf("Received shutdown notification, closing event bus")
			cancel()
		case <-ctx.Done():
			// Context was cancelled elsewhere
		}
	}()

	// If there's an existing listener, close it first
	if globalListener != nil {
		globalListener.Close()
		globalListener = nil
	}

	// Try to start on a random port
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		cancel() // Cancel the context if we can't start the server
		return -1, fmt.Errorf("failed to start event server: %w", err)
	}

	// Store the listener globally so we can close it if needed
	globalListener = listener

	addr, ok := listener.Addr().(*net.TCPAddr)
	if !ok {
		listener.Close()
		cancel()
		return -1, errors.New("failed to get TCP address")
	}

	port := addr.Port
	log.Printf("Event bus listening on port %d", port)

	// Start accepting connections in a goroutine
	go func() {
		// Lock the OS thread for this goroutine to isolate signal handling
		runtime.LockOSThread()
		defer runtime.UnlockOSThread()
		
		defer func() {
			if r := recover(); r != nil {
				log.Printf("Recovered from panic in accept loop: %v", r)
			}

			listener.Close()
			log.Println("Event server listener closed")
		}()

		// Use a ticker to periodically check for context cancellation
		ticker := time.NewTicker(500 * time.Millisecond)
		defer ticker.Stop()

		for {
			// Set accept deadline so we can check for cancellation
			listener.(*net.TCPListener).SetDeadline(time.Now().Add(1 * time.Second))

			// Check if context is cancelled
			select {
			case <-ctx.Done():
				return
			default:
				// Continue accepting connections
			}

			conn, err := listener.Accept()
			if err != nil {
				// Check if this is a timeout error
				if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
					continue
				}

				// Check if this is because the listener was closed
				if strings.Contains(err.Error(), "use of closed network connection") {
					return
				}

				log.Printf("Error accepting connection: %v", err)
				continue
			}

			// Handle each client connection in a separate goroutine with proper thread isolation
			go func(ctx context.Context, conn net.Conn, bus *EventBus) {
				// Lock the OS thread for this goroutine to isolate signal handling
				runtime.LockOSThread()
				defer runtime.UnlockOSThread()
				
				handleConnection(ctx, conn, bus)
			}(ctx, conn, bus)
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
	// Execute shutdown on the dedicated FFI thread to ensure proper signal handling
	bridge.ExecuteOnFFIThread(func() {
		log.Println("ShutdownEventBus called, sending shutdown notification")
		
		// Use mutex to protect shutdown operations and prevent double close
		shutdownChMu.Lock()
		if !shutdownFlag {
			shutdownFlag = true
			log.Println("Closing shutdown channel")
			close(shutdownCh)
		}
		shutdownChMu.Unlock()
		
		// Also cancel context directly as a backup method
		if globalCtxCancel != nil {
			globalCtxCancel()
			// Give goroutines a moment to clean up
			time.Sleep(50 * time.Millisecond)
		}
		
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
	})
}
