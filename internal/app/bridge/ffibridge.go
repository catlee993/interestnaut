package bridge

import (
	"log"
	"os"
	"os/signal"
	"runtime"
	"sync"
	"syscall"
	"time"
)

/*
#include <stdlib.h>
#include <signal.h>
#include <string.h>
#include <stdio.h>
#include <pthread.h>
#include <sched.h>

// Signal handling utilities
void configure_thread_signals() {
    // Set up proper signal handling with SA_ONSTACK flag
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = SIG_IGN;
    sa.sa_flags = SA_ONSTACK;
    
    // Ignore SIGPIPE which commonly occurs with network/audio operations
    sigaction(SIGPIPE, &sa, NULL);
    
    // Also set explicit handlers for common signals that might interfere with Go runtime
    sigaction(SIGURG, &sa, NULL); // Signal 16 (SIGURG) that was causing the crash
}

// Thread priority settings
void set_thread_priority_high() {
    #ifdef __APPLE__
    // On macOS, use sched_param to set high priority
    struct sched_param param;
    param.sched_priority = sched_get_priority_max(SCHED_RR);
    pthread_setschedparam(pthread_self(), SCHED_RR, &param);
    fprintf(stderr, "Set thread priority to high for FFI thread\n");
    #endif
}
*/
import "C"

var (
	// Global bridge instance
	ffiBridge  *FFIBridge
	bridgeOnce sync.Once
)

// FFIBridge provides a dedicated thread for FFI operations
type FFIBridge struct {
	taskQueue chan FFITask
	shutdown  chan struct{}
	isRunning bool
}

// FFITask represents a unit of work to be executed on the FFI thread
type FFITask struct {
	fn       func()
	complete chan struct{}
}

// InitializeFFIBridge creates and starts the FFI bridge if not already running
func InitializeFFIBridge() {
	bridgeOnce.Do(func() {
		log.Println("Initializing dedicated FFI thread bridge")
		ffiBridge = &FFIBridge{
			taskQueue: make(chan FFITask, 100),
			shutdown:  make(chan struct{}),
			isRunning: true,
		}

		// Start the event loop goroutine
		go func() {
			// Lock this goroutine to its OS thread permanently
			runtime.LockOSThread()
			log.Println("FFI bridge thread started and locked")

			// Set up proper signal handling for this thread
			setupSignalHandling()

			// Configure thread signals and priority
			C.configure_thread_signals()
			C.set_thread_priority_high()

			// Start the event loop
			ffiBridge.eventLoop()
		}()
	})
}

// setupSignalHandling properly sets up signal handling for the dedicated FFI thread
func setupSignalHandling() {
	// Create a channel to receive OS signals
	sigChan := make(chan os.Signal, 1)

	// Register for SIGINT, SIGTERM, and SIGQUIT
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM, syscall.SIGQUIT)

	// Handle signals in a separate goroutine
	go func() {
		sig := <-sigChan
		log.Printf("Signal %v received, initiating shutdown", sig)

		// Give app time to clean up
		time.Sleep(500 * time.Millisecond)
		os.Exit(0)
	}()
}

// eventLoop is the core FFI thread that handles all cross-boundary calls
func (b *FFIBridge) eventLoop() {
	// Make sure to release the thread when done
	defer runtime.UnlockOSThread()

	for {
		select {
		case task := <-b.taskQueue:
			// Execute the task in the locked thread
			func() {
				defer func() {
					if r := recover(); r != nil {
						// Log recovery but don't crash the FFI thread
						log.Printf("Recovered from panic in FFI thread: %v", r)
					}
					// Always signal completion even if there was a panic
					close(task.complete)
				}()

				// Execute the task
				task.fn()
			}()
		case <-b.shutdown:
			log.Println("FFI bridge thread shutting down")
			b.isRunning = false
			return
		}
	}
}

// ExecuteOnFFIThread runs the given function on the FFI thread and waits for completion
func ExecuteOnFFIThread(fn func()) {
	// Initialize bridge if not already done
	InitializeFFIBridge()

	done := make(chan struct{})
	ffiBridge.taskQueue <- FFITask{
		fn:       fn,
		complete: done,
	}
	<-done // Wait for completion
}

// ExecuteOnFFIThreadAsync runs the given function on the FFI thread without waiting
func ExecuteOnFFIThreadAsync(fn func()) {
	// Initialize bridge if not already done
	InitializeFFIBridge()

	// We still need a channel for the recovery mechanism
	done := make(chan struct{})
	ffiBridge.taskQueue <- FFITask{
		fn:       fn,
		complete: done,
	}
	// Don't wait for completion
}

// ShutdownFFIBridge terminates the FFI bridge thread
func ShutdownFFIBridge() {
	if ffiBridge != nil && ffiBridge.isRunning {
		close(ffiBridge.shutdown)
	}
}
