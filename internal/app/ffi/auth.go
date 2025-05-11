package ffi

/*
#include <stdlib.h>
*/
import "C"

import (
	"unsafe"
)

//export Auth_GetOpenAIToken
func Auth_GetOpenAIToken() *C.char {
	if authBindings == nil {
		return C.CString("{\"error\": \"Auth bindings not initialized\"}")
	}

	token, err := authBindings.GetOpenAIToken()
	if err != nil {
		return processError(err)
	}

	return C.CString(token)
}

//export Auth_SaveOpenAIToken
func Auth_SaveOpenAIToken(tokenC *C.char) *C.char {
	if authBindings == nil {
		return C.CString("{\"error\": \"Auth bindings not initialized\"}")
	}

	token := C.GoString(tokenC)
	defer C.free(unsafe.Pointer(tokenC))

	err := authBindings.SaveOpenAIToken(token)
	return processError(err)
}

//export Auth_ClearOpenAIToken
func Auth_ClearOpenAIToken() *C.char {
	if authBindings == nil {
		return C.CString("{\"error\": \"Auth bindings not initialized\"}")
	}

	err := authBindings.ClearOpenAIToken()
	return processError(err)
}

//export Auth_GetTMBDAccessToken
func Auth_GetTMBDAccessToken() *C.char {
	if authBindings == nil {
		return C.CString("{\"error\": \"Auth bindings not initialized\"}")
	}

	token, err := authBindings.GetTMBDAccessToken()
	if err != nil {
		return processError(err)
	}

	return C.CString(token)
}

//export Auth_SaveTMBDAccessToken
func Auth_SaveTMBDAccessToken(tokenC *C.char) *C.char {
	if authBindings == nil {
		return C.CString("{\"error\": \"Auth bindings not initialized\"}")
	}

	token := C.GoString(tokenC)
	defer C.free(unsafe.Pointer(tokenC))

	err := authBindings.SaveTMBDAccessToken(token)
	return processError(err)
}

//export Auth_ClearTMBDAccessToken
func Auth_ClearTMBDAccessToken() *C.char {
	if authBindings == nil {
		return C.CString("{\"error\": \"Auth bindings not initialized\"}")
	}

	err := authBindings.ClearTMBDAccessToken()
	return processError(err)
}

//export Auth_GetGeminiToken
func Auth_GetGeminiToken() *C.char {
	if authBindings == nil {
		return C.CString("{\"error\": \"Auth bindings not initialized\"}")
	}

	token, err := authBindings.GetGeminiToken()
	if err != nil {
		return processError(err)
	}

	return C.CString(token)
}

//export Auth_SaveGeminiToken
func Auth_SaveGeminiToken(tokenC *C.char) *C.char {
	if authBindings == nil {
		return C.CString("{\"error\": \"Auth bindings not initialized\"}")
	}

	token := C.GoString(tokenC)
	defer C.free(unsafe.Pointer(tokenC))

	err := authBindings.SaveGeminiToken(token)
	return processError(err)
}

//export Auth_ClearGeminiToken
func Auth_ClearGeminiToken() *C.char {
	if authBindings == nil {
		return C.CString("{\"error\": \"Auth bindings not initialized\"}")
	}

	err := authBindings.ClearGeminiToken()
	return processError(err)
}

//export Auth_GetRAWGAPIKey
func Auth_GetRAWGAPIKey() *C.char {
	if authBindings == nil {
		return C.CString("{\"error\": \"Auth bindings not initialized\"}")
	}

	key, err := authBindings.GetRAWGAPIKey()
	if err != nil {
		return processError(err)
	}

	return C.CString(key)
}

//export Auth_SaveRAWGAPIKey
func Auth_SaveRAWGAPIKey(keyC *C.char) *C.char {
	if authBindings == nil {
		return C.CString("{\"error\": \"Auth bindings not initialized\"}")
	}

	key := C.GoString(keyC)
	defer C.free(unsafe.Pointer(keyC))

	err := authBindings.SaveRAWGAPIKey(key)
	return processError(err)
}

//export Auth_ClearRAWGAPIKey
func Auth_ClearRAWGAPIKey() *C.char {
	if authBindings == nil {
		return C.CString("{\"error\": \"Auth bindings not initialized\"}")
	}

	err := authBindings.ClearRAWGAPIKey()
	return processError(err)
}
