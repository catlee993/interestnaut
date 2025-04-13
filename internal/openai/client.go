package openai

import (
	"context"
	"encoding/json"
	"fmt"
	"interestnaut/internal/llm"
	"interestnaut/internal/session"
	"log"
	"net/http"
	"os"
	"regexp"
	"strings"

	request "github.com/catlee993/go-request"
)

const (
	model         = "gpt-4o"
	roleSystem    = "system"
	roleUser      = "user"
	roleAssistant = "assistant"
)

type client[T session.Media] struct {
	apiKey     string
	httpClient *http.Client
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
	trimmed := strings.TrimSpace(content)
	if !strings.HasPrefix(trimmed, "{") || !strings.HasSuffix(trimmed, "}") {
		log.Print("WARNING: JSON response does not start and end with braces. Attempting to fix.")
		trimmed = "{" + trimmed + "}"
	}

	return trimmed
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

func (c *client[T]) ComposeMessages(_ context.Context, content *session.Content[T]) ([]llm.Message, error) {
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

func (c *client[T]) SendMessages(ctx context.Context, msgs ...llm.Message) (string, error) {
	reqBody := ChatRequest{
		Model:    model,
		Messages: msgs,
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
	content := extractJsonContent(chatResp.Choices[0].Message.GetContent())
	return content, nil
}

func formatSuggestion[T session.Media](suggestion session.Suggestion[T]) string {
	switch media := any(suggestion.Content).(type) {
	case session.Music:
		return fmt.Sprintf("Suggested song:\nTitle: %s\nArtist: %s\nAlbum: %s\nUser Outcome: %s",
			suggestion.Title, media.Artist, media.Album, suggestion.UserOutcome)
	default:
		return fmt.Sprintf("Suggested item: %s\nReasoning: %s", suggestion.Title, suggestion.Reasoning)
	}
}
