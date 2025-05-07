package session

import (
	"fmt"
	"regexp"
	"strings"
)

// sanitizeKey removes all non-alphanumeric characters and converts to lowercase
func sanitizeKey(s string) string {
	// Remove all non-alphanumeric characters except underscores
	reg := regexp.MustCompile(`[^a-zA-Z0-9_]`)
	return strings.ToLower(reg.ReplaceAllString(s, ""))
}

// Keyer functions are necessary since results from remote sources won't be the session.Media type

func KeyerMusicInfo(title, artist, album string) string {
	return sanitizeKey(fmt.Sprintf("%s_%s_%s", title, artist, album))
}

func KeyerMovieInfo(title, director, writer string) string {
	return sanitizeKey(fmt.Sprintf("%s_%s_%s", title, director, writer))
}

func KeyerBookInfo(title, author string) string {
	return sanitizeKey(fmt.Sprintf("%s_%s", title, author))
}

func KeyerTVShowInfo(title, director, writer string) string {
	return sanitizeKey(fmt.Sprintf("%s_%s_%s", title, director, writer))
}

func KeyerVideoGameInfo(title, developer, publisher string) string {
	return sanitizeKey(fmt.Sprintf("%s_%s_%s", title, developer, publisher))
}
