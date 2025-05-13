package eventbus

import (
	"encoding/json"
	"log"
	"net"
	"sync"
	"time"
)

type Event struct {
	Type    string                 `json:"type"`
	Payload map[string]interface{} `json:"payload"`
}

var (
	eventChan    chan Event
	eventChanMux sync.Mutex
	eventPort    int64
	serverOnce   sync.Once
	listener     net.Listener
	clientActive bool
	clientMux    sync.Mutex
)

// StartEventServer starts a TCP server for the event bus and returns the port
func StartEventServer() int64 {
	eventChanMux.Lock()
	if eventChan == nil {
		eventChan = make(chan Event, 100)
	}
	eventChanMux.Unlock()
	serverOnce.Do(func() {
		go runEventServer()
	})
	return eventPort
}

func runEventServer() {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		log.Fatalf("Failed to start event bus server: %v", err)
	}
	listener = ln
	addr := ln.Addr().(*net.TCPAddr)
	eventPort = int64(addr.Port)
	log.Printf("Event bus server listening on port %d", eventPort)
	for {
		conn, err := ln.Accept()
		if err != nil {
			log.Printf("Event bus accept error: %v", err)
			continue
		}
		if !setClientActive(true) {
			log.Printf("Rejecting additional event bus client: only one allowed")
			conn.Close()
			continue
		}
		go handleEventClient(conn)
	}
}

func handleEventClient(conn net.Conn) {
	defer func() {
		setClientActive(false)
		conn.Close()
	}()
	encoder := json.NewEncoder(conn)
	for {
		select {
		case ev := <-eventChan:
			conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
			if err := encoder.Encode(ev); err != nil {
				log.Printf("Error encoding event: %v", err)
				return
			}
		case <-time.After(30 * time.Second):
			// Keep connection alive
			if _, err := conn.Write([]byte("\n")); err != nil {
				return
			}
		}
	}
}

func setClientActive(active bool) bool {
	clientMux.Lock()
	defer clientMux.Unlock()
	if active {
		if clientActive {
			return false
		}
		clientActive = true
		return true
	} else {
		clientActive = false
		return true
	}
}

// Emit sends an event to the channel
func Emit(event Event) {
	eventChanMux.Lock()
	ch := eventChan
	eventChanMux.Unlock()
	if ch != nil {
		select {
		case ch <- event:
			log.Printf("Emitted event: %s", event.Type)
		default:
			log.Printf("Event channel full, dropping event: %s", event.Type)
		}
	} else {
		log.Printf("No event channel to emit: %s", event.Type)
	}
}
