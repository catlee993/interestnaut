package openai

import (
	"context"
	"encoding/json"
	"fmt"
	"interestnaut/internal/creds"
	"interestnaut/internal/llm"
	"interestnaut/internal/session"
	"log"
	"net/http"
	"regexp"
	"strings"

	request "github.com/catlee993/go-request"
)

const (
	defaultModel  = "gpt-4o"
	roleSystem    = "system"
	roleUser      = "user"
	roleAssistant = "assistant"
)

type client[T session.Media] struct {
	apiKey     string
	httpClient *http.Client
	cm         session.CentralManager
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

func NewClient[T session.Media](cm session.CentralManager) (llm.Client[T], error) {
	apiKey, err := creds.GetOpenAIKey()
	if err != nil {
		return nil, fmt.Errorf("failed to get OpenAI API key from keychain: %w", err)
	}
	if apiKey == "" {
		return nil, fmt.Errorf("OpenAI API key not found in keychain")
	}

	return &client[T]{
		apiKey:     apiKey,
		httpClient: &http.Client{},
		cm:         cm,
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

func (c *client[T]) SendMessages(ctx context.Context, msgs ...llm.Message) (*llm.SuggestionResponse[T], error) {
	// Get the current model from settings if available
	modelToUse := defaultModel
	if c.cm != nil && c.cm.Settings() != nil {
		configModel := c.cm.Settings().GetChatGPTModel()
		if configModel != "" {
			modelToUse = configModel
		}
	}

	reqBody := ChatRequest{
		Model:    modelToUse,
		Messages: msgs,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
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
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	var chatResp ChatResponse
	_, err = req.Make(ctx, &chatResp)
	if err != nil {
		// Check if the error is a rate limit error
		if strings.Contains(err.Error(), "rate_limit_exceeded") {
			// Extract the original error message
			var apiError struct {
				Error struct {
					Message string `json:"message"`
					Type    string `json:"type"`
					Code    string `json:"code"`
				} `json:"error"`
			}
			if jsonErr := json.Unmarshal([]byte(err.Error()), &apiError); jsonErr == nil && apiError.Error.Message != "" {
				return nil, fmt.Errorf("failed to get suggestion from LLM: %s", apiError.Error.Message)
			}
		}
		return nil, fmt.Errorf("failed to get suggestion from LLM: %w", err)
	}

	if len(chatResp.Choices) == 0 {
		return nil, fmt.Errorf("no response choices available")
	}

	// Extract clean JSON content
	content := extractJsonContent(chatResp.Choices[0].Message.GetContent())

	// Store the original raw response
	rawResponse := chatResp.Choices[0].Message.GetContent()

	// Parse the response into our generic type
	suggestion, err := llm.ParseSuggestionFromString[T](content)
	if err != nil {
		errSuggest := &llm.SuggestionResponse[T]{
			RawResponse: rawResponse,
		}
		log.Printf("WARNING: Failed to parse JSON response: %v. Content: %s", err, content)
		return errSuggest, fmt.Errorf("failed to parse suggestion: %w", err)
	}

	// Store the raw response in the suggestion
	suggestion.RawResponse = rawResponse

	return suggestion, nil
}

func (c *client[T]) ErrorFollowup(ctx context.Context, resp *llm.SuggestionResponse[T], msgs ...llm.Message) (*llm.SuggestionResponse[T], error) {
	// Create an error message
	errorMsg := &Message{
		Role:    roleSystem,
		Content: "Your previous response was not the requested valid JSON or did not adhere to the rules. Please observe the following and correct your response:",
	}

	// Add original messages
	allMessages := []llm.Message{errorMsg}
	allMessages = append(allMessages, msgs...)

	// Add the error indication
	errorResponseMsg := &Message{
		Role:    roleAssistant,
		Content: "My previous response (which was incorrect):\n```\n" + resp.RawResponse + "\n```",
	}
	allMessages = append(allMessages, errorResponseMsg)

	// Add a clarification message
	clarificationMsg := &Message{
		Role:    roleSystem,
		Content: "Please provide a single valid JSON object with the expected structure. Do not include any text outside the JSON object, and ensure all fields are present and correctly formatted.",
	}
	allMessages = append(allMessages, clarificationMsg)

	// Retry the request
	return c.SendMessages(ctx, allMessages...)
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
