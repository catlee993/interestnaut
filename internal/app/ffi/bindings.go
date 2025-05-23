// Package ffi provides FFI bindings for Interestnaut, handling the communication
// between Flutter and Go.
package ffi

/*
#include <stdlib.h>
*/
import "C"
import (
	"context"
	"encoding/json"
	"fmt"
	"interestnaut/internal/app/spotify"
	"log"
	"unsafe"
)

//export FreeString
func FreeString(s *C.char) {
	C.free(unsafe.Pointer(s))
}

//export Music_InitiateSpotifyAuth
func Music_InitiateSpotifyAuth(port C.int) *C.char {
	var result *C.char

	// Call the simplified version that just opens the browser, passing the port
	err := initiateSpotifyAuth(int(port))
	if err != nil {
		log.Printf("Music_InitiateSpotifyAuth failed: %v", err)
		errorJson, _ := json.Marshal(map[string]interface{}{
			"error": err.Error(),
		})
		result = C.CString(string(errorJson))
		return result
	}

	// Return success message
	result = C.CString("{\"status\": \"Spotify auth initiated successfully\"}")
	return result
}

func initiateSpotifyAuth(port int) error {
	log.Printf("Explicitly initiating Spotify authentication flow with port %d", port)

	// Validate that the port is one of the registered ports
	if !spotify.IsRegisteredPort(port) {
		return fmt.Errorf("port %d is not registered in the Spotify Developer Dashboard", port)
	}

	// Open the browser with the auth URL but don't set up a server or handle callback
	err := spotify.OpenSpotifyAuthBrowser(context.Background(), port)
	if err != nil {
		log.Printf("ERROR: Failed to open Spotify auth browser: %v", err)
		return err
	}

	log.Println("Browser opened with Spotify auth URL - Flutter will handle the callback")

	// No need to return anything, the code verifier is stored in the spotify package
	return nil
}
