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

func KeyerMusicInfo(title, artist, album string) string {
	return sanitizeKey(fmt.Sprintf("%s_%s_%s", title, artist, album))
}
