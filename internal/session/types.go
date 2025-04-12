package session

import "encoding/json"

const DefaultUserID string = "default_user" // TODO: no plan to support multiple users yet, but will think about it later

type Key string

type Outcome string

const Ext string = ".json"

// specific string values will hopefully be clearer to whatever LLM
const (
	Liked    Outcome = "liked"
	Disliked Outcome = "disliked"
	Skipped  Outcome = "skipped"
	Pending  Outcome = "pending"
	Added    Outcome = "added"
)

type Music struct {
	Artist string `json:"artist"`
	Album  string `json:"album"`
}

type Movie struct {
	Director   string `json:"director"`
	Writer     string `json:"writer"`
	IMDBRating string `json:"imdb_rating"`
}

type Book struct {
	Author string `json:"author"`
}

type TVShow struct {
	Director   string `json:"director"`
	Writer     string `json:"writer"`
	IMDBRating string `json:"imdb_rating"`
}

type VideoGame struct {
	Developer string   `json:"developer"`
	Publisher string   `json:"publisher"`
	Platforms []string `json:"platforms"`
}

type Media interface {
	Music | Movie | Book | TVShow | VideoGame
}

type Suggestion[T Media] struct {
	Title        string  `json:"title"`
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
	UserConstraints []string                 `json:"user_constraints"` // Miscellaneous user-defined constraints that
} // can help temper suggestions

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

type Comparator[T Media] func(Suggestion[T], Suggestion[T]) bool

type MapKeyer[T Media] func(Suggestion[T]) string
