package llm

import (
	"context"
	"interestnaut/internal/session"
)

type Client[T session.Media] interface {
	ComposeMessages(context.Context, *session.Content[T]) ([]Message, error)
	SendMessages(context.Context, ...Message) (string, error)
}
