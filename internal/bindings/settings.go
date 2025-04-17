package bindings

import (
	"context"
	"interestnaut/internal/session"
	"log"
)

type Settings struct {
	ContentManager session.CentralManager
}

func (s *Settings) GetContinuousPlayback() bool {
	if s.ContentManager == nil || s.ContentManager.Settings() == nil {
		log.Printf("WARNING: ContentManager or Settings is nil in GetContinuousPlayback")
		return false
	}
	value := s.ContentManager.Settings().GetContinuousPlayback()
	log.Printf("GetContinuousPlayback returning: %v", value)
	return value
}

func (s *Settings) SetContinuousPlayback(continuous bool) error {
	if s.ContentManager == nil || s.ContentManager.Settings() == nil {
		log.Printf("ERROR: ContentManager or Settings is nil in SetContinuousPlayback")
		return nil
	}
	log.Printf("SetContinuousPlayback called with value: %v", continuous)
	return s.ContentManager.Settings().SetContinuousPlayback(context.Background(), continuous)
}

func (s *Settings) GetChatGPTModel() string {
	if s.ContentManager == nil || s.ContentManager.Settings() == nil {
		log.Printf("WARNING: ContentManager or Settings is nil in GetChatGPTModel")
		return "gpt-4o"
	}
	value := s.ContentManager.Settings().GetChatGPTModel()
	// Default to gpt-4o if empty
	if value == "" {
		value = "gpt-4o"
	}
	log.Printf("GetChatGPTModel returning: %s", value)
	return value
}

func (s *Settings) SetChatGPTModel(model string) error {
	if s.ContentManager == nil || s.ContentManager.Settings() == nil {
		log.Printf("ERROR: ContentManager or Settings is nil in SetChatGPTModel")
		return nil
	}

	// Default to gpt-4o if empty or invalid
	if model == "" {
		model = "gpt-4o"
	}

	log.Printf("SetChatGPTModel called with value: %s", model)
	return s.ContentManager.Settings().SetChatGPTModel(context.Background(), model)
}
