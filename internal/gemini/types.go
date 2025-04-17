package gemini

import "interestnaut/internal/llm"

// Message represents a message in the Gemini API format
type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// GetContent implements the llm.Message interface
func (m *Message) GetContent() string {
	return m.Content
}

// Role constants for Gemini messages
const (
	RoleSystem = "system" // Not directly supported by Gemini
	RoleUser   = "user"   // Supported by Gemini
	RoleModel  = "model"  // Gemini uses "model" instead of "assistant"
)

// ChatRequest represents a request to the Gemini API
// Note: This is kept for reference but no longer used
type ChatRequest struct {
	Contents []Message `json:"contents"`
	Model    string    `json:"model"`
}

// ChatResponse represents a response from the Gemini API
type ChatResponse struct {
	Candidates []struct {
		Content struct {
			Parts []struct {
				Text string `json:"text"`
			} `json:"parts"`
		} `json:"content"`
	} `json:"candidates"`
}

// Convert from llm.Message to gemini.Message
func ConvertMessage(msg llm.Message) Message {
	role := RoleUser
	if gmsg, ok := msg.(*Message); ok {
		return *gmsg
	}

	// By default, use the user role for messages
	return Message{
		Role:    role,
		Content: msg.GetContent(),
	}
}
