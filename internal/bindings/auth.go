package bindings

import "interestnaut/internal/creds"

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
