package bindings

import (
	"interestnaut/internal/creds"
)

type Auth struct{}

func (a *Auth) GetOpenAIToken() (string, error) {
	return creds.GetOpenAIKey()
}

func (a *Auth) SaveOpenAIToken(token string) error {
	return creds.SaveOpenAIKey(token)
}

func (a *Auth) ClearOpenAIToken() error {
	return creds.ClearOpenAIKey()
}

func (a *Auth) GetTMBDAccessToken() (string, error) {
	return creds.GetTMDBAccessToken()
}

func (a *Auth) SaveTMBDAccessToken(token string) error {
	return creds.SaveTMDBAccessToken(token)
}

func (a *Auth) ClearTMBDAccessToken() error {
	return creds.ClearTMDBAccessToken()
}

func (a *Auth) GetGeminiToken() (string, error) {
	return creds.GetGeminiKey()
}

func (a *Auth) SaveGeminiToken(token string) error {
	return creds.SaveGeminiKey(token)
}

func (a *Auth) ClearGeminiToken() error {
	return creds.ClearGeminiKey()
}
