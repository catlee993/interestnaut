package bridge

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

import (
	"log"
	"runtime"
)

// FFITask represents a unit of work to be executed on the FFI thread
type FFITask struct {
	fn       func()
	complete chan struct{}
}

// FFIBridge provides a dedicated thread for FFI operations
type FFIBridge struct {
	taskQueue chan FFITask
	shutdown  chan struct{}
	isRunning bool
}

// NewFFIBridge creates a new FFIBridge instance
func NewFFIBridge() *FFIBridge {
	b := &FFIBridge{
		taskQueue: make(chan FFITask, 100),
		shutdown:  make(chan struct{}),
		isRunning: true,
	}
	go b.run()
	return b
}

// run starts the dedicated FFI thread event loop
func (b *FFIBridge) run() {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	C.configure_thread_signals()
	C.set_thread_priority_high()
	b.eventLoop()
}

// Execute runs the given function on the FFI thread and waits for completion
func (b *FFIBridge) Execute(fn func()) {
	done := make(chan struct{})
	b.taskQueue <- FFITask{
		fn:       fn,
		complete: done,
	}
	<-done
}

// ExecuteAsync runs the given function on the FFI thread without waiting
func (b *FFIBridge) ExecuteAsync(fn func()) {
	done := make(chan struct{})
	b.taskQueue <- FFITask{
		fn:       fn,
		complete: done,
	}
}

// Shutdown terminates the FFI bridge thread
func (b *FFIBridge) Shutdown() {
	if b.isRunning {
		close(b.shutdown)
	}
}

// eventLoop is the core FFI thread that handles all cross-boundary calls
func (b *FFIBridge) eventLoop() {
	for {
		select {
		case task := <-b.taskQueue:
			func() {
				defer func() {
					if r := recover(); r != nil {
						log.Printf("Recovered from panic in FFI thread: %v", r)
					}
					close(task.complete)
				}()
				task.fn()
			}()
		case <-b.shutdown:
			log.Println("FFI bridge thread shutting down")
			b.isRunning = false
			return
		}
	}
}
