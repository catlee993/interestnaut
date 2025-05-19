package mistral

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
)

const downloadURL = "https://interestnaut.com/Mistral-7B-Instruct-v0.3-q4_1.gguf"
const modelName = "Mistral-7B-Instruct-v0.3-q4_1.gguf"

type MClient struct {
	hasClient atomic.Bool
	mu        sync.Mutex
}

// DefaultClient is the global instance of the client, should be used for most operations.
var DefaultClient = &MClient{}

// DownloadGGUF fetches the file from `url` and writes it to destPath.
func DownloadGGUF(modelDir string) error {
	DefaultClient.mu.Lock()
	defer DefaultClient.mu.Unlock()

	modelPath := filepath.Join(modelDir, modelName)

	if exists, _ := os.Stat(modelPath); exists != nil {
		log.Printf("Model file already exists at %s, skipping download.", modelPath)
		if DefaultClient.hasClient.Load() == false {
			DefaultClient.hasClient.Store(true)
		}
		return nil
	}

	// Download using HTTP client
	req, err := http.NewRequestWithContext(context.Background(), http.MethodGet, downloadURL, nil)
	if err != nil {
		return fmt.Errorf("construct request: %w", err)
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
	if err := os.MkdirAll(filepath.Dir(modelDir), 0o755); err != nil {
		return fmt.Errorf("mkdir: %w", err)
	}
	f, err := os.Create(modelPath)
	if err != nil {
		return fmt.Errorf("create file: %w", err)
	}
	defer func() {
		if cerr := f.Close(); cerr != nil {
			log.Printf("close file: %v", cerr)
		}
	}()

	if _, cErr := io.Copy(f, resp.Body); cErr != nil {
		return fmt.Errorf("write file: %w", cErr)
	}

	DefaultClient.hasClient.Store(true)

	return nil
}

func HasModel() bool {
	return DefaultClient.hasClient.Load()
}
