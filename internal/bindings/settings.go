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

func (s *Settings) GetLLMProvider() string {
	if s.ContentManager == nil || s.ContentManager.Settings() == nil {
		log.Printf("WARNING: ContentManager or Settings is nil in GetLLMProvider")
		return "openai"
	}
	value := s.ContentManager.Settings().GetLLMProvider()
	log.Printf("GetLLMProvider returning: %s", value)
	return value
}

func (s *Settings) SetLLMProvider(provider string) error {
	if s.ContentManager == nil || s.ContentManager.Settings() == nil {
		log.Printf("ERROR: ContentManager or Settings is nil in SetLLMProvider")
		return nil
	}

	// Default to openai if empty or invalid
	if provider == "" || (provider != "openai" && provider != "gemini") {
		provider = "openai"
	}

	log.Printf("SetLLMProvider called with value: %s", provider)
	return s.ContentManager.Settings().SetLLMProvider(context.Background(), provider)
}

func (s *Settings) GetGeminiModel() string {
	if s.ContentManager == nil || s.ContentManager.Settings() == nil {
		log.Printf("WARNING: ContentManager or Settings is nil in GetGeminiModel")
		return "gemini-1.5-pro"
	}
	value := s.ContentManager.Settings().GetGeminiModel()
	// Default to gemini-1.5-pro if empty
	if value == "" {
		value = "gemini-1.5-pro"
	}
	log.Printf("GetGeminiModel returning: %s", value)
	return value
}

func (s *Settings) SetGeminiModel(model string) error {
	if s.ContentManager == nil || s.ContentManager.Settings() == nil {
		log.Printf("ERROR: ContentManager or Settings is nil in SetGeminiModel")
		return nil
	}

	// Validate model is one of the supported ones
	validModels := []string{
		"gemini-1.5-pro",
		"gemini-2.0-flash",
		"gemini-2.0-flash-lite",
	}

	isValid := false
	for _, validModel := range validModels {
		if model == validModel {
			isValid = true
			break
		}
	}

	if !isValid {
		model = "gemini-1.5-pro" // Default if invalid
	}

	log.Printf("SetGeminiModel called with value: %s", model)
	return s.ContentManager.Settings().SetGeminiModel(context.Background(), model)
}
