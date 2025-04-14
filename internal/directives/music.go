package directives

import (
	"context"
	"fmt"
	"interestnaut/internal/spotify"
	"log"
	"strings"
)

// MusicDirective is static, and will be used once to prime the model
const MusicDirective = `
You are a music recommendation assistant. Your goal is to understand the user's 
music preferences and suggest new music they might enjoy. 
Keep track of their likes and dislikes to improve your recommendations over time.

IMPORTANT RULES:
1. Never suggest the same song twice.
2. Return only a valid JSON object with keys and string values properly enclosed in double quotes. Do not include any extra text, markdown fences, or commentary.
{
  "title": "Song Name",
  "artist": "Artist Name",
  "album": "Album Name",
  "primary_genre": "The primary genre of the song",
  "reason": "Detailed explanation of why this song matches their taste, referencing specific patterns in their library or likes/dislikes."
}
3. Don't suggest songs that are already in the user's library. 
4. Refer to suggestions for your previous suggestions.
5. Refer to user_constraints for any specific user-defined constraints.
6. Refer to baseline for a list of tracks in the user's library.

Do not include any other text in your response, only the JSON object to be parsed.
`

// GetMusicBaseline generates a music baseline for the user based on their concatenated liked tracks
func GetMusicBaseline(ctx context.Context, client spotify.Client) string {
	tracks, err := client.GetAllLikedTracks(ctx)
	if err != nil {
		log.Printf("failed to get liked tracks: %v", err)
		return ""
	}

	if len(tracks) == 0 {
		log.Println("no liked tracks found")
		return ""
	}

	var sb strings.Builder
	sb.WriteString("Here are all the tracks in the user's library. Use these to understand their music taste and suggest new songs they might enjoy. They are in the form of Artist - Song (Album), separated by newlines \n\n")

	// Create a more compact representation to save tokens
	// Format: "Artist - Song (Album)" one per line
	for _, item := range tracks {
		if item.Track != nil {
			var artistNames []string
			for _, artist := range item.Track.Artists {
				artistNames = append(artistNames, artist.Name)
			}
			sb.WriteString(fmt.Sprintf("%s - %s",
				strings.Join(artistNames, ", "),
				item.Track.Name))
			if item.Track.Album.Name != "" {
				sb.WriteString(fmt.Sprintf(" (%s)", item.Track.Album.Name))
			}
			sb.WriteString("\n")
		}
	}

	sb.WriteString(fmt.Sprintf("\nAnalyzed %d tracks. Based on these, suggest songs that match their musical preferences while introducing new artists and styles. For each suggestion, explain why you think they'll like it based on specific patterns in their library.\n", len(tracks)))

	return sb.String()
}
