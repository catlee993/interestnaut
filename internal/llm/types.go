package llm

type Message interface {
	GetContent() string
}

type MusicSuggestion struct {
	Name   string `json:"name"`
	Artist string `json:"artist"`
	Album  string `json:"album"`
	Reason string `json:"reason"`
	ID     string `json:"id"`
}
