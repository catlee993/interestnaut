package llm

type Message struct {
	Content string `json:"content"`
}

type MusicSuggestion struct {
	Name   string `json:"name"`
	Artist string `json:"artist"`
	Album  string `json:"album"`
	Reason string `json:"reason"`
	ID     string `json:"id"`
}
