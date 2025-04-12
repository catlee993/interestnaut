package openai

import (
	"context"
	"encoding/json"
	"fmt"
	"interestnaut/internal/llm"
	"interestnaut/internal/session"
	"net/http"
	"os"
	"regexp"
	"strings"

	request "github.com/catlee993/go-request"
)

const (
	apiURL = "https://api.openai.com/v1/chat/completions"
	model  = "gpt-4o"
)

type client[T session.Media] struct {
	apiKey     string
	httpClient *http.Client
}

type ChatRequest struct {
	Model   string      `json:"model"`
	Message llm.Message `json:"message"`
}

type ChatResponse struct {
	Choices []struct {
		Message llm.Message `json:"message"`
	} `json:"choices"`
}

// Regex to find JSON within ```json ... ``` fences.
// Handles potential leading/trailing whitespace around the JSON.
var jsonRegex = regexp.MustCompile("```json\\s*([\\s\\S]*?)\\s*```")

// extractJsonContent extracts raw JSON string, removing potential markdown fences.
func extractJsonContent(content string) string {
	match := jsonRegex.FindStringSubmatch(content)
	if len(match) > 1 {
		return strings.TrimSpace(match[1]) // Return the captured group (JSON part)
	}
	// If no fences, return the original content, trimmed
	return strings.TrimSpace(content)
}

func NewClient[T session.Media]() (llm.Client[T], error) {
	apiKey := os.Getenv("OPENAI_API_SECRET")
	if apiKey == "" {
		return nil, fmt.Errorf("OPENAI_API_SECRET environment variable not set")
	}

	return &client[T]{
		apiKey:     apiKey,
		httpClient: &http.Client{},
	}, nil
}

func (c *client[T]) ComposeMessage(ctx context.Context, content *session.Content[T]) (llm.Message, error) {
	val, err := content.ToString()
	if err != nil {
		return llm.Message{}, fmt.Errorf("failed to convert content to string: %w", err)
	}

	msg := llm.Message{
		Content: val,
	}

	return msg, nil
}

func (c *client[T]) SendMessage(ctx context.Context, msg llm.Message) (string, error) {
	reqBody := ChatRequest{
		Model:   model,
		Message: msg,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Post),
		request.WithHost("api.openai.com"),
		request.WithPath("v1", "chat", "completions"),
		request.WithBody(jsonData),
		request.WithHeaders(map[string][]string{
			"Content-Type":  {"application/json"},
			"Authorization": {"Bearer " + c.apiKey},
		}),
	)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	var chatResp ChatResponse
	_, err = req.Make(ctx, &chatResp)
	if err != nil {
		return "", fmt.Errorf("API request failed: %w", err)
	}

	if len(chatResp.Choices) == 0 {
		return "", fmt.Errorf("no response choices available")
	}

	// Extract clean JSON content before returning
	content := extractJsonContent(chatResp.Choices[0].Message.Content)
	return content, nil
}
