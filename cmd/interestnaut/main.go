package main

/*
#cgo CFLAGS: -I${SRCDIR}/../../dependencies/llama.cpp/include -I${SRCDIR}/../../dependencies/llama.cpp/common -I${SRCDIR}/../../dependencies/llama.cpp/ggml/include -I${SRCDIR}/../../internal/llama
#cgo LDFLAGS: -L${SRCDIR}/../../dependencies/llama.cpp/build -lllama -lstdc++ -lm -framework Accelerate -framework Foundation -framework Metal
#include "llama_wrapper.h"
#include <stdlib.h>
*/
import "C"
import (
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"unsafe"
)

func main() {
	// Setup signal handling for graceful shutdown
	setupSignalHandling()

	// Use environment variable for model path or use a default
	modelPath := os.Getenv("LLAMA_MODEL_PATH")
	if modelPath == "" {
		modelPath = "models/llama-2-7b-chat.gguf" // Default model path
	}

	// Test the llama integration
	fmt.Println("Testing llama.cpp integration...")
	testLlamaIntegration(modelPath)
}

// testLlamaIntegration tests the integration with llama.cpp
func testLlamaIntegration(modelPath string) {
	fmt.Printf("Loading model from: %s\n", modelPath)

	// Simple prompt for testing
	prompt := "Hello, I am an AI assistant. How can I help you today?"
	
	// Call our wrapper function to generate text
	cModelPath := C.CString(modelPath)
	cPrompt := C.CString(prompt)
	defer C.free(unsafe.Pointer(cModelPath))
	defer C.free(unsafe.Pointer(cPrompt))
	
	fmt.Println("Generating response...")
	cResult := C.GoLlamaGenerate(cModelPath, cPrompt, C.int(100))
	
	if cResult == nil {
		fmt.Println("Error: Failed to generate text")
		return
	}
	
	// Convert the C string to a Go string and free the C memory
	result := C.GoString(cResult)
	C.free(unsafe.Pointer(cResult))
	
	fmt.Println("Generated response:")
	fmt.Println(result)
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
