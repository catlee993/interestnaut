package ffi

/*
#include <stdlib.h>
*/
import "C"

import (
	"unsafe"
)

//export Settings_GetContinuousPlayback
func Settings_GetContinuousPlayback() *C.char {
	if settingsBindings == nil {
		return C.CString("{\"error\": \"Settings bindings not initialized\"}")
	}

	continuous := settingsBindings.GetContinuousPlayback()
	return returnJSON(map[string]bool{"continuous": continuous})
}

//export Settings_SetContinuousPlayback
func Settings_SetContinuousPlayback(continuousC C.int) *C.char {
	if settingsBindings == nil {
		return C.CString("{\"error\": \"Settings bindings not initialized\"}")
	}

	continuous := continuousC != 0
	err := settingsBindings.SetContinuousPlayback(continuous)
	return processError(err)
}

//export Settings_GetChatGPTModel
func Settings_GetChatGPTModel() *C.char {
	if settingsBindings == nil {
		return C.CString("{\"error\": \"Settings bindings not initialized\"}")
	}

	model := settingsBindings.GetChatGPTModel()
	return returnJSON(map[string]string{"model": model})
}

//export Settings_SetChatGPTModel
func Settings_SetChatGPTModel(modelC *C.char) *C.char {
	if settingsBindings == nil {
		return C.CString("{\"error\": \"Settings bindings not initialized\"}")
	}

	model := C.GoString(modelC)
	defer C.free(unsafe.Pointer(modelC))

	err := settingsBindings.SetChatGPTModel(model)
	return processError(err)
}

//export Settings_GetLLMProvider
func Settings_GetLLMProvider() *C.char {
	if settingsBindings == nil {
		return C.CString("{\"error\": \"Settings bindings not initialized\"}")
	}

	provider := settingsBindings.GetLLMProvider()
	return returnJSON(map[string]string{"provider": provider})
}

//export Settings_SetLLMProvider
func Settings_SetLLMProvider(providerC *C.char) *C.char {
	if settingsBindings == nil {
		return C.CString("{\"error\": \"Settings bindings not initialized\"}")
	}

	provider := C.GoString(providerC)
	defer C.free(unsafe.Pointer(providerC))

	err := settingsBindings.SetLLMProvider(provider)
	return processError(err)
}

//export Settings_GetGeminiModel
func Settings_GetGeminiModel() *C.char {
	if settingsBindings == nil {
		return C.CString("{\"error\": \"Settings bindings not initialized\"}")
	}

	model := settingsBindings.GetGeminiModel()
	return returnJSON(map[string]string{"model": model})
}

//export Settings_SetGeminiModel
func Settings_SetGeminiModel(modelC *C.char) *C.char {
	if settingsBindings == nil {
		return C.CString("{\"error\": \"Settings bindings not initialized\"}")
	}

	model := C.GoString(modelC)
	defer C.free(unsafe.Pointer(modelC))

	err := settingsBindings.SetGeminiModel(model)
	return processError(err)
}
