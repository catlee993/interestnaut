package gemini

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
	defaultModel = "gemini-1.5-pro" // Default model if not specified in settings
)

type client[T session.Media] struct {
	apiKey     string
	httpClient *http.Client
	model      string
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

// NewClient creates a new Gemini client implementing the llm.Client interface
func NewClient[T session.Media](cm session.CentralManager) (llm.Client[T], error) {
	apiKey, err := creds.GetGeminiKey()
	if err != nil {
		return nil, fmt.Errorf("failed to get Gemini API key from keychain: %w", err)
	}
	if apiKey == "" {
		return nil, fmt.Errorf("Gemini API key not found in keychain")
	}

	return &client[T]{
		apiKey:     apiKey,
		httpClient: &http.Client{},
		model:      defaultModel,
		cm:         cm,
	}, nil
}

// ComposeMessages implements the llm.Client interface
func (c *client[T]) ComposeMessages(_ context.Context, content *session.Content[T]) ([]llm.Message, error) {
	if content == nil {
		return nil, fmt.Errorf("content cannot be nil")
	}

	// Start with a system message (in Gemini, this is still a user message, but with special prefix)
	systemContent := content.PrimeDirective.Task + "\n" + content.PrimeDirective.Baseline
	msgs := []llm.Message{&Message{
		Role:    RoleUser, // Gemini doesn't support "system" role as role, use user instead
		Content: systemContent,
	}}

	// Add previous suggestions
	for _, suggestion := range content.Suggestions {
		msgs = append(msgs, &Message{
			Role:    RoleUser,
			Content: formatSuggestion(suggestion),
		})
	}

	// Add user constraints
	for _, constraint := range content.UserConstraints {
		msgs = append(msgs, &Message{
			Role:    RoleUser,
			Content: constraint,
		})
	}

	return msgs, nil
}

// SendMessages implements the llm.Client interface
func (c *client[T]) SendMessages(ctx context.Context, msgs ...llm.Message) (*llm.SuggestionResponse[T], error) {
	// Convert messages to Gemini format
	contents := make([]map[string]interface{}, 0, len(msgs))

	for _, msg := range msgs {
		geminiMsg := ConvertMessage(msg)

		// Create proper content structure
		part := map[string]interface{}{
			"text": geminiMsg.Content,
		}

		content := map[string]interface{}{
			"role":  geminiMsg.Role,
			"parts": []map[string]interface{}{part},
		}

		contents = append(contents, content)
	}

	// Build request body
	reqBody := map[string]interface{}{
		"contents": contents,
	}

	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	// Get the current model from settings if available
	modelToUse := c.model
	if c.cm != nil && c.cm.Settings() != nil {
		modelToUse = c.cm.Settings().GetGeminiModel()
	}

	// Create request to Gemini API
	req, err := request.NewRequester(
		request.WithScheme(request.HTTPS),
		request.WithMethod(request.Post),
		request.WithHost("generativelanguage.googleapis.com"),
		request.WithPath("v1", "models", modelToUse+":generateContent"),
		request.WithQueryArgs(map[string][]string{
			"key": {c.apiKey},
		}),
		request.WithBody(jsonData),
		request.WithHeaders(map[string][]string{
			"Content-Type": {"application/json"},
		}),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	var geminiResp ChatResponse
	_, err = req.Make(ctx, &geminiResp)
	if err != nil {
		return nil, fmt.Errorf("failed to get suggestion from Gemini: %w", err)
	}

	if len(geminiResp.Candidates) == 0 {
		return nil, fmt.Errorf("no response candidates available")
	}

	// Get text content from the response
	var contentText string
	if len(geminiResp.Candidates[0].Content.Parts) > 0 {
		contentText = geminiResp.Candidates[0].Content.Parts[0].Text
	}

	// Extract clean JSON content
	jsonContent := extractJsonContent(contentText)

	// Store the original raw response
	rawResponse := contentText

	// Parse the response into our generic type
	suggestion, err := llm.ParseSuggestionFromString[T](jsonContent)
	if err != nil {
		errSuggest := &llm.SuggestionResponse[T]{
			RawResponse: rawResponse,
		}
		log.Printf("WARNING: Failed to parse JSON response: %v. Content: %s", err, jsonContent)
		return errSuggest, fmt.Errorf("failed to parse suggestion: %w", err)
	}

	// Store the raw response in the suggestion
	suggestion.RawResponse = rawResponse

	return suggestion, nil
}

// ErrorFollowup implements the llm.Client interface
func (c *client[T]) ErrorFollowup(ctx context.Context, resp *llm.SuggestionResponse[T], msgs ...llm.Message) (*llm.SuggestionResponse[T], error) {
	// Create an error message
	errorMsg := &Message{
		Role:    RoleUser, // Gemini uses user role for system messages
		Content: "Your previous response was not the requested valid JSON or did not adhere to the rules. Please observe the following and correct your response:",
	}

	// Add original messages
	allMessages := []llm.Message{errorMsg}
	allMessages = append(allMessages, msgs...)

	// Add the error indication
	errorResponseMsg := &Message{
		Role:    RoleModel, // Show as model response
		Content: "My previous response (which was incorrect):\n```\n" + resp.RawResponse + "\n```",
	}
	allMessages = append(allMessages, errorResponseMsg)

	// Add a clarification message
	clarificationMsg := &Message{
		Role:    RoleUser,
		Content: "Please provide a single valid JSON object with the expected structure. Do not include any text outside the JSON object, and ensure all fields are present and correctly formatted. Remember to follow the JSON format exactly as specified in the initial instructions.",
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
