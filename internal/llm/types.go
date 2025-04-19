package llm

import (
	"encoding/json"
	"fmt"
	"interestnaut/internal/session"
	"regexp"
	"strings"
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
	RawResponse  string `json:"-"` // Store the original unparsed response
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

		// If we successfully parsed JSON but title/author are in the wrong place for books,
		// try to fix the structure
		if _, isBook := any(suggestion.Content).(session.Book); isBook {
			// Check if we need to extract directly from the raw response
			if suggestion.RawResponse != "" {
				// Get the book to check if it has an author
				book, ok := any(suggestion.Content).(session.Book)
				if !ok || book.Author == "" && suggestion.Artist == "" {
					var rawData map[string]interface{}

					// Clean the raw response
					rawContent := suggestion.RawResponse
					if strings.Contains(rawContent, "```json") && strings.Contains(rawContent, "```") {
						parts := strings.Split(rawContent, "```json")
						if len(parts) > 1 {
							rawContent = parts[1]
							parts = strings.Split(rawContent, "```")
							if len(parts) > 0 {
								rawContent = parts[0]
							}
						}
					}

					// Try to parse the cleaned raw JSON
					if err := json.Unmarshal([]byte(strings.TrimSpace(rawContent)), &rawData); err == nil {
						// Look for author field in raw data
						if rawAuthor, ok := rawData["author"].(string); ok && rawAuthor != "" {
							book.Author = rawAuthor
							suggestion.Content = any(book).(T)
							suggestion.Artist = rawAuthor
						}
					}
				}
			}

			// If title/author fields are at top level but content is empty, move them
			if suggestion.Title != "" {
				// Get the existing book, or create a new one
				book, ok := any(suggestion.Content).(session.Book)
				if !ok || (book.Title == "" && book.Author == "") {
					book = session.Book{}
				}

				// Copy the top-level fields to the book content
				book.Title = suggestion.Title

				// Look for author in the artist field (common parsing mistake)
				if suggestion.Artist != "" {
					book.Author = suggestion.Artist
				}

				// Set the content
				suggestion.Content = any(book).(T)
			}
		}

		// Store the original content
		suggestion.RawResponse = content
		return &suggestion, nil
	}

	// If JSON parsing fails, try to infer properties
	suggestion = SuggestionResponse[T]{}
	// Store the original content
	suggestion.RawResponse = content

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

	// Look for author (for books)
	if authorMatch := regexp.MustCompile(`"?author"?\s*[:=]\s*"([^"]+)"`).FindStringSubmatch(content); len(authorMatch) > 1 {
		// Store in Artist field for compatibility
		suggestion.Artist = authorMatch[1]

		// If this is a book, update the Content directly
		if _, isBook := any(suggestion.Content).(session.Book); isBook {
			// Get the existing book or create a new one
			book, ok := any(suggestion.Content).(session.Book)
			if !ok {
				book = session.Book{}
			}

			// Update fields
			if suggestion.Title != "" {
				book.Title = suggestion.Title
			}
			book.Author = authorMatch[1]

			// Set the content
			suggestion.Content = any(book).(T)
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
