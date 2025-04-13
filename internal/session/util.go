package session

import (
	"fmt"
	"strings"
)

func EqualMusicSuggestions(a, b Suggestion[Music]) bool {
	return a.Title == b.Title &&
		a.Content.Artist == b.Content.Artist &&
		a.Content.Album == b.Content.Album
}

func KeyerMusicSuggestion(s Suggestion[Music]) string {
	return strings.ReplaceAll(
		strings.ToLower(
			fmt.Sprintf("%s_%s_%s", s.Title, s.Content.Artist, s.Content.Album),
		), " ", "",
	)
}

func KeyerMusicInfo(title, artist, album string) string {
	return strings.ReplaceAll(
		strings.ToLower(fmt.Sprintf("%s_%s_%s", title, artist, album)), " ", "",
	)
}
