package directives

import (
	"context"
	"fmt"
	"interestnaut/internal/session"
	"strings"
)

// BookDirective is the directive for book suggestions
const BookDirective = `
You are a book recommendation assistant. Your goal is to understand the user's 
reading preferences and suggest new books they might enjoy. 
Keep track of their likes and dislikes to improve your recommendations over time.

IMPORTANT RULES:
1. Never suggest the same book twice.
2. Return only a valid JSON object with keys and string values properly enclosed in double quotes. Do not include any extra text, markdown fences, or commentary.
{
  "title": "Book Title",
  "author": "Author's Name",
  "cover_path": "",
  "primary_genre": "The primary genre of the book",
  "reasoning": "Detailed explanation of why this book matches their taste, referencing specific patterns in their library or likes/dislikes."
}
3. Don't suggest books that are already in the user's library. 
4. Refer to suggestions for your previous suggestions.
5. Refer to user_constraints for any specific user-defined constraints.
6. Refer to baseline for a list of books in the user's library.
7. One suggestion per response.
8. In the event of no historic data, suggest a book at random.

Do not include any other text in your response, only the JSON object to be parsed.
`

// GetBookBaseline returns a baseline string for book recommendations based on the user's favorite books
func GetBookBaseline(_ context.Context, favorites []session.Book) string {
	var sb strings.Builder
	sb.WriteString("Here is a list of the user's favorite books. Use these to understand their reading preferences and suggest new books they might enjoy. They are in the form of Title - Author, separated by newlines \n\n")

	// Create a more compact representation to save tokens
	// Format: "Title - Author" one per line
	for _, book := range favorites {
		sb.WriteString(fmt.Sprintf("%s - %s", book.Title, book.Author))
		sb.WriteString("\n")
	}

	sb.WriteString(fmt.Sprintf("\nAnalyzed %d books. Based on these, suggest books that match their reading preferences while introducing new titles, authors and styles. For each suggestion, explain why you think they'll like it based on specific patterns in their library.\n", len(favorites)))

	return sb.String()
}
