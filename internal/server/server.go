package server

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func Start(ctx context.Context, stop <-chan struct{}, handler http.Handler) error {
	srv := &http.Server{
		Addr:    ":8080",
		Handler: handler,
	}

	// Listen for system interrupts for graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	// Channel to communicate server errors
	errChan := make(chan error, 1)

	go func() {
		log.Println("Server listening on http://localhost:8080")
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			errChan <- fmt.Errorf("ListenAndServe error: %w", err)
		}
	}()

	// Wait for stop signal or error
	select {
	case <-stop:
		log.Println("Received stop signal")
	case <-sigChan:
		log.Println("Received OS interrupt signal")
	case err := <-errChan:
		return err
	}

	cCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(cCtx); err != nil {
		return fmt.Errorf("Server Shutdown Failed: %w", err)
	}
	log.Println("Server exited properly")
	return nil
}
