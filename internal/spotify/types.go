package spotify

// SuggestedTrackInfo holds combined details for a suggested track to be sent to the frontend.
type SuggestedTrackInfo struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Artist      string `json:"artist"`
	Album       string `json:"album"`
	PreviewURL  string `json:"previewUrl,omitempty"`
	AlbumArtURL string `json:"albumArtUrl,omitempty"`
	Reason      string `json:"reason,omitempty"`
}

// AuthConfig represents the Spotify OAuth configuration.
type AuthConfig struct {
	ClientID    string
	RedirectURI string
}
