package bindings

import (
	"context"
	"errors"
	"fmt"
	"interestnaut/internal/directives"
	"interestnaut/internal/gemini"
	"interestnaut/internal/llm"
	"interestnaut/internal/openai"
	"interestnaut/internal/openlibrary"
	"interestnaut/internal/session"
	"log"
	"strings"
)

// BookWithSavedStatus represents a book with its saved status
type BookWithSavedStatus struct {
	Title     string   `json:"title"`
	Author    string   `json:"author"`
	Key       string   `json:"key"`
	CoverPath string   `json:"cover_path"`
	Year      int      `json:"year,omitempty"`
	Subjects  []string `json:"subjects,omitempty"`
}

type Books struct {
	olClient               *openlibrary.Client
	llmClients             map[string]llm.Client[session.Book]
	manager                session.Manager[session.Book]
	centralManager         session.CentralManager
	baselineFunc, taskFunc func() string
}

func NewBooks(_ context.Context, cm session.CentralManager) (*Books, error) {
	client := openlibrary.NewClient()

	// Create a map of LLM clients for both providers
	llmClients := make(map[string]llm.Client[session.Book])

	// Initialize OpenAI client
	openaiClient, err := openai.NewClient[session.Book](cm)
	if err != nil {
		log.Printf("ERROR: Failed to create OpenAI client: %v", err)
	} else {
		llmClients["openai"] = openaiClient
	}

	// Initialize Gemini client
	geminiClient, err := gemini.NewClient[session.Book](cm)
	if err != nil {
		log.Printf("ERROR: Failed to create Gemini client: %v", err)
	} else {
		llmClients["gemini"] = geminiClient
	}

	// If no clients were successfully created, return nil
	if len(llmClients) == 0 {
		log.Printf("ERROR: Failed to create any LLM clients")
		return nil, errors.New("failed to create any LLM clients")
	}

	manager := cm.Book()

	b := &Books{
		olClient:       client,
		llmClients:     llmClients,
		manager:        manager,
		centralManager: cm,
	}

	b.taskFunc = func() string {
		return directives.BookDirective
	}

	b.baselineFunc = func() string {
		// Get favorites directly from the central manager
		favorites := cm.Favorites().GetBooks()
		return directives.GetBookBaseline(context.Background(), favorites)
	}

	return b, nil
}

// SetFavoriteBooks allows the user to set their initial list of favorite books
func (b *Books) SetFavoriteBooks(books []session.Book) error {
	// Simply replace all book favorites with the provided list
	// Get current favorites
	currentFavorites := b.centralManager.Favorites().GetBooks()

	// Remove all current favorites
	for _, book := range currentFavorites {
		if err := b.centralManager.Favorites().RemoveBook(book); err != nil {
			log.Printf("WARNING: Failed to remove book favorite %s: %v", book.Title, err)
		}
	}

	// Add all new favorites
	for _, book := range books {
		if err := b.centralManager.Favorites().AddBook(book); err != nil {
			log.Printf("WARNING: Failed to add book favorite %s: %v", book.Title, err)
		}
	}

	log.Printf("Updated favorites with %d books", len(books))
	return nil
}

// GetFavoriteBooks returns the current list of favorite books
func (b *Books) GetFavoriteBooks() ([]session.Book, error) {
	favorites := b.centralManager.Favorites().GetBooks()

	// If no favorites, return empty slice instead of nil
	if favorites == nil {
		return []session.Book{}, nil
	}

	return favorites, nil
}

// AddToReadList adds a book to the user's reading list
func (b *Books) AddToReadList(book session.Book) error {
	// Check if book already exists in reading list
	readList := b.centralManager.Queue().GetBooks()
	for _, rb := range readList {
		if rb.Title == book.Title && rb.Author == book.Author {
			// Book already in reading list
			return nil
		}
	}

	// Add book to reading list
	if err := b.centralManager.Queue().AddBook(book); err != nil {
		return fmt.Errorf("failed to add book to reading list: %w", err)
	}

	log.Printf("Added '%s' by '%s' to reading list", book.Title, book.Author)
	return nil
}

// RemoveFromReadList removes a book from the user's reading list
func (b *Books) RemoveFromReadList(title, author string) error {
	// Get current reading list
	readList := b.centralManager.Queue().GetBooks()

	// Find the book by title and author
	found := false
	var bookToRemove session.Book

	for _, book := range readList {
		if book.Title == title && book.Author == author {
			found = true
			bookToRemove = book
			break
		}
	}

	if !found {
		return fmt.Errorf("book '%s' by '%s' not found in reading list", title, author)
	}

	// Remove from the reading list
	if err := b.centralManager.Queue().RemoveBook(bookToRemove); err != nil {
		return fmt.Errorf("failed to remove book from reading list: %w", err)
	}

	log.Printf("Removed '%s' by '%s' from reading list", title, author)
	return nil
}

// GetReadList returns the current reading list
func (b *Books) GetReadList() ([]session.Book, error) {
	return b.centralManager.Queue().GetBooks(), nil
}

// SearchBooks searches for books using the Open Library API
func (b *Books) SearchBooks(query string) ([]*BookWithSavedStatus, error) {
	resp, err := b.olClient.SearchBooks(context.Background(), query)
	if err != nil {
		return nil, fmt.Errorf("failed to search books: %w", err)
	}

	// Convert response to array of books with saved status
	books := make([]*BookWithSavedStatus, len(resp.Docs))
	for i, result := range resp.Docs {
		authorName := ""
		if len(result.AuthorNames) > 0 {
			authorName = result.AuthorNames[0]
		}

		coverPath := ""
		if result.CoverID != 0 {
			coverPath = b.olClient.GetCoverURL(result.CoverID)
		}

		books[i] = &BookWithSavedStatus{
			Title:     result.Title,
			Author:    authorName,
			Key:       result.Key,
			CoverPath: coverPath,
			Year:      result.FirstPublish,
			Subjects:  result.SubjectFacets,
		}
	}

	return books, nil
}

// GetBookDetails gets detailed information about a specific book
func (b *Books) GetBookDetails(workKey string) (*BookWithSavedStatus, error) {
	book, err := b.olClient.GetBookDetails(context.Background(), workKey)
	if err != nil {
		return nil, fmt.Errorf("failed to get book details: %w", err)
	}

	// Get the author information if available
	authorName := ""
	if len(book.AuthorKeys) > 0 {
		authorKey := book.AuthorKeys[0].Author.Key
		author, err := b.olClient.GetAuthorDetails(context.Background(), authorKey)
		if err == nil && author != nil {
			authorName = author.Name
		}
	}

	coverPath := ""
	if len(book.Covers) > 0 {
		coverPath = b.olClient.GetCoverURL(book.Covers[0])
	}

	return &BookWithSavedStatus{
		Title:     book.Title,
		Author:    authorName,
		Key:       book.Key,
		CoverPath: coverPath,
		Subjects:  book.Subjects,
	}, nil
}

// GetBookSuggestion requests a book suggestion from the LLM
func (b *Books) GetBookSuggestion() (map[string]interface{}, error) {
	ctx := context.Background()
	sess := b.manager.GetOrCreateSession(ctx, b.manager.Key(), b.taskFunc, b.baselineFunc)

	// Get current LLM provider from settings
	provider := b.centralManager.Settings().GetLLMProvider()

	// Get the appropriate client
	llmClient, ok := b.llmClients[provider]
	if !ok {
		// Fall back to openai if the requested provider is not available
		log.Printf("WARNING: Requested LLM provider '%s' not available, falling back to openai", provider)
		llmClient, ok = b.llmClients["openai"]
		if !ok {
			return nil, errors.New("no LLM clients available")
		}
	}

	// Request a new suggestion
	messages, err := llmClient.ComposeMessages(ctx, &sess.Content)
	if err != nil {
		return nil, fmt.Errorf("failed to compose message for LLM: %w", err)
	}

	suggestion, err := llmClient.SendMessages(ctx, messages...)
	if err != nil {
		// Check if this is a parsing error and try using the error followup
		if err.Error() != "" && (strings.Contains(err.Error(), "failed to parse suggestion") ||
			strings.Contains(err.Error(), "could not parse suggestion")) {
			log.Printf("Initial LLM response could not be parsed, attempting error followup")

			// If we got a suggestion object but it wasn't valid, try error followup
			if suggestion != nil {
				// Try error followup with original messages
				suggestion, err = llmClient.ErrorFollowup(ctx, suggestion, messages...)
				if err != nil {
					return nil, fmt.Errorf("error followup also failed: %w", err)
				}
			} else {
				return nil, fmt.Errorf("failed to get suggestion from LLM: %w", err)
			}
		} else {
			return nil, fmt.Errorf("failed to get suggestion from LLM: %w", err)
		}
	}

	// Check if title and author are present
	if suggestion.Content.Title == "" || suggestion.Content.Author == "" {
		log.Printf("ERROR: LLM content missing title or author. Content: %+v", suggestion)
		return nil, errors.New("LLM content response was missing title or author")
	}

	// Try to find the book on Open Library
	searchQuery := fmt.Sprintf("%s %s", suggestion.Content.Title, suggestion.Content.Author)
	books, err := b.SearchBooks(searchQuery)
	if err != nil || len(books) == 0 {
		// Even if we can't find the book on Open Library, we can still use the suggestion
		// Just without a proper cover or additional metadata
		log.Printf("WARNING: Could not find book '%s' by '%s' on Open Library: %v", suggestion.Content.Title, suggestion.Content.Author, err)

		bookSuggestion := session.Suggestion[session.Book]{
			PrimaryGenre: suggestion.PrimaryGenre,
			UserOutcome:  session.Pending,
			Reasoning:    suggestion.Reason,
			Content: session.Book{
				Title:     suggestion.Content.Title,
				Author:    suggestion.Content.Author,
				CoverPath: "", // No cover path available
			},
		}

		if sErr := b.manager.AddSuggestion(ctx, sess, bookSuggestion); sErr != nil {
			log.Printf("ERROR: Failed to add suggestion: %v", sErr)
			return nil, fmt.Errorf("failed to add suggestion: %w", sErr)
		}

		// Return the suggestion even without additional metadata
		return map[string]interface{}{
			"title":         suggestion.Content.Title,
			"author":        suggestion.Content.Author,
			"cover_path":    "",
			"reasoning":     suggestion.Reason,
			"primary_genre": suggestion.PrimaryGenre,
		}, nil
	}

	// Find the best match from the search results
	var bestMatch *BookWithSavedStatus
	bestSimilarity := 0.0

	for _, book := range books {
		titleSimilarity := calculateSimilarity(book.Title, suggestion.Content.Title)
		authorSimilarity := calculateSimilarity(book.Author, suggestion.Content.Author)

		// Weighted average of title and author similarity
		similarity := (titleSimilarity*0.7 + authorSimilarity*0.3)

		if similarity > bestSimilarity {
			bestSimilarity = similarity
			bestMatch = book
		}
	}

	if bestMatch == nil {
		bestMatch = books[0] // Default to first result if no good match found
	}

	// Store the suggestion in the session
	bookSuggestion := session.Suggestion[session.Book]{
		PrimaryGenre: suggestion.PrimaryGenre,
		UserOutcome:  session.Pending,
		Reasoning:    suggestion.Reason,
		Content: session.Book{
			Title:     bestMatch.Title,
			Author:    bestMatch.Author,
			CoverPath: bestMatch.CoverPath,
		},
	}

	if err := b.manager.AddSuggestion(ctx, sess, bookSuggestion); err != nil {
		log.Printf("ERROR: Failed to add suggestion: %v", err)
		return nil, fmt.Errorf("failed to add suggestion: %w", err)
	}

	// Return the book information
	return map[string]interface{}{
		"title":         bestMatch.Title,
		"author":        bestMatch.Author,
		"cover_path":    bestMatch.CoverPath,
		"reasoning":     suggestion.Reason,
		"primary_genre": suggestion.PrimaryGenre,
		"key":           bestMatch.Key,
	}, nil
}

// ProvideSuggestionFeedback provides feedback on a suggestion
func (b *Books) ProvideSuggestionFeedback(outcome session.Outcome, title string, author string) error {
	ctx := context.Background()
	sess := b.manager.GetOrCreateSession(ctx, b.manager.Key(), b.taskFunc, b.baselineFunc)

	// Create a key for the book
	key := session.Book{
		Title:  title,
		Author: author,
	}.Key()

	// Update the suggestion with the user's outcome
	if err := b.manager.UpdateSuggestionOutcome(ctx, sess, key, outcome); err != nil {
		return fmt.Errorf("failed to update suggestion outcome: %w", err)
	}

	// If the user liked the suggestion, add it to favorites
	if outcome == session.Liked {
		book := session.Book{
			Title:  title,
			Author: author,
		}
		if err := b.centralManager.Favorites().AddBook(book); err != nil {
			log.Printf("WARNING: Failed to add book to favorites: %v", err)
		}
	}

	return nil
}
