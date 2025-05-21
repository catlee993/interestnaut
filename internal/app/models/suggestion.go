package models

import (
	"time"
)

// SuggestionStatus represents the state of a suggestion.
// These should match the Dart enum SuggestionStatus.
type SuggestionStatus string

const (
	StatusPending   SuggestionStatus = "pending"
	StatusSkipped   SuggestionStatus = "skipped"
	StatusLiked     SuggestionStatus = "liked"
	StatusDisliked  SuggestionStatus = "disliked"
	StatusAdded     SuggestionStatus = "added" // Favorited
)

// MediaSuggestion mirrors the Dart MediaSuggestion class.
// It's used for database storage and FFI communication.
type MediaSuggestion struct {
	ID           string           `json:"id" db:"id"`                     // Unique identifier (e.g., UUID, assigned by Go DB)
	Query        string           `json:"query" db:"query"`                 // Original LLM query or bot's raw suggestion text
	MediaType    string           `json:"media_type" db:"media_type"`         // e.g., "music", "movie", "book"
	Title        *string          `json:"title,omitempty" db:"title"`            // Enriched title from Wikidata/Wikipedia
	Artist       *string          `json:"artist,omitempty" db:"artist"`          // Specific for music
	Album        *string          `json:"album,omitempty" db:"album"`            // Specific for music
	CoverArtURL  *string          `json:"cover_art_url,omitempty" db:"cover_art_url"` // URL for cover art
	Description  *string          `json:"description,omitempty" db:"description"`    // Enriched description
	WikiURL      *string          `json:"wiki_url,omitempty" db:"wiki_url"`          // Wikipedia URL
	WikidataID   *string          `json:"wikidata_id,omitempty" db:"wikidata_id"`    // Wikidata item ID
	BotReasoning *string          `json:"bot_reasoning,omitempty" db:"bot_reasoning"` // LLM's reasoning or Go's match reasoning
	Status       SuggestionStatus `json:"status" db:"status"`                 // Current status of the suggestion
	CreatedAt    time.Time        `json:"created_at" db:"created_at"`           // Timestamp of creation
	UpdatedAt    *time.Time       `json:"updated_at,omitempty" db:"updated_at"`     // Timestamp of last update
}

// IsValidStatus checks if the provided string is a valid SuggestionStatus.
func IsValidStatus(statusStr string) bool {
	switch SuggestionStatus(statusStr) {
	case StatusPending, StatusSkipped, StatusLiked, StatusDisliked, StatusAdded:
		return true
	default:
		return false
	}
}
