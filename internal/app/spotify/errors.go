package spotify

import "errors"

var (
	// ErrNotAuthenticated is returned when trying to access Spotify API without authentication
	ErrNotAuthenticated = errors.New("not authenticated with Spotify")
)
