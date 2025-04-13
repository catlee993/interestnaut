package openai

import "interestnaut/internal/llm"

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

func (m *Message) GetContent() string {
	return m.Content
}

type ChatRequest struct {
	Model    string        `json:"model"`
	Messages []llm.Message `json:"messages"`
}

type ChatResponse struct {
	Choices []struct {
		Message *Message `json:"message"`
	} `json:"choices"`
}
