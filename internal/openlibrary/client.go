package openlibrary

import (
	"context"
	"encoding/json"
	"fmt"
	"interestnaut/internal/session"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	baseURL          = "https://openlibrary.org"
	searchEndpoint   = "/search.json"
	bookEndpoint     = "/works"
	authorEndpoint   = "/authors"
	coverURLTemplate = "https://covers.openlibrary.org/b/id/%s-L.jpg"
)

// SearchResult represents a book search result from Open Library
type SearchResult struct {
	Title         string   `json:"title"`
	AuthorNames   []string `json:"author_name,omitempty"`
	Key           string   `json:"key"`
	CoverID       int      `json:"cover_i,omitempty"`
	FirstPublish  int      `json:"first_publish_year,omitempty"`
	PublishYear   []int    `json:"publish_year,omitempty"`
	NumberOfPages int      `json:"number_of_pages_median,omitempty"`
	SubjectFacets []string `json:"subject_facet,omitempty"`
}

// SearchResponse represents the response from Open Library search
type SearchResponse struct {
	NumFound int            `json:"numFound"`
	Start    int            `json:"start"`
	Docs     []SearchResult `json:"docs"`
}

// WorksResponse represents the detailed book information
type WorksResponse struct {
	Title       string   `json:"title"`
	Key         string   `json:"key"`
	Description any      `json:"description"` // Can be string or object
	Subjects    []string `json:"subjects,omitempty"`
	AuthorKeys  []struct {
		Author struct {
			Key string `json:"key"`
		} `json:"author"`
	} `json:"authors,omitempty"`
	Covers []int `json:"covers,omitempty"`
}

// AuthorResponse represents author information
type AuthorResponse struct {
	Name        string `json:"name"`
	Key         string `json:"key"`
	Birth       string `json:"birth_date,omitempty"`
	Death       string `json:"death_date,omitempty"`
	Bio         any    `json:"bio,omitempty"`
	Photos      []int  `json:"photos,omitempty"`
	PersonalWeb string `json:"personal_web,omitempty"`
}

// Client for interacting with the Open Library API
type Client struct {
	httpClient *http.Client
}

// NewClient creates a new Open Library client
func NewClient() *Client {
	return &Client{
		httpClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// SearchBooks searches for books using the Open Library API
func (c *Client) SearchBooks(ctx context.Context, query string) (*SearchResponse, error) {
	// Create the URL for the search request
	endpoint := baseURL + searchEndpoint
	params := url.Values{}
	params.Add("q", query)
	params.Add("limit", "20")

	// Make the request
	req, err := http.NewRequestWithContext(ctx, "GET", endpoint+"?"+params.Encode(), nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create search request: %w", err)
	}

	// Send the request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send search request: %w", err)
	}
	defer resp.Body.Close()

	// Check for errors
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("search request failed with status: %s", resp.Status)
	}

	// Parse the response
	var searchResp SearchResponse
	if err := json.NewDecoder(resp.Body).Decode(&searchResp); err != nil {
		return nil, fmt.Errorf("failed to decode search response: %w", err)
	}

	return &searchResp, nil
}

// GetBookDetails gets detailed information about a book
func (c *Client) GetBookDetails(ctx context.Context, workKey string) (*WorksResponse, error) {
	// Ensure the key starts with /works/
	if !strings.HasPrefix(workKey, "/works/") {
		workKey = "/works/" + strings.TrimPrefix(workKey, "/works/")
	}

	// Create the URL for the book details request
	endpoint := baseURL + workKey + ".json"

	// Make the request
	req, err := http.NewRequestWithContext(ctx, "GET", endpoint, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create book details request: %w", err)
	}

	// Send the request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send book details request: %w", err)
	}
	defer resp.Body.Close()

	// Check for errors
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("book details request failed with status: %s", resp.Status)
	}

	// Parse the response
	var worksResp WorksResponse
	if err := json.NewDecoder(resp.Body).Decode(&worksResp); err != nil {
		return nil, fmt.Errorf("failed to decode book details response: %w", err)
	}

	return &worksResp, nil
}

// GetAuthorDetails gets detailed information about an author
func (c *Client) GetAuthorDetails(ctx context.Context, authorKey string) (*AuthorResponse, error) {
	// Ensure the key starts with /authors/
	if !strings.HasPrefix(authorKey, "/authors/") {
		authorKey = "/authors/" + strings.TrimPrefix(authorKey, "/authors/")
	}

	// Create the URL for the author details request
	endpoint := baseURL + authorKey + ".json"

	// Make the request
	req, err := http.NewRequestWithContext(ctx, "GET", endpoint, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create author details request: %w", err)
	}

	// Send the request
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send author details request: %w", err)
	}
	defer resp.Body.Close()

	// Check for errors
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("author details request failed with status: %s", resp.Status)
	}

	// Parse the response
	var authorResp AuthorResponse
	if err := json.NewDecoder(resp.Body).Decode(&authorResp); err != nil {
		return nil, fmt.Errorf("failed to decode author details response: %w", err)
	}

	return &authorResp, nil
}

// GetCoverURL returns the URL for a book cover
func (c *Client) GetCoverURL(coverID int) string {
	if coverID == 0 {
		return ""
	}
	return fmt.Sprintf(coverURLTemplate, fmt.Sprintf("%d", coverID))
}

// ConvertToSessionBook converts an Open Library book to a session Book
func (c *Client) ConvertToSessionBook(book *WorksResponse, authorName string) session.Book {
	coverPath := ""
	if len(book.Covers) > 0 {
		coverPath = c.GetCoverURL(book.Covers[0])
	}

	return session.Book{
		Title:     book.Title,
		Author:    authorName,
		CoverPath: coverPath,
	}
}
