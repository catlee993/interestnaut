package mistral

import (
	"context"
	"errors"
	"fmt"
	"interestnaut/internal/app/llama"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"interestnaut/internal/app/llm"
	"interestnaut/internal/app/session"
)

const downloadURL = "https://interestnaut.com/Mistral-7B-Instruct-v0.3-q4_1.gguf"
const modelName = "Mistral-7B-Instruct-v0.3-q4_1.gguf"

const (
	maxTokens   = 4096
	temperature = 0.7
)

const (
	roleSystem    = "system"
	roleUser      = "user"
	roleAssistant = "assistant"
)

type MClient[T session.Media] struct {
	cm          session.CentralManager
	model       *llama.Model
	context     *llama.Context
	initialized bool
	mu          sync.Mutex
}

// DefaultClient is the global instance of the client, should be used for most operations.
var DefaultClient *MClient[session.Music]

// MusicClient is the music client
func MusicClient(cm session.CentralManager) *MClient[session.Music] {
	if DefaultClient == nil {
		DefaultClient = &MClient[session.Music]{cm: cm}
	}
	return DefaultClient
}

var mutex = &sync.Mutex{}

// Initialize sets up the model and creates a context
func (c *MClient[T]) Initialize(modelDir string) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.initialized {
		return nil
	}

	// Make sure model directory exists
	if err := os.MkdirAll(modelDir, 0755); err != nil {
		return fmt.Errorf("failed to create model directory: %w", err)
	}

	// Construct the model path
	modelPath := filepath.Join(modelDir, modelName)

	// Download the model if it doesn't exist
	if _, err := os.Stat(modelPath); os.IsNotExist(err) {
		if err := DownloadGGUF(modelPath); err != nil {
			return fmt.Errorf("failed to download model: %w", err)
		}
	}

	// Initialize the llama library
	if err := llama.Initialize(); err != nil {
		return fmt.Errorf("failed to initialize llama: %w", err)
	}

	// Load the model
	model, err := llama.LoadModel(modelPath)
	if err != nil {
		return fmt.Errorf("failed to load model: %w", err)
	}
	c.model = model

	// Create a context for inference
	context, err := model.CreateContext()
	if err != nil {
		return fmt.Errorf("failed to create context: %w", err)
	}
	c.context = context

	c.initialized = true
	return nil
}

// DownloadGGUF fetches the file from `url` and writes it to destPath.
func DownloadGGUF(modelPath string) error {
	mutex.Lock()
	defer mutex.Unlock()

	if exists, _ := os.Stat(modelPath); exists != nil {
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
	if err := os.MkdirAll(filepath.Dir(modelPath), 0o755); err != nil {
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

	if _, err := io.Copy(f, resp.Body); err != nil {
		return fmt.Errorf("write file: %w", err)
	}
	return nil
}

func HandleNewSuggestion() (*llm.SuggestionResponse[session.Music], error) {
	c := DefaultClient
	messages, mErr := c.ComposeMessages(context.Background(), nil)
	if mErr != nil {
		return nil, fmt.Errorf("compose messages: %w", mErr)
	}

	res, rErr := c.SendMessages(context.Background(), messages...)
	if rErr != nil {
		return nil, fmt.Errorf("send messages: %w", rErr)
	}

	return res, nil
}

// runGGUF runs the prompt through the loaded model
func (c *MClient[T]) runGGUF(message string) (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if !c.initialized {
		return "", fmt.Errorf("mistral client not initialized")
	}

	// Format prompt for Mistral
	formattedPrompt := formatPrompt(message)

	// Generate completion
	completion, err := c.context.Complete(formattedPrompt, maxTokens)
	if err != nil {
		return "", fmt.Errorf("completion error: %w", err)
	}

	if completion == "" {
		return "", errors.New("no output generated from model")
	}

	return completion, nil
}

// formatPrompt formats a prompt for Mistral
func formatPrompt(prompt string) string {
	return fmt.Sprintf("<s>[INST] %s [/INST]", strings.TrimSpace(prompt))
}

func (c *MClient[T]) ComposeMessages(_ context.Context, content *session.Content[T]) ([]llm.Message, error) {
	if content == nil {
		return nil, fmt.Errorf("content cannot be nil")
	}

	msg := &Message{
		Role:    roleSystem,
		Content: content.PrimeDirective.Task + "\n" + content.PrimeDirective.Baseline,
	}

	for _, suggestion := range content.Suggestions {
		msg.Content += "\n" + formatSuggestion(suggestion)
	}
	msgs := []llm.Message{msg}

	for _, constraint := range content.UserConstraints {
		msgs = append(msgs, &Message{
			Role:    roleUser,
			Content: constraint,
		})
	}

	return msgs, nil
}

func (c *MClient[T]) SendMessages(_ context.Context, msgs ...llm.Message) (*llm.SuggestionResponse[T], error) {
	var sb strings.Builder
	for _, msg := range msgs {
		sb.WriteString(msg.GetContent())
		sb.WriteString("\n")
	}

	output, err := c.runGGUF(sb.String())
	if err != nil {
		return nil, fmt.Errorf("run model: %w", err)
	}

	return llm.ParseSuggestionFromString[T](output)
}

// Close releases resources
func (c *MClient[T]) Close() {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.model != nil {
		c.model.Free()
		c.model = nil
	}

	if c.context != nil {
		c.context.Free()
		c.context = nil
	}

	c.initialized = false
}

func formatSuggestion[T session.Media](suggestion session.Suggestion[T]) string {
	switch media := any(suggestion.Content).(type) {
	case session.Music:
		return fmt.Sprintf("Suggested song:\nTitle: %s\nArtist: %s\nAlbum: %s\nUser Outcome: %s",
			media.Title, media.Artist, media.Album, suggestion.UserOutcome)
	case session.Movie:
		return fmt.Sprintf("Suggested movie:\nTitle: %s\nDirector: %s\nWriter: %s\nUser Outcome: %s",
			media.Title, media.Director, media.Writer, suggestion.UserOutcome)
	case session.Book:
		return fmt.Sprintf("Suggested book:\nTitle: %s\nAuthor: %s\nUser Outcome: %s",
			media.Title, media.Author, suggestion.UserOutcome)
	case session.TVShow:
		return fmt.Sprintf("Suggested TV show:\nTitle: %s\nDirector: %s\nWriter: %s\nUser Outcome: %s",
			media.Title, media.Director, media.Writer, suggestion.UserOutcome)
	case session.VideoGame:
		return fmt.Sprintf("Suggested video game:\nTitle: %s\nDeveloper: %s\nPublisher: %s\nUser Outcome: %s",
			media.Title, media.Developer, media.Publisher, suggestion.UserOutcome)
	default:
		return fmt.Sprintf("Reasoning: %s", suggestion.Reasoning)
	}
}
