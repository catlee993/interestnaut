package llm

import (
	"encoding/json"
	"fmt"
	"interestnaut/internal/session"
	"regexp"
)

type Message interface {
	GetContent() string
}

// SuggestionResponse is a generic response type for suggestions that use session.Media
type SuggestionResponse[T session.Media] struct {
	Title        string `json:"title"`
	Artist       string `json:"artist"`
	Album        string `json:"album"`
	PrimaryGenre string `json:"primary_genre"`
	Reason       string `json:"reason"`
	Content      T      `json:"content"`
}

// ParseSuggestionFromString attempts to parse a suggestion from a string response
// If JSON parsing fails, it tries to infer the properties from the text
func ParseSuggestionFromString[T session.Media](content string) (*SuggestionResponse[T], error) {
	// First try standard JSON parsing
	var suggestion SuggestionResponse[T]
	if err := json.Unmarshal([]byte(content), &suggestion); err == nil {
		// If we successfully parsed JSON but artist/album are in the wrong place,
		// try to fix the structure
		if _, isMusic := any(suggestion.Content).(session.Music); isMusic {
			// If artist/album are at top level but not in content, move them
			if suggestion.Artist != "" || suggestion.Album != "" {
				suggestion.Content = any(session.Music{
					Artist: suggestion.Artist,
					Album:  suggestion.Album,
				}).(T)
			}
		}
		return &suggestion, nil
	}

	// If JSON parsing fails, try to infer properties
	suggestion = SuggestionResponse[T]{}

	// Look for title
	if titleMatch := regexp.MustCompile(`"?title"?\s*[:=]\s*"([^"]+)"`).FindStringSubmatch(content); len(titleMatch) > 1 {
		suggestion.Title = titleMatch[1]
	}

	// Look for artist
	if artistMatch := regexp.MustCompile(`"?artist"?\s*[:=]\s*"([^"]+)"`).FindStringSubmatch(content); len(artistMatch) > 1 {
		suggestion.Artist = artistMatch[1]
		if _, isMusic := any(suggestion.Content).(session.Music); isMusic {
			suggestion.Content = any(session.Music{
				Artist: artistMatch[1],
			}).(T)
		}
	}

	// Look for album
	if albumMatch := regexp.MustCompile(`"?album"?\s*[:=]\s*"([^"]+)"`).FindStringSubmatch(content); len(albumMatch) > 1 {
		suggestion.Album = albumMatch[1]
		if music, ok := any(suggestion.Content).(session.Music); ok {
			music.Album = albumMatch[1]
			suggestion.Content = any(music).(T)
		}
	}

	// Look for primary genre
	if genreMatch := regexp.MustCompile(`"?primary_genre"?\s*[:=]\s*"([^"]+)"`).FindStringSubmatch(content); len(genreMatch) > 1 {
		suggestion.PrimaryGenre = genreMatch[1]
	}

	// Look for reason
	if reasonMatch := regexp.MustCompile(`"?reason"?\s*[:=]\s*"([^"]+)"`).FindStringSubmatch(content); len(reasonMatch) > 1 {
		suggestion.Reason = reasonMatch[1]
	}

	// If we couldn't find any properties, return error
	if suggestion.Title == "" {
		return nil, fmt.Errorf("could not parse suggestion from content: %s", content)
	}

	return &suggestion, nil
}

type MusicSuggestion struct {
	Name   string `json:"name"`
	Artist string `json:"artist"`
	Album  string `json:"album"`
	Reason string `json:"reason"`
	ID     string `json:"id"`
}
