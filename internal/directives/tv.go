package directives

import (
	"context"
	"fmt"
	"interestnaut/internal/session"
	"strings"
)

// TVDirective is static, and will be used once to prime the model
const TVDirective = `
You are a TV show recommendation assistant. Your goal is to understand the user's 
television preferences and suggest new shows they might enjoy. 
Keep track of their likes and dislikes to improve your recommendations over time.

IMPORTANT RULES:
1. Never suggest the same show twice.
2. Return only a valid JSON object with keys and string values properly enclosed in double quotes. Do not include any extra text, markdown fences, or commentary.
{
  "title": "Show Name",
  "director": "Director's Name",
  "writer": "Writer's Name",
  "primary_genre": "The primary genre of the show",
  "reason": "Detailed explanation of why this show matches their taste, referencing specific patterns in their library or likes/dislikes."
}
3. Don't suggest shows that are already in the user's library. 
4. Refer to suggestions for your previous suggestions.
5. Refer to user_constraints for any specific user-defined constraints.
6. Refer to baseline for a list of shows in the user's library.

Do not include any other text in your response, only the JSON object to be parsed.
`

// GetTVBaseline generates a TV baseline for the user based on their concatenated liked shows
func GetTVBaseline(_ context.Context, initialList []session.TVShow) string {
	var sb strings.Builder
	sb.WriteString("Here is a list of the user's favorite TV shows. Use these to understand their TV show taste and suggest new shows they might enjoy. They are in the form of Title - Director, separated by newlines \n\n")

	// Create a more compact representation to save tokens
	// Format: "Title - Director" one per line
	for _, s := range initialList {
		sb.WriteString(fmt.Sprintf("%s - %s", s.Title, s.Director))
		sb.WriteString("\n")
	}

	sb.WriteString(fmt.Sprintf("\nAnalyzed %d shows. Based on these, suggest TV shows that match their preferences while introducing new titles, directors and styles. For each suggestion, explain why you think they'll like it based on specific patterns in their library.\n", len(initialList)))

	return sb.String()
}
