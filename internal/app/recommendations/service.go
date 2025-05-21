package recommendations

import (
	"context"
	"fmt"
	"log"

	"interestnaut/internal/app/db"
	"interestnaut/internal/app/models"
	"interestnaut/internal/app/wikidata"
	"interestnaut/internal/app/wikipedia"

	"github.com/pkg/errors"
)

// Service handles the logic for media recommendations.
type Service struct {
	dbClient        db.Database
	wikidataClient  *wikidata.Client
	wikipediaClient *wikipedia.Client
}

// NewService creates a new Recommendation service.
func NewService(dbClient db.Database, wdClient *wikidata.Client, wpClient *wikipedia.Client) *Service {
	if dbClient == nil {
		log.Println("ERROR: NewService (recommendations) received nil dbClient")
		return nil
	}
	if wdClient == nil {
		log.Println("ERROR: NewService (recommendations) received nil wikidataClient")
		return nil
	}
	if wpClient == nil {
		log.Println("ERROR: NewService (recommendations) received nil wikipediaClient")
		return nil
	}
	return &Service{
		dbClient:        dbClient,
		wikidataClient:  wdClient,
		wikipediaClient: wpClient,
	}
}

// FindAndSaveSuggestion attempts to find a media item based on a raw query,
// enriches it with data from Wikidata/Wikipedia, and saves it as a pending suggestion.
func (s *Service) FindAndSaveSuggestion(ctx context.Context, rawQuery string, mediaTypeStr string, botReasoning string) (*models.MediaSuggestion, error) {
	if rawQuery == "" {
		return nil, errors.New("rawQuery cannot be empty")
	}
	if mediaTypeStr == "" {
		return nil, errors.New("mediaTypeStr cannot be empty")
	}

	var wdMediaType wikidata.MediaType
	switch mediaTypeStr {
	case "music":
		wdMediaType = wikidata.MediaTypeMusic
	case "book":
		wdMediaType = wikidata.MediaTypeBook
	case "movie":
		wdMediaType = wikidata.MediaTypeMovie
	case "show":
		wdMediaType = wikidata.MediaTypeShow
	case "game":
		wdMediaType = wikidata.MediaTypeVideoGame
	default:
		return nil, fmt.Errorf("unsupported media type string for Wikidata: %s", mediaTypeStr)
	}

	searchResults, err := s.wikidataClient.SearchEntities(ctx, rawQuery, wdMediaType, "en")
	if err != nil {
		return nil, errors.Wrap(err, "failed to search Wikidata entities")
	}

	if len(searchResults) == 0 {
		log.Printf("No Wikidata results found for query: '%s', mediaType: '%s'. Saving basic suggestion.", rawQuery, mediaTypeStr)
		suggestion := &models.MediaSuggestion{
			Query:     rawQuery,
			MediaType: mediaTypeStr,
			Status:    models.StatusPending,
		}
		if botReasoning != "" {
			suggestion.BotReasoning = &botReasoning
		}
		if dbErr := s.dbClient.SaveMediaSuggestion(ctx, suggestion); dbErr != nil {
			return nil, errors.Wrap(dbErr, "failed to save basic suggestion after no Wikidata match")
		}
		return suggestion, nil
	}

	bestMatch := searchResults[0]
	mediaInfo, err := s.wikidataClient.GetMediaInfo(ctx, bestMatch.ID, wdMediaType)
	if err != nil {
		log.Printf("Failed to get full MediaInfo from Wikidata for ID %s ('%s'): %v. Proceeding with basic search result data.", bestMatch.ID, bestMatch.Label, err)
		// Fallback to basic data from searchResults if GetMediaInfo fails
		mediaInfo = &wikidata.MediaInfo{
			WikidataID:  bestMatch.ID,
			Title:       bestMatch.Label,
			Description: bestMatch.Description,
		}
	}

	suggestion := &models.MediaSuggestion{
		Query:     rawQuery,
		MediaType: mediaTypeStr,
		Status:    models.StatusPending,
	}

	if mediaInfo.Title != "" {
		suggestion.Title = &mediaInfo.Title
	}
	if mediaInfo.Description != "" {
		suggestion.Description = &mediaInfo.Description
	}
	if mediaInfo.WikidataID != "" {
		suggestion.WikidataID = &mediaInfo.WikidataID
	}
	if botReasoning != "" {
		suggestion.BotReasoning = &botReasoning
	}
	if mediaInfo.ImageURL != "" {
		suggestion.CoverArtURL = &mediaInfo.ImageURL
	}
	if mediaInfo.WikipediaURL != "" {
		suggestion.WikiURL = &mediaInfo.WikipediaURL
	}

	switch wdMediaType {
	case wikidata.MediaTypeMusic:
		if mediaInfo.Artist != "" {
			suggestion.Artist = &mediaInfo.Artist
		}
		if mediaInfo.Album != "" {
			suggestion.Album = &mediaInfo.Album
		}
	case wikidata.MediaTypeBook:
		if mediaInfo.Author != "" {
			suggestion.Artist = &mediaInfo.Author // Use Artist field for book authors
		}
	case wikidata.MediaTypeMovie, wikidata.MediaTypeShow:
		if mediaInfo.Director != "" {
			suggestion.Artist = &mediaInfo.Director // Use Artist field for directors
		}
	case wikidata.MediaTypeVideoGame:
		if mediaInfo.Developer != "" {
			suggestion.Artist = &mediaInfo.Developer // Use Artist field for game developers
		}
	}

	if err := s.dbClient.SaveMediaSuggestion(ctx, suggestion); err != nil {
		return nil, errors.Wrap(err, "failed to save media suggestion")
	}

	log.Printf("Successfully found and saved suggestion: ID %s, Title %s", suggestion.ID, PtrToString(suggestion.Title))
	return suggestion, nil
}

// GetAllSuggestions retrieves all suggestions, optionally filtered.
func (s *Service) GetAllSuggestions(ctx context.Context, mediaType string, statusFilter models.SuggestionStatus, limit int, offset int) ([]*models.MediaSuggestion, error) {
	return s.dbClient.GetAllMediaSuggestions(ctx, mediaType, statusFilter, limit, offset)
}

// UpdateSuggestionStatus updates the status of a specific suggestion.
func (s *Service) UpdateSuggestionStatus(ctx context.Context, suggestionID string, status models.SuggestionStatus) error {
	if suggestionID == "" {
		return errors.New("suggestionID cannot be empty")
	}
	if !models.IsValidStatus(string(status)) {
		return fmt.Errorf("invalid suggestion status: %s", status)
	}
	return s.dbClient.UpdateMediaSuggestionStatus(ctx, suggestionID, status)
}

// GetPendingSuggestionsCount returns the count of pending suggestions for a given media type.
func (s *Service) GetPendingSuggestionsCount(ctx context.Context, mediaType string) (int, error) {
	if mediaType == "" {
		// Depending on desired behavior, you might want to count all pending or return an error.
		// For now, let's assume an empty mediaType means count for all types if the DB method supports it,
		// or it's an error if the DB method requires a specific type.
		// The current db.CountPendingMediaSuggestions requires a mediaType.
		return 0, errors.New("mediaType cannot be empty for GetPendingSuggestionsCount")
	}
	return s.dbClient.CountPendingMediaSuggestions(ctx, mediaType)
}

// PtrToString safely dereferences a string pointer for logging or other non-critical uses.
func PtrToString(s *string) string {
	if s == nil {
		return "<nil>"
	}
	return *s
}
