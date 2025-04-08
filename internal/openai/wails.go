package openai

import (
	"context"
	"fmt"
	"strings"
)

type WailsClient struct {
	client  *Client
	session *SessionManager
}

func NewWailsClient() (*WailsClient, error) {
	client, err := NewClient()
	if err != nil {
		return nil, fmt.Errorf("failed to create OpenAI client: %w", err)
	}

	session, err := NewSessionManager()
	if err != nil {
		return nil, fmt.Errorf("failed to create session manager: %w", err)
	}

	return &WailsClient{
		client:  client,
		session: session,
	}, nil
}

func (w *WailsClient) SendMessage(ctx context.Context, userID string, content string) (string, error) {
	// Add user message to session
	if err := w.session.AddMessage(userID, Message{
		Role:    "user",
		Content: content,
	}); err != nil {
		return "", fmt.Errorf("failed to add message to session: %w", err)
	}

	// Get conversation history
	messages, err := w.session.GetMessages(userID)
	if err != nil {
		return "", fmt.Errorf("failed to get messages: %w", err)
	}

	// Send to OpenAI
	response, err := w.client.SendMessage(messages)
	if err != nil {
		return "", fmt.Errorf("failed to send message: %w", err)
	}

	// Add assistant response to session
	if err := w.session.AddMessage(userID, response); err != nil {
		return "", fmt.Errorf("failed to add response to session: %w", err)
	}

	return response.Content, nil
}

func (w *WailsClient) GetConversationHistory(ctx context.Context, userID string) ([]Message, error) {
	return w.session.GetMessages(userID)
}

// AnalyzeMusicPreferences analyzes the user's saved tracks and returns a summary of their music preferences
func (w *WailsClient) AnalyzeMusicPreferences(ctx context.Context, userID string, savedTracks []map[string]interface{}) (string, error) {
	// Format the saved tracks for analysis
	var tracksInfo strings.Builder
	tracksInfo.WriteString("Here are the user's saved tracks:\n\n")

	for i, track := range savedTracks {
		if i >= 20 { // Limit to 20 tracks to avoid token limits
			tracksInfo.WriteString("... and more tracks\n")
			break
		}

		name, _ := track["name"].(string)
		artist, _ := track["artist"].(string)
		album, _ := track["album"].(string)

		tracksInfo.WriteString(fmt.Sprintf("%d. \"%s\" by %s (Album: %s)\n", i+1, name, artist, album))
	}

	// Create a message to analyze preferences
	analysisPrompt := fmt.Sprintf("Based on the following saved tracks, analyze the user's music preferences including genres, artists, and musical style. Provide a concise summary:\n\n%s", tracksInfo.String())

	// Add the analysis request to the session
	if err := w.session.AddMessage(userID, Message{
		Role:    "user",
		Content: analysisPrompt,
	}); err != nil {
		return "", fmt.Errorf("failed to add analysis request: %w", err)
	}

	// Get conversation history
	messages, err := w.session.GetMessages(userID)
	if err != nil {
		return "", fmt.Errorf("failed to get messages: %w", err)
	}

	// Send to OpenAI
	response, err := w.client.SendMessage(messages)
	if err != nil {
		return "", fmt.Errorf("failed to analyze preferences: %w", err)
	}

	// Add assistant response to session
	if err := w.session.AddMessage(userID, response); err != nil {
		return "", fmt.Errorf("failed to add analysis response: %w", err)
	}

	return response.Content, nil
}

// GetSongSuggestion asks ChatGPT to suggest a song based on the user's preferences
func (w *WailsClient) GetSongSuggestion(ctx context.Context, userID string) (string, error) {
	// Create a message to request a song suggestion
	suggestionPrompt := "Based on my music preferences, suggest a song I might like. Please provide the song name and artist only, in the format 'Song Name - Artist'."

	// Add the suggestion request to the session
	if err := w.session.AddMessage(userID, Message{
		Role:    "user",
		Content: suggestionPrompt,
	}); err != nil {
		return "", fmt.Errorf("failed to add suggestion request: %w", err)
	}

	// Get conversation history
	messages, err := w.session.GetMessages(userID)
	if err != nil {
		return "", fmt.Errorf("failed to get messages: %w", err)
	}

	// Send to OpenAI
	response, err := w.client.SendMessage(messages)
	if err != nil {
		return "", fmt.Errorf("failed to get song suggestion: %w", err)
	}

	// Add assistant response to session
	if err := w.session.AddMessage(userID, response); err != nil {
		return "", fmt.Errorf("failed to add suggestion response: %w", err)
	}

	return response.Content, nil
}

// ProvideFeedback adds user feedback about a suggested song to the conversation
func (w *WailsClient) ProvideFeedback(ctx context.Context, userID string, songName string, liked bool) error {
	feedback := "liked"
	if !liked {
		feedback = "didn't like"
	}

	feedbackMessage := fmt.Sprintf("I %s the song '%s' that you suggested.", feedback, songName)

	// Add the feedback to the session
	if err := w.session.AddMessage(userID, Message{
		Role:    "user",
		Content: feedbackMessage,
	}); err != nil {
		return fmt.Errorf("failed to add feedback: %w", err)
	}

	// Get conversation history
	messages, err := w.session.GetMessages(userID)
	if err != nil {
		return fmt.Errorf("failed to get messages: %w", err)
	}

	// Send to OpenAI to get acknowledgment
	response, err := w.client.SendMessage(messages)
	if err != nil {
		return fmt.Errorf("failed to process feedback: %w", err)
	}

	// Add assistant response to session
	if err := w.session.AddMessage(userID, response); err != nil {
		return fmt.Errorf("failed to add feedback response: %w", err)
	}

	return nil
}
