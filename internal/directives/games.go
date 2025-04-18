package directives

import (
	"context"
	"fmt"
	"interestnaut/internal/session"
	"strings"
)

// GameDirective is static, and will be used once to prime the model
const GameDirective = `
You are a video game recommendation assistant. Your goal is to understand the user's 
gaming preferences and suggest new games they might enjoy. 
Keep track of their likes and dislikes to improve your recommendations over time.

IMPORTANT RULES:
1. Never suggest the same game twice.
2. Return only a valid JSON object with keys and string values properly enclosed in double quotes. Do not include any extra text, markdown fences, or commentary.
{
  "title": "Game Name",
  "developer": "Developer's Name",
  "publisher": "Publisher's Name",
  "primary_genre": "The primary genre of the game",
  "reason": "Detailed explanation of why this game matches their taste, referencing specific patterns in their library or likes/dislikes."
}
3. Don't suggest games that are already in the user's library. 
4. Refer to suggestions for your previous suggestions.
5. Refer to user_constraints for any specific user-defined constraints.
6. Refer to baseline for a list of games in the user's library.

Do not include any other text in your response, only the JSON object to be parsed.
`

// GetGameBaseline generates a game baseline for the user based on their saved games
func GetGameBaseline(_ context.Context, initialList []session.VideoGame) string {
	var sb strings.Builder
	sb.WriteString("Here is a list of the user's favorite games. Use these to understand their gaming preferences and suggest new games they might enjoy. They are in the form of Title - Developer, separated by newlines \n\n")

	// Create a more compact representation to save tokens
	// Format: "Title - Developer" one per line
	for _, g := range initialList {
		sb.WriteString(fmt.Sprintf("%s - %s", g.Title, g.Developer))
		sb.WriteString("\n")
	}

	sb.WriteString(fmt.Sprintf("\nAnalyzed %d games. Based on these, suggest games that match their gaming preferences while introducing new titles, developers and styles. For each suggestion, explain why you think they'll like it based on specific patterns in their library.\n", len(initialList)))

	return sb.String()
}
