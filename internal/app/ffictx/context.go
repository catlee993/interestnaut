package ffictx

import (
	"context"
	"net"
	"sync"
)

var GlobalFFIContext *FFIContext

// FFIContext encapsulates all state for the FFI bridge, eventbus, and related state
// to avoid package-level globals, simplify teardown, and make testing easier.
type FFIContext struct {
	Bridge      any
	EventBus    any
	Listener    net.Listener
	Port        int
	AuthMu      sync.Mutex
	AuthInProgress bool
	ShutdownCh  chan struct{}
	Connections map[net.Conn]bool
	ConnectionsMu sync.Mutex
	Ctx         context.Context
	CtxCancel   context.CancelFunc
}

func InitGlobalFFIContext(bridge any, eventBus any) {
	GlobalFFIContext = &FFIContext{
		Bridge:      bridge,
		EventBus:    eventBus,
		ShutdownCh:  make(chan struct{}),
		Connections: make(map[net.Conn]bool),
	}
}

// SafeGo runs fn in a goroutine with panic recovery and optional error/event handling.
func (fc *FFIContext) SafeGo(fn func()) {
	go func() {
		defer func() {
			if r := recover(); r != nil {
				// Optionally emit a safe event or log
			}
		}()
		fn()
	}()
}

// SetAuthInProgress safely sets the auth-in-progress flag
func (fc *FFIContext) SetAuthInProgress(val bool) {
	fc.AuthMu.Lock()
	defer fc.AuthMu.Unlock()
	fc.AuthInProgress = val
}

// IsAuthInProgress safely gets the auth-in-progress flag
func (fc *FFIContext) IsAuthInProgress() bool {
	fc.AuthMu.Lock()
	defer fc.AuthMu.Unlock()
	return fc.AuthInProgress
}

// Shutdown cleanly shuts down the FFI bridge and eventbus
func (fc *FFIContext) Shutdown() {
	if fc.CtxCancel != nil {
		fc.CtxCancel()
	}
	if fc.Listener != nil {
		fc.Listener.Close()
	}
	// Bridge and EventBus shutdown must be handled by the user with type assertion
	close(fc.ShutdownCh)
}
