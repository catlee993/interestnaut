package bindings

import (
	"context"
	"interestnaut/internal/session"
)

type Settings struct {
	ContentManager session.CentralManager
}

func (s *Settings) GetContinuousPlayback() bool {
	return s.ContentManager.Settings().GetContinuousPlayback()
}

func (s *Settings) SetContinuousPlayback(continuous bool) error {
	return s.ContentManager.Settings().SetContinuousPlayback(context.Background(), continuous)
}

func (s *Settings) GetChatGPTModel() string {
	return s.ContentManager.Settings().GetChatGPTModel()
}

func (s *Settings) SetChatGPTModel(model string) error {
	return s.ContentManager.Settings().SetChatGPTModel(context.Background(), model)
}
