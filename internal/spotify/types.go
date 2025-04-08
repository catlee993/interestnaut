package spotify

// SuggestedTrackInfo holds combined details for a suggested track to be sent to the frontend.
type SuggestedTrackInfo struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Artist      string `json:"artist"` // Primary artist name
	PreviewURL  string `json:"previewUrl,omitempty"`
	AlbumArtURL string `json:"albumArtUrl,omitempty"`
}
