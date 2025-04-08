package openai

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"strings"
)

const (
	apiURL = "https://api.openai.com/v1/chat/completions"
	model  = "gpt-4o"
)

type Client struct {
	apiKey     string
	httpClient *http.Client
}

type ChatRequest struct {
	Model    string    `json:"model"`
	Messages []Message `json:"messages"`
}

type ChatResponse struct {
	Choices []struct {
		Message Message `json:"message"`
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

func NewClient() (*Client, error) {
	apiKey := os.Getenv("OPENAI_API_SECRET")
	if apiKey == "" {
		return nil, fmt.Errorf("OPENAI_API_SECRET environment variable not set")
	}

	return &Client{
		apiKey:     apiKey,
		httpClient: &http.Client{},
	}, nil
}

func (c *Client) SendMessage(messages []Message) (Message, error) {
	reqBody := ChatRequest{
		Model:    model,
		Messages: messages,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return Message{}, fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequest("POST", apiURL, bytes.NewBuffer(jsonData))
	if err != nil {
		return Message{}, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+c.apiKey)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return Message{}, fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return Message{}, fmt.Errorf("failed to read response body: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return Message{}, fmt.Errorf("API request failed with status %d: %s", resp.StatusCode, string(body))
	}

	var chatResp ChatResponse
	if err := json.Unmarshal(body, &chatResp); err != nil {
		return Message{}, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	if len(chatResp.Choices) == 0 {
		return Message{}, fmt.Errorf("no response choices available")
	}

	// Extract clean JSON content before returning
	finalMessage := chatResp.Choices[0].Message
	finalMessage.Content = extractJsonContent(finalMessage.Content)

	return finalMessage, nil
}
