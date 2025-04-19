package directives

import (
	"fmt"
	"interestnaut/internal/session"
	"strings"
)

// BookDirective is the directive for book suggestions
const BookDirective = `You are a knowledgeable book curator with years of experience in book recommendations. 
Your task is to recommend ONE book to users based on their preferences and constraints.

CRITICAL INSTRUCTION: Your response will be parsed directly by a computer program, not read by a human.
You MUST return ONLY a single JSON object with EXACTLY the following structure and nothing else:

{
  "title": "Book Title",
  "author": "Book Author",
  "cover_path": "",
  "reasoning": "Brief explanation of why you're recommending this book",
  "primary_genre": "Main genre"
}

DO NOT include any other text, markdown, explanation, introduction, or multiple recommendations.
DO NOT wrap the JSON in backticks or other formatting.
Your entire response must be this single JSON object that can be directly parsed.
ANY deviation from this format will cause a system error.

Select one compelling book recommendation, not a list of options.
For the cover_path, leave it as an empty string - it will be filled in by the system.`

// GetBookBaseline returns a baseline string for book recommendations based on the user's favorite books
func GetBookBaseline(favorites []session.Book) string {
	if len(favorites) == 0 {
		return "The user has not specified any favorite books yet."
	}

	var sb strings.Builder
	sb.WriteString("The user has indicated they enjoy the following books:\n")

	for i, book := range favorites {
		sb.WriteString(fmt.Sprintf("%d. \"%s\" by %s\n", i+1, book.Title, book.Author))
	}

	sb.WriteString("\nBased on these preferences, recommend books that the user might enjoy. ")
	sb.WriteString("Consider similar themes, writing styles, genres, or authors that align with their taste. ")
	sb.WriteString("For each recommendation, provide a brief explanation of why you think they would enjoy it based on their preferences.")

	return sb.String()
}
