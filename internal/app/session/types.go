package session

import (
	"encoding/json"
	"fmt"
)

const DefaultUserID string = "default_user"

type Key string

type Outcome string

const Ext string = ".json"
const SettingsSuffix string = "_settings" + Ext

// specific string values will hopefully be clearer to whatever LLM
const (
	Liked    Outcome = "liked"
	Disliked Outcome = "disliked"
	Skipped  Outcome = "skipped"
	Pending  Outcome = "pending"
	Added    Outcome = "added"
)

type Music struct {
	Title  string `json:"title"`
	Artist string `json:"artist"`
	Album  string `json:"album"`
}

type Movie struct {
	Title      string `json:"title"`
	Director   string `json:"director"`
	Writer     string `json:"writer"`
	PosterPath string `json:"poster_path"`
}

type Book struct {
	Title     string `json:"title"`
	Author    string `json:"author"`
	CoverPath string `json:"cover_path"`
}

type TVShow struct {
	Title      string `json:"title"`
	Director   string `json:"director"`
	Writer     string `json:"writer"`
	PosterPath string `json:"poster_path"`
}

type VideoGame struct {
	Title     string   `json:"title"`
	Developer string   `json:"developer"`
	Publisher string   `json:"publisher"`
	Platforms []string `json:"platforms"`
	CoverPath string   `json:"cover_path"`
}

type EquatableMedia interface {
	Equal(other any) bool
	Key() string
}

type Media interface {
	EquatableMedia
}

func (m Music) Equal(other any) bool {
	o, ok := other.(Music)
	return ok && m.Title == o.Title &&
		m.Artist == o.Artist &&
		m.Album == o.Album
}

func (m Music) Key() string {
	return sanitizeKey(fmt.Sprintf("%s_%s_%s", m.Title, m.Artist, m.Album))
}

func (m Movie) Equal(other any) bool {
	o, ok := other.(Movie)
	return ok && m.Title == o.Title &&
		m.Director == o.Director &&
		m.Writer == o.Writer
}

func (m Movie) Key() string {
	return sanitizeKey(fmt.Sprintf("%s_%s_%s", m.Title, m.Director, m.Writer))
}

func (m Book) Equal(other any) bool {
	o, ok := other.(Book)
	return ok && m.Title == o.Title &&
		m.Author == o.Author
}

func (m Book) Key() string {
	return sanitizeKey(fmt.Sprintf("%s_%s", m.Title, m.Author))
}

func (m TVShow) Equal(other any) bool {
	o, ok := other.(TVShow)
	return ok && m.Title == o.Title &&
		m.Director == o.Director &&
		m.Writer == o.Writer
}

func (m TVShow) Key() string {
	return sanitizeKey(fmt.Sprintf("%s_%s_%s", m.Title, m.Director, m.Writer))
}

func (m VideoGame) Equal(other any) bool {
	o, ok := other.(VideoGame)

	return ok && m.Title == o.Title &&
		m.Developer == o.Developer &&
		m.Publisher == o.Publisher &&
		m.CoverPath == o.CoverPath
}

func (m VideoGame) Key() string {
	return sanitizeKey(fmt.Sprintf("%s_%s_%s", m.Title, m.Developer, m.Publisher))
}

type Suggestion[T Media] struct {
	PrimaryGenre string  `json:"primary_genre"`
	Reasoning    string  `json:"reasoning"`
	UserOutcome  Outcome `json:"user_outcome"`
	RespondedAt  int64   `json:"responded_at"`
	Content      T       `json:"content"`
}

type PrimeDirective struct {
	Task     string `json:"task"`
	Baseline string `json:"baseline"`
}

type Content[T Media] struct {
	PrimeDirective  `json:"prime_directive"`
	Suggestions     map[string]Suggestion[T] `json:"suggestions"`
	UserConstraints []string                 `json:"user_constraints"` // Miscellaneous user-defined constraints that can help temper suggestions
}

func (c Content[T]) ToString() (string, error) {
	str, err := json.Marshal(c)
	if err != nil {
		return "", err
	}

	return string(str), nil
}

type Session[T Media] struct {
	Key
	Content[T] `json:"content"`
}

// Favorites stores user favorites for all media types sans Spotify governed music
type Favorites struct {
	Movies     []Movie     `json:"movies"`
	Books      []Book      `json:"books"`
	TVShows    []TVShow    `json:"tv_shows"`
	VideoGames []VideoGame `json:"video_games"`
}

// Queued stores user queued items for all media types (except music)
type Queued struct {
	Movies     []Movie     `json:"movies"`
	Books      []Book      `json:"books"`
	TVShows    []TVShow    `json:"tv_shows"`
	VideoGames []VideoGame `json:"video_games"`
}

type Comparator[T Media] func(Suggestion[T], Suggestion[T]) bool

type MapKeyer[T Media] func(Suggestion[T]) string
