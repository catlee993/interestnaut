package mistral

type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

func (m *Message) GetContent() string {
	return m.Content
}
