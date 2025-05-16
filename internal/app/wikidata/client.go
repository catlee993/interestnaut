package wikidata

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
	// Base API endpoint for Wikidata
	wikidataAPIEndpoint = "https://www.wikidata.org/w/api.php"
	
	// Base entity data endpoint
	wikidataEntityEndpoint = "https://www.wikidata.org/wiki/Special:EntityData"
	
	// Base SPARQL query endpoint
	sparqlEndpoint = "https://query.wikidata.org/sparql"
	
	// Request timeout in seconds
	requestTimeout = 30
)

// Client handles interactions with the Wikidata API
type Client struct {
	httpClient *http.Client
	userAgent  string
}

// NewClient creates a new Wikidata client
func NewClient(userAgent string) *Client {
	return &Client{
		httpClient: &http.Client{
			Timeout: time.Second * requestTimeout,
		},
		userAgent: userAgent,
	}
}

// MediaType represents the type of media being searched
type MediaType string

// Media type constants
const (
	MediaTypeMusic     MediaType = "music"
	MediaTypeBook      MediaType = "book"
	MediaTypeMovie     MediaType = "movie"
	MediaTypeShow      MediaType = "show"
	MediaTypeVideoGame MediaType = "video_game"
)

// EntityResponse represents a Wikidata entity response
type EntityResponse struct {
	Entities map[string]Entity `json:"entities"`
}

// Entity represents a Wikidata entity
type Entity struct {
	ID          string                 `json:"id"`
	Type        string                 `json:"type"`
	Labels      map[string]Label       `json:"labels"`
	Descriptions map[string]Description `json:"descriptions"`
	Claims      map[string][]Claim     `json:"claims"`
	Sitelinks   map[string]Sitelink    `json:"sitelinks"`
}

// Label represents a label in a specific language
type Label struct {
	Language string `json:"language"`
	Value    string `json:"value"`
}

// Description represents a description in a specific language
type Description struct {
	Language string `json:"language"`
	Value    string `json:"value"`
}

// Claim represents a property claim in Wikidata
type Claim struct {
	MainSnak Snak                  `json:"mainsnak"`
	Type     string                `json:"type"`
	ID       string                `json:"id"`
	Rank     string                `json:"rank"`
	Qualifiers map[string][]Snak   `json:"qualifiers,omitempty"`
}

// Snak represents a property value in Wikidata
type Snak struct {
	SnakType    string      `json:"snaktype"`
	Property    string      `json:"property"`
	DataType    string      `json:"datatype,omitempty"`
	DataValue   *DataValue  `json:"datavalue,omitempty"`
}

// DataValue represents the value of a property
type DataValue struct {
	Value interface{} `json:"value"`
	Type  string      `json:"type"`
}

// Sitelink represents a link to a page on a Wikimedia site
type Sitelink struct {
	Site  string `json:"site"`
	Title string `json:"title"`
	URL   string `json:"url,omitempty"`
}

// SearchResult represents a search result from Wikidata
type SearchResult struct {
	ID          string `json:"id"`
	Label       string `json:"label"`
	Description string `json:"description"`
	URL         string `json:"url"`
}

// Property codes for different media types
var (
	// Common properties
	PropInstanceOf      = "P31"  // Instance of
	PropTitle           = "P1476" // Title
	PropImage           = "P18"  // Image
	
	// Music properties
	PropPerformer       = "P175" // Performer
	PropMusicComposer   = "P86"  // Composer
	PropAlbum           = "P361" // Part of (album)
	
	// Book properties
	PropAuthor          = "P50"  // Author
	PropPublisher       = "P123" // Publisher
	
	// Movie and show properties
	PropDirector        = "P57"  // Director
	PropScreenwriter    = "P58"  // Screenwriter
	
	// Video game properties
	PropDeveloper       = "P178" // Developer
	PropPlatform        = "P400" // Platform
)

// Items IDs for instance classification
var (
	// Music
	ItemMusic           = "Q638"   // Music
	ItemAlbum           = "Q482994" // Album
	ItemSong            = "Q7366"  // Song
	
	// Books
	ItemBook            = "Q571"   // Book
	ItemNovel           = "Q8261"  // Novel
	
	// Movies
	ItemFilm            = "Q11424" // Film
	ItemMovie           = "Q31629" // Movie
	
	// Shows
	ItemTVSeries        = "Q5398426" // Television series
	
	// Video Games
	ItemVideoGame       = "Q7889"  // Video game
)

// SearchEntities searches for entities matching the query
func (c *Client) SearchEntities(ctx context.Context, query string, mediaType MediaType, language string) ([]SearchResult, error) {
	if language == "" {
		language = "en"
	}
	
	params := url.Values{}
	params.Set("action", "wbsearchentities")
	params.Set("format", "json")
	params.Set("search", query)
	params.Set("language", language)
	params.Set("limit", "10")
	params.Set("origin", "*")
	
	// Filter by type based on mediaType
	var typeFilterProperty string
	switch mediaType {
	case MediaTypeMusic:
		params.Set("type", "item")
		typeFilterProperty = fmt.Sprintf("haswbstatement:%s=%s|%s|%s", PropInstanceOf, ItemMusic, ItemAlbum, ItemSong)
	case MediaTypeBook:
		params.Set("type", "item")
		typeFilterProperty = fmt.Sprintf("haswbstatement:%s=%s|%s", PropInstanceOf, ItemBook, ItemNovel)
	case MediaTypeMovie:
		params.Set("type", "item")
		typeFilterProperty = fmt.Sprintf("haswbstatement:%s=%s|%s", PropInstanceOf, ItemFilm, ItemMovie)
	case MediaTypeShow:
		params.Set("type", "item")
		typeFilterProperty = fmt.Sprintf("haswbstatement:%s=%s", PropInstanceOf, ItemTVSeries)
	case MediaTypeVideoGame:
		params.Set("type", "item")
		typeFilterProperty = fmt.Sprintf("haswbstatement:%s=%s", PropInstanceOf, ItemVideoGame)
	default:
		params.Set("type", "item")
	}
	
	if typeFilterProperty != "" {
		params.Set("profile", typeFilterProperty)
	}
	
	apiURL := fmt.Sprintf("%s?%s", wikidataAPIEndpoint, params.Encode())
	
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
		Search []struct {
			ID          string `json:"id"`
			Label       string `json:"label"`
			Description string `json:"description"`
		} `json:"search"`
	}
	
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}
	
	var searchResults []SearchResult
	for _, item := range result.Search {
		searchResults = append(searchResults, SearchResult{
			ID:          item.ID,
			Label:       item.Label,
			Description: item.Description,
			URL:         fmt.Sprintf("https://www.wikidata.org/wiki/%s", item.ID),
		})
	}
	
	return searchResults, nil
}

// GetEntity retrieves a specific entity by ID
func (c *Client) GetEntity(ctx context.Context, entityID string, language string) (*Entity, error) {
	if language == "" {
		language = "en"
	}
	
	params := url.Values{}
	params.Set("action", "wbgetentities")
	params.Set("format", "json")
	params.Set("ids", entityID)
	params.Set("languages", language)
	params.Set("props", "labels|descriptions|claims|sitelinks")
	params.Set("sitefilter", "enwiki")
	params.Set("origin", "*")
	
	apiURL := fmt.Sprintf("%s?%s", wikidataAPIEndpoint, params.Encode())
	
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
	
	var entityResp EntityResponse
	if err := json.NewDecoder(resp.Body).Decode(&entityResp); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}
	
	entity, exists := entityResp.Entities[entityID]
	if !exists {
		return nil, fmt.Errorf("entity with ID %s not found", entityID)
	}
	
	return &entity, nil
}

// ExecuteSPARQL executes a SPARQL query against the Wikidata Query Service
func (c *Client) ExecuteSPARQL(ctx context.Context, query string) ([]map[string]interface{}, error) {
	params := url.Values{}
	params.Set("query", query)
	params.Set("format", "json")
	
	apiURL := fmt.Sprintf("%s?%s", sparqlEndpoint, params.Encode())
	
	req, err := http.NewRequestWithContext(ctx, "GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	
	req.Header.Set("User-Agent", c.userAgent)
	req.Header.Set("Accept", "application/sparql-results+json")
	
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API request failed with status: %s", resp.Status)
	}
	
	var result struct {
		Head struct {
			Vars []string `json:"vars"`
		} `json:"head"`
		Results struct {
			Bindings []map[string]struct {
				Type  string `json:"type"`
				Value string `json:"value"`
			} `json:"bindings"`
		} `json:"results"`
	}
	
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}
	
	var results []map[string]interface{}
	for _, binding := range result.Results.Bindings {
		row := make(map[string]interface{})
		for k, v := range binding {
			row[k] = v.Value
		}
		results = append(results, row)
	}
	
	return results, nil
}

// GetStringClaimValue extracts a string value from a claim
func GetStringClaimValue(entity *Entity, property string, language string) string {
	if entity == nil || property == "" {
		return ""
	}
	
	claims, exists := entity.Claims[property]
	if !exists || len(claims) == 0 {
		return ""
	}
	
	for _, claim := range claims {
		if claim.MainSnak.SnakType == "value" && claim.MainSnak.DataValue != nil {
			if claim.MainSnak.DataValue.Type == "string" {
				if str, ok := claim.MainSnak.DataValue.Value.(string); ok {
					return str
				}
			} else if claim.MainSnak.DataValue.Type == "monolingualtext" {
				if textObj, ok := claim.MainSnak.DataValue.Value.(map[string]interface{}); ok {
					if textObj["language"] == language {
						if text, ok := textObj["text"].(string); ok {
							return text
						}
					}
				}
			}
		}
	}
	
	return ""
}

// GetEntityClaimValue extracts an entity ID from a claim
func GetEntityClaimValue(entity *Entity, property string) string {
	if entity == nil || property == "" {
		return ""
	}
	
	claims, exists := entity.Claims[property]
	if !exists || len(claims) == 0 {
		return ""
	}
	
	for _, claim := range claims {
		if claim.MainSnak.SnakType == "value" && claim.MainSnak.DataValue != nil {
			if claim.MainSnak.DataValue.Type == "wikibase-entityid" {
				if entityObj, ok := claim.MainSnak.DataValue.Value.(map[string]interface{}); ok {
					if id, ok := entityObj["id"].(string); ok {
						return id
					}
				}
			}
		}
	}
	
	return ""
}

// GetWikipediaURL extracts the Wikipedia URL from an entity
func GetWikipediaURL(entity *Entity) string {
	if entity == nil {
		return ""
	}
	
	if sitelink, exists := entity.Sitelinks["enwiki"]; exists {
		title := strings.ReplaceAll(sitelink.Title, " ", "_")
		return fmt.Sprintf("https://en.wikipedia.org/wiki/%s", url.PathEscape(title))
	}
	
	return ""
}

// MediaInfo represents structured information about a media item
type MediaInfo struct {
	WikidataID  string
	Title       string
	Description string
	ImageURL    string
	WikipediaURL string
	
	// Music specific
	Artist      string
	Album       string
	
	// Book specific
	Author      string
	
	// Movie and Show specific
	Director    string
	Writer      string
	
	// Video Game specific
	Developer   string
	Platforms   []string
}

// GetMediaInfo retrieves structured information about a media item
func (c *Client) GetMediaInfo(ctx context.Context, entityID string, mediaType MediaType) (*MediaInfo, error) {
	entity, err := c.GetEntity(ctx, entityID, "en")
	if err != nil {
		return nil, err
	}
	
	info := &MediaInfo{
		WikidataID: entityID,
	}
	
	// Extract title
	if labels, ok := entity.Labels["en"]; ok {
		info.Title = labels.Value
	}
	
	// Extract description
	if desc, ok := entity.Descriptions["en"]; ok {
		info.Description = desc.Value
	}
	
	// Extract Wikipedia URL
	info.WikipediaURL = GetWikipediaURL(entity)
	
	// Extract image URL if available
	imageFile := GetStringClaimValue(entity, PropImage, "en")
	if imageFile != "" {
		// Convert to Wikimedia Commons URL
		imageFile = strings.ReplaceAll(imageFile, " ", "_")
		md5prefix := getMD5Prefix(imageFile)
		info.ImageURL = fmt.Sprintf("https://upload.wikimedia.org/wikipedia/commons/%s/%s/%s", 
			md5prefix[0:1], md5prefix[0:2], url.PathEscape(imageFile))
	}
	
	// Extract media-specific properties
	switch mediaType {
	case MediaTypeMusic:
		// For music, get artist and album
		artistID := GetEntityClaimValue(entity, PropPerformer)
		if artistID != "" {
			artistEntity, err := c.GetEntity(ctx, artistID, "en")
			if err == nil && artistEntity != nil {
				if label, ok := artistEntity.Labels["en"]; ok {
					info.Artist = label.Value
				}
			}
		}
		
		albumID := GetEntityClaimValue(entity, PropAlbum)
		if albumID != "" {
			albumEntity, err := c.GetEntity(ctx, albumID, "en")
			if err == nil && albumEntity != nil {
				if label, ok := albumEntity.Labels["en"]; ok {
					info.Album = label.Value
				}
			}
		}
		
	case MediaTypeBook:
		// For books, get author
		authorID := GetEntityClaimValue(entity, PropAuthor)
		if authorID != "" {
			authorEntity, err := c.GetEntity(ctx, authorID, "en")
			if err == nil && authorEntity != nil {
				if label, ok := authorEntity.Labels["en"]; ok {
					info.Author = label.Value
				}
			}
		}
		
	case MediaTypeMovie, MediaTypeShow:
		// For movies and shows, get director and writer
		directorID := GetEntityClaimValue(entity, PropDirector)
		if directorID != "" {
			directorEntity, err := c.GetEntity(ctx, directorID, "en")
			if err == nil && directorEntity != nil {
				if label, ok := directorEntity.Labels["en"]; ok {
					info.Director = label.Value
				}
			}
		}
		
		writerID := GetEntityClaimValue(entity, PropScreenwriter)
		if writerID != "" {
			writerEntity, err := c.GetEntity(ctx, writerID, "en")
			if err == nil && writerEntity != nil {
				if label, ok := writerEntity.Labels["en"]; ok {
					info.Writer = label.Value
				}
			}
		}
		
	case MediaTypeVideoGame:
		// For video games, get developer and platforms
		developerID := GetEntityClaimValue(entity, PropDeveloper)
		if developerID != "" {
			developerEntity, err := c.GetEntity(ctx, developerID, "en")
			if err == nil && developerEntity != nil {
				if label, ok := developerEntity.Labels["en"]; ok {
					info.Developer = label.Value
				}
			}
		}
		
		// Get platforms
		claims, exists := entity.Claims[PropPlatform]
		if exists && len(claims) > 0 {
			for _, claim := range claims {
				if claim.MainSnak.SnakType == "value" && claim.MainSnak.DataValue != nil {
					if claim.MainSnak.DataValue.Type == "wikibase-entityid" {
						if entityObj, ok := claim.MainSnak.DataValue.Value.(map[string]interface{}); ok {
							if id, ok := entityObj["id"].(string); ok {
								platformEntity, err := c.GetEntity(ctx, id, "en")
								if err == nil && platformEntity != nil {
									if label, ok := platformEntity.Labels["en"]; ok {
										info.Platforms = append(info.Platforms, label.Value)
									}
								}
							}
						}
					}
				}
			}
		}
	}
	
	return info, nil
}

// getMD5Prefix is a helper function to convert a filename to an MD5 prefix
// for Wikimedia Commons URLs (simplified for example)
func getMD5Prefix(filename string) string {
	// In a real implementation, this would calculate an MD5 hash
	// For simplicity, we'll just return a placeholder
	return "ab/abc"
}
