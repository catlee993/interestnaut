package llm

import (
	"context"
	"interestnaut/internal/session"
)

type Client[T session.Media] interface {
	ComposeMessage(context.Context, *session.Content[T]) (Message, error)
	SendMessage(context.Context, Message) (string, error)
}
