package session

import (
	"fmt"
	"regexp"
	"strings"
)

func EqualMusicSuggestions(a, b Suggestion[Music]) bool {
	return a.Title == b.Title &&
		a.Content.Artist == b.Content.Artist &&
		a.Content.Album == b.Content.Album
}

// sanitizeKey removes all non-alphanumeric characters and converts to lowercase
func sanitizeKey(s string) string {
	// Remove all non-alphanumeric characters except underscores
	reg := regexp.MustCompile(`[^a-zA-Z0-9_]`)
	return strings.ToLower(reg.ReplaceAllString(s, ""))
}

func KeyerMusicSuggestion(s Suggestion[Music]) string {
	return sanitizeKey(fmt.Sprintf("%s_%s_%s", s.Title, s.Content.Artist, s.Content.Album))
}

func KeyerMusicInfo(title, artist, album string) string {
	return sanitizeKey(fmt.Sprintf("%s_%s_%s", title, artist, album))
}
