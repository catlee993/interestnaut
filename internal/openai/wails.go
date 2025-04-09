package openai

import (
	"context"
	"fmt"
	"log"
	"strings"
)

type WailsClient struct {
	client  *Client
	session *SessionManager
	userID  string // Add userID field to store the actual Spotify user ID
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

// SetUserID sets the current user ID
func (w *WailsClient) SetUserID(userID string) {
	w.userID = userID
	// Set user ID on the underlying client
	w.client.SetUserID(userID)
	// Ensure a session exists for this user
	w.session.GetOrCreateSession(userID)
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
	tracksInfo.WriteString("Here are all tracks in the user's library. Use these to understand their music taste and suggest new songs they might enjoy. IMPORTANT: Only suggest songs that are NOT in this list:\n\n")

	// Use a more compact format to save tokens: "Artist - Song (Album)"
	for _, track := range savedTracks {
		name, _ := track["name"].(string)
		artist, _ := track["artist"].(string)
		album, _ := track["album"].(string)

		tracksInfo.WriteString(fmt.Sprintf("%s - %s", artist, name))
		if album != "" {
			tracksInfo.WriteString(fmt.Sprintf(" (%s)", album))
		}
		tracksInfo.WriteString("\n")
	}

	tracksInfo.WriteString(fmt.Sprintf("\nAnalyzed %d tracks. Based on these, analyze the user's music preferences including genres, artists, and musical style. Focus on identifying patterns and recurring elements that define their taste.\n", len(savedTracks)))

	// Create a message to analyze preferences
	analysisPrompt := tracksInfo.String()

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
	suggestionPrompt := `Based on my music preferences, suggest a song I might like. Remember to respond with ONLY a JSON object containing the song name, artist, and reason for the suggestion. Do not include any other text.`

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

// HasAnalyzedLibrary checks if we've already analyzed the user's library
func (w *WailsClient) HasAnalyzedLibrary(userID string) bool {
	return w.session.HasAnalyzedLibrary(userID)
}

// HasSuggested checks if a song has been suggested before
func (w *WailsClient) HasSuggested(songName string, artistName string) bool {
	return w.session.HasSuggested(w.GetCurrentUserID(), songName, artistName)
}

// AddSuggestion records a song suggestion with full details
func (w *WailsClient) AddSuggestion(name string, artist string, album string, spotifyID string, reason string) error {
	record := SuggestionRecord{
		Name:      name,
		Artist:    artist,
		Album:     album,
		SpotifyID: spotifyID,
		Reason:    reason,
	}
	return w.session.AddSuggestion(w.GetCurrentUserID(), record)
}

// UpdateSuggestionOutcome updates the outcome of a suggestion
func (w *WailsClient) UpdateSuggestionOutcome(songName string, artistName string, outcome SuggestionOutcome) error {
	return w.session.UpdateSuggestionOutcome(w.GetCurrentUserID(), songName, artistName, outcome)
}

// GetSuggestionHistory returns the full suggestion history
func (w *WailsClient) GetSuggestionHistory() ([]SuggestionRecord, error) {
	return w.session.GetSuggestionHistory(w.GetCurrentUserID())
}

// GetCurrentUserID gets the current user ID from the session
func (w *WailsClient) GetCurrentUserID() string {
	if w.userID == "" {
		// Fallback to default_user only if no user ID has been set
		log.Printf("WailsClient.GetCurrentUserID: No user ID set, using default_user")
		return "default_user"
	}
	log.Printf("WailsClient.GetCurrentUserID: Using user ID: %s", w.userID)
	return w.userID
}

// GetClient returns the underlying Client
func (w *WailsClient) GetClient() (*Client, bool) {
	if w.client == nil {
		return nil, false
	}
	return w.client, true
}
