package main

/*
#cgo CFLAGS: -I${SRCDIR}/../../internal/app/ffi
#include <stdlib.h>
*/
import "C"
import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	// Setup signal handling for graceful shutdown
	setupSignalHandling()

	fmt.Println("Interestnaut FFI service started")
	// Main service logic would go here
	
	// Keep the process running until we receive a signal
	select {}
}

// setupSignalHandling configures signal handling for graceful shutdown
func setupSignalHandling() {
	signalChan := make(chan os.Signal, 1)
	signal.Notify(signalChan, syscall.SIGINT, syscall.SIGTERM)
	
	go func() {
		sig := <-signalChan
		fmt.Printf("Received signal: %s\n", sig)
		fmt.Println("Shutting down gracefully...")
		os.Exit(0)
	}()
}
