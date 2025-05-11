package server

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"time"
)

// Start initializes and starts the HTTP server; this is currently only used to respond
// to Spotify's auth code callback to exchange for a token; should be short-lived,
// and shouldn't run when a refresh token is available in the keychain.
//
// This implementation is fully synchronous and blocking - it doesn't spawn any goroutines
// that outlive the function call, making it compatible with iOS App Store requirements.
func Start(ctx context.Context, stop <-chan struct{}, handler http.Handler) error {
	srv := &http.Server{
		Addr:    ":8080",
		Handler: handler,
	}

	// Use error channels for synchronous error handling
	serverErrChan := make(chan error, 1)

	// This is the only goroutine, and it's guaranteed to be cleaned up when this function returns
	// because we explicitly call Shutdown() before returning
	go func() {
		log.Println("Server listening on http://localhost:8080")
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErrChan <- err
		}
	}()

	// Block and wait for a signal to stop or an error
	var err error
	select {
	case <-stop:
		log.Println("Received stop signal")
	case err = <-serverErrChan:
		log.Printf("Server error: %v", err)
	case <-ctx.Done():
		log.Println("Context canceled")
	}

	// Shutdown the server gracefully regardless of how we got here
	log.Println("Shutting down server...")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if shutdownErr := srv.Shutdown(shutdownCtx); shutdownErr != nil {
		if err != nil {
			// Combine errors if we already had one
			return fmt.Errorf("multiple errors: server: %v, shutdown: %v", err, shutdownErr)
		}
		return fmt.Errorf("server shutdown failed: %w", shutdownErr)
	}

	log.Println("Server exited properly")
	return err
}
