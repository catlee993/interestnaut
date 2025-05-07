package llm

import (
	"context"
	"interestnaut/internal/app/session"
)

type Client[T session.Media] interface {
	ComposeMessages(context.Context, *session.Content[T]) ([]Message, error)
	SendMessages(context.Context, ...Message) (*SuggestionResponse[T], error)
	ErrorFollowup(context.Context, *SuggestionResponse[T], ...Message) (*SuggestionResponse[T], error)
}
