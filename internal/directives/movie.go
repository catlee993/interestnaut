package directives

import (
	"context"
	"fmt"
	"interestnaut/internal/session"
	"strings"
)

// MovieDirective is static, and will be used once to prime the model
const MovieDirective = `
You are a movie recommendation assistant. Your goal is to understand the user's 
theatrical preferences and suggest new movies they might enjoy. 
Keep track of their likes and dislikes to improve your recommendations over time.

IMPORTANT RULES:
1. Never suggest the same movie twice.
2. Return only a valid JSON object with keys and string values properly enclosed in double quotes. Do not include any extra text, markdown fences, or commentary.
{
  "title": "Movie Name",
  "director": "Director's Name",
  "writer": "Writer's Name",
  "primary_genre": "The primary genre of the movie",
  "reason": "Detailed explanation of why this movie matches their taste, referencing specific patterns in their library or likes/dislikes."
}
3. Don't suggest movies that are already in the user's library. 
4. Refer to suggestions for your previous suggestions.
5. Refer to user_constraints for any specific user-defined constraints.
6. Refer to baseline for a list of tracks in the user's library.
7. One suggestion per response.

Do not include any other text in your response, only the JSON object to be parsed.
`

// GetMovieBaseline generates a music baseline for the user based on their concatenated liked tracks
func GetMovieBaseline(_ context.Context, initialList []session.Movie) string {
	var sb strings.Builder
	sb.WriteString("Here is a list of the user's favorite movies. Use these to understand their movie taste and suggest new movies they might enjoy. They are in the form of Title - Director, separated by newlines \n\n")

	// Create a more compact representation to save tokens
	// Format: "Title - Director" one per line
	for _, m := range initialList {
		sb.WriteString(fmt.Sprintf("%s - %s", m.Title, m.Director))
		sb.WriteString("\n")
	}

	sb.WriteString(fmt.Sprintf("\nAnalyzed %d movies. Based on these, suggest movies that match their theatrical preferences while introducing new titles, directors and styles. For each suggestion, explain why you think they'll like it based on specific patterns in their library.\n", len(initialList)))

	return sb.String()
}
