package minstral

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/go-skynet/go-llama.cpp"
)

const downloadURL = "https://interestnaut.com/Mistral-7B-Instruct-v0.3-q4_1.gguf"

// DownloadGGUF fetches the file from `url` and writes it to destPath.
// If HF_TOKEN is in the env, it will be sent as a Bearer token.
func DownloadGGUF(ctx context.Context, destPath string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, downloadURL, nil)
	if err != nil {
		return fmt.Errorf("construct request: %w", err)
	}
	if token := os.Getenv("HF_TOKEN"); token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("download request: %w", err)
	}
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("bad status downloading model: %s", resp.Status)
	}
	defer func() {
		if cerr := resp.Body.Close(); cerr != nil {
			log.Printf("close response body: %v", cerr)
		}
	}()

	// ensure directory exists
	if err := os.MkdirAll(filepath.Dir(destPath), 0o755); err != nil {
		return fmt.Errorf("mkdir: %w", err)
	}
	f, err := os.Create(destPath)
	if err != nil {
		return fmt.Errorf("create file: %w", err)
	}
	defer func() {
		if cerr := f.Close(); cerr != nil {
			log.Printf("close file: %v", cerr)
		}
	}()

	if _, err := io.Copy(f, resp.Body); err != nil {
		return fmt.Errorf("write file: %w", err)
	}
	return nil
}

// RunGGUF loads a .gguf model at modelPath, runs `prompt` through it, and returns the generated output.
// It works with iOS-compatible models and recent versions of go-llama.cpp.
func RunGGUF(ctx context.Context, modelPath, prompt string, maxTokens int, temperature float32) (string, error) {
	// Set default max tokens if not specified
	if maxTokens <= 0 {
		maxTokens = 512
	}

	// Set default temperature if not specified
	if temperature <= 0 {
		temperature = 0.7
	}

	// Load the model with minimal required options for broader compatibility
	// Following the exact pattern from the examples
	l, err := llama.New(modelPath,
		llama.EnableF16Memory,  // Enable F16 memory for better performance and iOS compatibility
		llama.SetContext(2048), // Set a reasonable context size
		llama.SetGPULayers(0))  // Use CPU only by default for iOS compatibility

	if err != nil {
		return "", fmt.Errorf("loading model: %w", err)
	}
	defer l.Free() // Properly free resources when done

	// Create a string builder to collect tokens
	var result strings.Builder

	// Run prediction with appropriate options - following exact pattern from example
	_, err = l.Predict(
		prompt,
		llama.SetTokenCallback(func(token string) bool {
			result.WriteString(token)
			return true
		}),
		llama.SetTokens(maxTokens),
		llama.SetThreads(4),
		llama.SetTemperature(temperature),
		llama.SetTopK(40),
		llama.SetTopP(0.95),
		llama.SetStopWords("\n\n", "```"),
	)

	if err != nil {
		return "", fmt.Errorf("prediction error: %w", err)
	}

	output := result.String()
	if output == "" {
		return "", errors.New("no output generated from model")
	}

	return output, nil
}
