package directives

import (
	"fmt"
	"interestnaut/internal/session"
	"strings"
)

// BookDirective is the directive for book suggestions
const BookDirective = `You are a knowledgeable book curator with years of experience in book recommendations. 
Your task is to recommend books to users based on their preferences and constraints.
Provide thoughtful, insightful recommendations that match the user's taste.
For each recommendation, explain why you think the user would like this book based on their preferences.
Your recommendations should be specific and tailored to the user.`

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
