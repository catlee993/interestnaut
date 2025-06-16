package wikipedia

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

const (
	// Base API endpoint for Wikipedia
	wikipediaAPIEndpoint = "https://en.wikipedia.org/w/api.php"

	// Request timeout in seconds
	requestTimeout = 30
)

// Client handles interactions with the Wikipedia API
type Client struct {
	httpClient *http.Client
	userAgent  string
}

// NewClient creates a new Wikipedia client
func NewClient(userAgent string) *Client {
	return &Client{
		httpClient: &http.Client{
			Timeout: time.Second * requestTimeout,
		},
		userAgent: userAgent,
	}
}

// SearchResult represents a search result from Wikipedia
type SearchResult struct {
	Title    string
	PageID   int
	Snippet  string
	URL      string
	ImageURL string
}

// PageInfo represents detailed information about a Wikipedia page
type PageInfo struct {
	Title       string
	PageID      int
	URL         string
	Extract     string
	ImageURL    string
	Categories  []string
	InfoboxData map[string]string
}

// Search searches for Wikipedia pages matching the query
func (c *Client) Search(ctx context.Context, query string, limit int) ([]SearchResult, error) {
	if limit <= 0 {
		limit = 10
	}

	params := url.Values{}
	params.Set("action", "query")
	params.Set("format", "json")
	params.Set("list", "search")
	params.Set("srsearch", query)
	params.Set("srwhat", "text")
	params.Set("srlimit", fmt.Sprintf("%d", limit))
	params.Set("srprop", "snippet")
	params.Set("origin", "*")

	apiURL := fmt.Sprintf("%s?%s", wikipediaAPIEndpoint, params.Encode())

	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("User-Agent", c.userAgent)
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API request failed with status: %s", resp.Status)
	}

	var result struct {
		Query struct {
			Search []struct {
				Title   string `json:"title"`
				PageID  int    `json:"pageid"`
				Snippet string `json:"snippet"`
			} `json:"search"`
		} `json:"query"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	var searchResults []SearchResult
	for _, item := range result.Query.Search {
		// Create a clean URL-friendly title
		urlTitle := strings.ReplaceAll(item.Title, " ", "_")

		searchResults = append(searchResults, SearchResult{
			Title:   item.Title,
			PageID:  item.PageID,
			Snippet: strings.ReplaceAll(item.Snippet, "<span class=\"searchmatch\">", ""),
			URL:     fmt.Sprintf("https://en.wikipedia.org/wiki/%s", url.PathEscape(urlTitle)),
		})
	}

	return searchResults, nil
}

// SearchWithThumbnails searches Wikipedia using the Wikimedia Core API with thumbnail support
func (c *Client) SearchWithThumbnails(ctx context.Context, query string, limit int) ([]SearchResult, error) {
	if limit <= 0 {
		limit = 10
	}

	// Use Wikimedia Core API for better results with thumbnails
	apiURL := fmt.Sprintf("https://api.wikimedia.org/core/v1/wikipedia/en/search/title?q=%s&limit=%d",
		url.QueryEscape(query), limit)

	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("User-Agent", c.userAgent)
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API request failed with status: %s", resp.Status)
	}

	var result struct {
		Pages []struct {
			ID          int    `json:"id"`
			Key         string `json:"key"`
			Title       string `json:"title"`
			Excerpt     string `json:"excerpt"`
			Description string `json:"description"`
			Thumbnail   *struct {
				URL string `json:"url"`
			} `json:"thumbnail"`
		} `json:"pages"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	var searchResults []SearchResult
	for _, item := range result.Pages {
		// Create a clean URL-friendly title
		urlTitle := strings.ReplaceAll(item.Title, " ", "_")

		// Get thumbnail URL if available
		var thumbnailURL string
		if item.Thumbnail != nil && item.Thumbnail.URL != "" {
			// Convert protocol-relative URL to HTTPS
			thumbnailURL = item.Thumbnail.URL
			if strings.HasPrefix(thumbnailURL, "//") {
				thumbnailURL = "https:" + thumbnailURL
			}
		}

		searchResults = append(searchResults, SearchResult{
			Title:    item.Title,
			PageID:   item.ID,
			Snippet:  item.Description, // Use description as snippet
			URL:      fmt.Sprintf("https://en.wikipedia.org/wiki/%s", url.PathEscape(urlTitle)),
			ImageURL: thumbnailURL, // Add image URL to search result
		})
	}

	return searchResults, nil
}

// GetPageInfo retrieves detailed information about a Wikipedia page
func (c *Client) GetPageInfo(ctx context.Context, pageID int) (*PageInfo, error) {
	return c.getPageInfoByID(ctx, pageID)
}

// GetPageInfoByTitle retrieves detailed information about a Wikipedia page by its title
func (c *Client) GetPageInfoByTitle(ctx context.Context, title string) (*PageInfo, error) {
	params := url.Values{}
	params.Set("action", "query")
	params.Set("format", "json")
	params.Set("titles", title)
	params.Set("prop", "pageprops|extracts|images|categories|info")
	params.Set("exintro", "1")
	params.Set("explaintext", "1")
	params.Set("inprop", "url")
	params.Set("origin", "*")

	apiURL := fmt.Sprintf("%s?%s", wikipediaAPIEndpoint, params.Encode())

	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("User-Agent", c.userAgent)
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API request failed with status: %s", resp.Status)
	}

	var result struct {
		Query struct {
			Pages map[string]struct {
				PageID     int    `json:"pageid"`
				Title      string `json:"title"`
				Extract    string `json:"extract"`
				FullURL    string `json:"fullurl"`
				Categories []struct {
					Title string `json:"title"`
				} `json:"categories"`
				Images []struct {
					Title string `json:"title"`
				} `json:"images"`
			} `json:"pages"`
		} `json:"query"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	// Wikipedia returns pages as a map with page IDs as keys
	for _, page := range result.Query.Pages {
		pageInfo := &PageInfo{
			Title:       page.Title,
			PageID:      page.PageID,
			URL:         page.FullURL,
			Extract:     page.Extract,
			InfoboxData: make(map[string]string),
		}

		// Extract categories
		for _, category := range page.Categories {
			// Remove "Category:" prefix
			categoryName := strings.TrimPrefix(category.Title, "Category:")
			pageInfo.Categories = append(pageInfo.Categories, categoryName)
		}

		// Get the first image as the main image
		if len(page.Images) > 0 {
			// Prioritize infobox images and main content images
			var foundImage bool
			for _, img := range page.Images {
				imgTitle := strings.ToLower(img.Title)

				// Skip common non-content images
				if strings.Contains(imgTitle, "commons-logo") ||
					strings.Contains(imgTitle, "wikimedia") ||
					strings.Contains(imgTitle, "edit-icon") ||
					strings.Contains(imgTitle, "symbol") ||
					strings.Contains(imgTitle, "icon") ||
					strings.Contains(imgTitle, "logo") ||
					strings.Contains(imgTitle, "flag") ||
					strings.Contains(imgTitle, "coat of arms") {
					continue
				}

				// Prioritize poster, cover, and main images
				isPriority := strings.Contains(imgTitle, "poster") ||
					strings.Contains(imgTitle, "cover") ||
					strings.Contains(imgTitle, "dvd") ||
					strings.Contains(imgTitle, "blu-ray") ||
					strings.Contains(imgTitle, "theatrical") ||
					strings.Contains(imgTitle, "release") ||
					strings.Contains(imgTitle, ".jpg") ||
					strings.Contains(imgTitle, ".png")

				imageURL, err := c.getImageURL(ctx, img.Title)
				if err == nil && imageURL != "" {
					pageInfo.ImageURL = imageURL
					foundImage = true
					if isPriority {
						break // Use priority images immediately
					}
				}
			}

			// If no image found, try a different approach - get the page's main image
			if !foundImage && len(page.Images) > 0 {
				// Just try the first few images
				for i, img := range page.Images {
					if i >= 3 { // Only try first 3 images
						break
					}
					imageURL, err := c.getImageURL(ctx, img.Title)
					if err == nil && imageURL != "" {
						pageInfo.ImageURL = imageURL
						break
					}
				}
			}
		}

		// Get infobox data
		infoboxData, err := c.getInfoboxData(ctx, page.Title)
		if err == nil {
			pageInfo.InfoboxData = infoboxData
		}

		return pageInfo, nil
	}

	return nil, fmt.Errorf("page not found")
}

// getPageInfoByID retrieves detailed information about a Wikipedia page by its ID
func (c *Client) getPageInfoByID(ctx context.Context, pageID int) (*PageInfo, error) {
	params := url.Values{}
	params.Set("action", "query")
	params.Set("format", "json")
	params.Set("pageids", fmt.Sprintf("%d", pageID))
	params.Set("prop", "extracts|images|categories|info")
	params.Set("exintro", "1")
	params.Set("explaintext", "1")
	params.Set("inprop", "url")
	params.Set("origin", "*")

	apiURL := fmt.Sprintf("%s?%s", wikipediaAPIEndpoint, params.Encode())

	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("User-Agent", c.userAgent)
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API request failed with status: %s", resp.Status)
	}

	var result struct {
		Query struct {
			Pages map[string]struct {
				PageID     int    `json:"pageid"`
				Title      string `json:"title"`
				Extract    string `json:"extract"`
				FullURL    string `json:"fullurl"`
				Categories []struct {
					Title string `json:"title"`
				} `json:"categories"`
				Images []struct {
					Title string `json:"title"`
				} `json:"images"`
			} `json:"pages"`
		} `json:"query"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	pageIDStr := fmt.Sprintf("%d", pageID)
	page, exists := result.Query.Pages[pageIDStr]
	if !exists {
		return nil, fmt.Errorf("page with ID %d not found", pageID)
	}

	pageInfo := &PageInfo{
		Title:       page.Title,
		PageID:      page.PageID,
		URL:         page.FullURL,
		Extract:     page.Extract,
		InfoboxData: make(map[string]string),
	}

	// Extract categories
	for _, category := range page.Categories {
		// Remove "Category:" prefix
		categoryName := strings.TrimPrefix(category.Title, "Category:")
		pageInfo.Categories = append(pageInfo.Categories, categoryName)
	}

	// Get the first image as the main image
	if len(page.Images) > 0 {
		// Prioritize infobox images and main content images
		var foundImage bool
		for _, img := range page.Images {
			imgTitle := strings.ToLower(img.Title)

			// Skip common non-content images
			if strings.Contains(imgTitle, "commons-logo") ||
				strings.Contains(imgTitle, "wikimedia") ||
				strings.Contains(imgTitle, "edit-icon") ||
				strings.Contains(imgTitle, "symbol") ||
				strings.Contains(imgTitle, "icon") ||
				strings.Contains(imgTitle, "logo") ||
				strings.Contains(imgTitle, "flag") ||
				strings.Contains(imgTitle, "coat of arms") {
				continue
			}

			// Prioritize poster, cover, and main images
			isPriority := strings.Contains(imgTitle, "poster") ||
				strings.Contains(imgTitle, "cover") ||
				strings.Contains(imgTitle, "dvd") ||
				strings.Contains(imgTitle, "blu-ray") ||
				strings.Contains(imgTitle, "theatrical") ||
				strings.Contains(imgTitle, "release") ||
				strings.Contains(imgTitle, ".jpg") ||
				strings.Contains(imgTitle, ".png")

			imageURL, err := c.getImageURL(ctx, img.Title)
			if err == nil && imageURL != "" {
				pageInfo.ImageURL = imageURL
				foundImage = true
				if isPriority {
					break // Use priority images immediately
				}
			}
		}

		// If no image found, try a different approach - get the page's main image
		if !foundImage && len(page.Images) > 0 {
			// Just try the first few images
			for i, img := range page.Images {
				if i >= 3 { // Only try first 3 images
					break
				}
				imageURL, err := c.getImageURL(ctx, img.Title)
				if err == nil && imageURL != "" {
					pageInfo.ImageURL = imageURL
					break
				}
			}
		}
	}

	// Get infobox data
	infoboxData, err := c.getInfoboxData(ctx, page.Title)
	if err == nil {
		pageInfo.InfoboxData = infoboxData
	}

	return pageInfo, nil
}

// getImageURL retrieves the URL for a Wikipedia image
func (c *Client) getImageURL(ctx context.Context, imageTitle string) (string, error) {
	// Clean the image title
	imageTitle = strings.TrimSpace(imageTitle)
	if !strings.HasPrefix(imageTitle, "File:") {
		imageTitle = "File:" + imageTitle
	}

	params := url.Values{}
	params.Set("action", "query")
	params.Set("format", "json")
	params.Set("titles", imageTitle)
	params.Set("prop", "imageinfo")
	params.Set("iiprop", "url|size")
	params.Set("iiurlwidth", "300") // Get a reasonable size
	params.Set("origin", "*")

	apiURL := fmt.Sprintf("%s?%s", wikipediaAPIEndpoint, params.Encode())

	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("User-Agent", c.userAgent)
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("API request failed with status: %s", resp.Status)
	}

	var result struct {
		Query struct {
			Pages map[string]struct {
				ImageInfo []struct {
					URL      string `json:"url"`
					ThumbURL string `json:"thumburl"`
					Width    int    `json:"width"`
					Height   int    `json:"height"`
				} `json:"imageinfo"`
			} `json:"pages"`
		} `json:"query"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return "", fmt.Errorf("failed to decode response: %w", err)
	}

	for _, page := range result.Query.Pages {
		if len(page.ImageInfo) > 0 {
			imageInfo := page.ImageInfo[0]

			// Prefer thumbnail URL if available (better for display)
			if imageInfo.ThumbURL != "" {
				return imageInfo.ThumbURL, nil
			}

			// Fall back to original URL
			if imageInfo.URL != "" {
				return imageInfo.URL, nil
			}
		}
	}

	return "", fmt.Errorf("image info not found")
}

// getInfoboxData extracts structured data from the infobox of a Wikipedia page
func (c *Client) getInfoboxData(ctx context.Context, title string) (map[string]string, error) {
	params := url.Values{}
	params.Set("action", "parse")
	params.Set("format", "json")
	params.Set("page", title)
	params.Set("prop", "templates")
	params.Set("origin", "*")

	apiURL := fmt.Sprintf("%s?%s", wikipediaAPIEndpoint, params.Encode())

	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("User-Agent", c.userAgent)
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API request failed with status: %s", resp.Status)
	}

	// Now get the parsed wikitext to extract infobox properties
	params = url.Values{}
	params.Set("action", "parse")
	params.Set("format", "json")
	params.Set("page", title)
	params.Set("prop", "parsetree")
	params.Set("origin", "*")

	apiURL = fmt.Sprintf("%s?%s", wikipediaAPIEndpoint, params.Encode())

	req, err = http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("User-Agent", c.userAgent)
	req.Header.Set("Accept", "application/json")

	resp, err = c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API request failed with status: %s", resp.Status)
	}

	// This is a simplified approach - in a real implementation, we would properly parse the XML
	// or use a more sophisticated method to extract infobox data. For demonstration purposes,
	// we'll use a simpler approach here:

	// Make another request to get just the content in a more processable format
	params = url.Values{}
	params.Set("action", "parse")
	params.Set("format", "json")
	params.Set("page", title)
	params.Set("prop", "wikitext")
	params.Set("origin", "*")

	apiURL = fmt.Sprintf("%s?%s", wikipediaAPIEndpoint, params.Encode())

	req, err = http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("User-Agent", c.userAgent)
	req.Header.Set("Accept", "application/json")

	resp, err = c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	var result struct {
		Parse struct {
			Wikitext struct {
				Content string `json:"*"`
			} `json:"wikitext"`
		} `json:"parse"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}

	wikitext := result.Parse.Wikitext.Content

	// Extract the infobox data using a simple regex approach
	// In a production environment, you would want to use a proper wikitext parser
	infoboxData := parseInfoboxData(wikitext)

	return infoboxData, nil
}

// parseInfoboxData is a simplified parser for infobox data
// In a real implementation, this would be much more robust
func parseInfoboxData(wikitext string) map[string]string {
	data := make(map[string]string)

	// Look for infobox section
	infoboxStart := strings.Index(wikitext, "{{Infobox")
	if infoboxStart == -1 {
		// Try other common infobox templates
		infoboxStart = strings.Index(wikitext, "{{infobox")
	}

	if infoboxStart == -1 {
		return data
	}

	// Find the end of the infobox
	braceCount := 0
	infoboxEnd := infoboxStart

	for i := infoboxStart; i < len(wikitext); i++ {
		if wikitext[i] == '{' && i+1 < len(wikitext) && wikitext[i+1] == '{' {
			braceCount++
			i++
		} else if wikitext[i] == '}' && i+1 < len(wikitext) && wikitext[i+1] == '}' {
			braceCount--
			i++
			if braceCount == 0 {
				infoboxEnd = i + 1
				break
			}
		}
	}

	infoboxText := wikitext[infoboxStart:infoboxEnd]

	// Parse key-value pairs
	lines := strings.Split(infoboxText, "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if !strings.Contains(line, "=") {
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}

		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])

		// Clean up value (remove wiki markup)
		value = cleanWikiMarkup(value)

		if key != "" && value != "" {
			data[key] = value
		}
	}

	return data
}

// cleanWikiMarkup removes common wiki markup from text
func cleanWikiMarkup(text string) string {
	// Remove [[links]]
	for {
		linkStart := strings.Index(text, "[[")
		if linkStart == -1 {
			break
		}

		linkEnd := strings.Index(text[linkStart:], "]]")
		if linkEnd == -1 {
			break
		}

		linkEnd += linkStart

		link := text[linkStart+2 : linkEnd]
		displayText := link

		// Handle pipe links [[page|display]]
		if strings.Contains(link, "|") {
			parts := strings.SplitN(link, "|", 2)
			displayText = parts[1]
		}

		text = text[:linkStart] + displayText + text[linkEnd+2:]
	}

	// Remove '''bold'''
	text = strings.ReplaceAll(text, "'''", "")

	// Remove ''italic''
	text = strings.ReplaceAll(text, "''", "")

	// Remove <ref>...</ref>
	for {
		refStart := strings.Index(text, "<ref")
		if refStart == -1 {
			break
		}

		refEnd := strings.Index(text[refStart:], "</ref>")
		if refEnd == -1 {
			break
		}

		refEnd += refStart + 6
		text = text[:refStart] + text[refEnd:]
	}

	// Remove {{templates}}
	braceStack := 0
	var cleanText strings.Builder
	i := 0

	for i < len(text) {
		if i+1 < len(text) && text[i:i+2] == "{{" {
			braceStack++
			i += 2
		} else if i+1 < len(text) && text[i:i+2] == "}}" {
			braceStack--
			i += 2
		} else {
			if braceStack == 0 {
				cleanText.WriteByte(text[i])
			}
			i++
		}
	}

	return strings.TrimSpace(cleanText.String())
}
