package directives

import (
	"context"
	"interestnaut/internal/spotify"
)

type Director interface {
	GetMusicBaseline(ctx context.Context) string
}

type director struct {
	spotify.Client
}

func NewDirector(client spotify.Client) Director {
	return &director{
		Client: client,
	}
}
