package minstral

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"interestnaut/internal/app/llm"
	"interestnaut/internal/app/session"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/go-skynet/go-llama.cpp"
)

const downloadURL = "https://interestnaut.com/Mistral-7B-Instruct-v0.3-q4_1.gguf"

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
	cm        session.CentralManager
	modelPath string
}

type minstralResponse struct {
	Title  string `json:"title"`
	Artist string `json:"artist"`
}

var DefaultClient = &MClient[session.Media]{}

func SetCentralManager[T session.Media](c *MClient[T], cm session.CentralManager) {
	c.cm = cm
}

func (c *MClient[T]) HasModel() bool {
	if c.modelPath == "" {
		return false
	}
	if _, err := os.Stat(c.modelPath); os.IsNotExist(err) {
		return false
	}

	return true
}

var mutex = &sync.Mutex{}

// DownloadGGUF fetches the file from `url` and writes it to destPath.
// If HF_TOKEN is in the env, it will be sent as a Bearer token.
func DownloadGGUF(modelPath string) error {
	mutex.Lock()
	defer mutex.Unlock()
	if exists, _ := os.Stat(modelPath); exists != nil {
		return nil
	}

	if DefaultClient.modelPath == "" {
		DefaultClient.modelPath = modelPath
	}
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

func (c *MClient[T]) HandleNewSuggestion() (*llm.SuggestionResponse[T], error) {
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

// RunGGUF loads a .gguf model at modelPath, runs `prompt` through it, and returns the generated output.
// It works with iOS-compatible models and recent versions of go-llama.cpp.
func (c *MClient[T]) runGGUF(message string) (string, error) {
	// Load the model with minimal required options for broader compatibility
	// Following the exact pattern from the examples
	l, err := llama.New(c.modelPath,
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
		message,
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

// GetContent implements the llm.Message interface
func (m *Message) GetContent() string {
	return m.Content
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

	// Attempt to parse the output as JSON
	var suggestion minstralResponse
	if uErr := json.Unmarshal([]byte(output), &suggestion); uErr != nil {
		return nil, fmt.Errorf("unmarshal response: %w", uErr)
	}

	return &llm.SuggestionResponse[T]{
		Title:  suggestion.Title,
		Artist: suggestion.Artist,
	}, nil
}

func (c *MClient[T]) ErrorFollowup(_ context.Context, _ *llm.SuggestionResponse[T], _ ...llm.Message) (*llm.SuggestionResponse[T], error) {
	fmt.Printf("Error followup not implemented for Mistral MClient")
	return nil, nil
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
