package spotify

// Image represents a Spotify image
type Image struct {
	URL    string `json:"url"`
	Height int    `json:"height"`
	Width  int    `json:"width"`
}

// Artist represents a Spotify artist
type Artist struct {
	ID     string   `json:"id"`
	Name   string   `json:"name"`
	Genres []string `json:"genres"`
}

// Album represents a Spotify album
type Album struct {
	ID     string  `json:"id"`
	Name   string  `json:"name"`
	Images []Image `json:"images"`
}

// UserProfile represents a Spotify user's profile data.
type UserProfile struct {
	ID          string   `json:"id"`
	DisplayName string   `json:"display_name"`
	Email       string   `json:"email"`
	Country     string   `json:"country"`
	Genres      []string `json:"genres"`
	Images      []Image  `json:"images"`
}

// Track represents a Spotify track with full details
type Track struct {
	ID         string   `json:"id"`
	Name       string   `json:"name"`
	Artists    []Artist `json:"artists"`
	Album      Album    `json:"album"`
	PreviewUrl string   `json:"preview_url"`
	URI        string   `json:"uri"`
}

// SimpleTrack is a simplified track representation for the frontend
type SimpleTrack struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Artist      string `json:"artist"`
	ArtistID    string `json:"artistId"`
	Album       string `json:"album"`
	AlbumID     string `json:"albumId"`
	AlbumArtUrl string `json:"albumArtUrl"`
	PreviewUrl  string `json:"previewUrl"`
	URI         string `json:"uri"`
}

// SavedTrackItem represents a single saved track with metadata
type SavedTrackItem struct {
	Track   *Track `json:"track"`
	AddedAt string `json:"added_at"`
}

// SearchResults represents search results from Spotify
type SearchResults struct {
	Tracks struct {
		Items []*Track `json:"items"`
	} `json:"tracks"`
}

// SavedTracks represents the response from getting user's saved tracks
type SavedTracks struct {
	Items    []SavedTrackItem `json:"items"`
	Total    int              `json:"total"`
	Limit    int              `json:"limit"`
	Offset   int              `json:"offset"`
	Next     string           `json:"next"`
	Previous string           `json:"previous"`
}

type AuthResponse struct {
	AccessToken  string `json:"access_token"`
	TokenType    string `json:"token_type"`
	ExpiresIn    int    `json:"expires_in"`
	RefreshToken string `json:"refresh_token"`
	Scope        string `json:"scope"`
}
