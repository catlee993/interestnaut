package llama

/*
#cgo CFLAGS: -I${SRCDIR}/../../../internal/llama
#cgo LDFLAGS: -L${SRCDIR}/../../../build/macos -linterestnaut -lstdc++ -lm -framework Accelerate -framework Foundation -framework Metal

#include "llama_wrapper.h"
#include <stdlib.h>
*/
import "C"
import (
	"fmt"
	"runtime"
	"sync"
	"unsafe"
)

// Model represents a llama model
type Model struct {
	handle unsafe.Pointer
	mu     sync.Mutex
}

// Context represents a llama context
type Context struct {
	handle unsafe.Pointer
	mu     sync.Mutex
}

var (
	initOnce sync.Once
	initErr  error
)

// Initialize initializes the llama library
func Initialize() error {
	initOnce.Do(func() {
		if C.GoInitLlamaLib() == 0 {
			initErr = fmt.Errorf("failed to initialize llama library")
		}
	})
	return initErr
}

// LoadModel loads a model from a file
func LoadModel(modelPath string) (*Model, error) {
	if err := Initialize(); err != nil {
		return nil, err
	}

	cModelPath := C.CString(modelPath)
	defer C.free(unsafe.Pointer(cModelPath))

	handle := C.GoLoadModel(cModelPath)
	if handle == nil {
		return nil, fmt.Errorf("failed to load model: %s", modelPath)
	}

	model := &Model{
		handle: handle,
	}

	runtime.SetFinalizer(model, finalizeModel)
	return model, nil
}

// CreateContext creates a context from a model
func (m *Model) CreateContext() (*Context, error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.handle == nil {
		return nil, fmt.Errorf("model has been freed")
	}

	handle := C.GoNewContextFromModel(m.handle, 2048) // Default context size
	if handle == nil {
		return nil, fmt.Errorf("failed to create context")
	}

	ctx := &Context{
		handle: handle,
	}

	runtime.SetFinalizer(ctx, finalizeContext)
	return ctx, nil
}

// Complete generates a text completion
func (c *Context) Complete(prompt string, maxTokens int) (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.handle == nil {
		return "", fmt.Errorf("context has been freed")
	}

	cPrompt := C.CString(prompt)
	defer C.free(unsafe.Pointer(cPrompt))

	// For demonstration, we'll use GoLlamaGenerate which takes a model path, prompt, and max tokens
	// In a real implementation, we'd use the context directly
	cResult := C.GoLlamaGenerate(nil, cPrompt, C.int(maxTokens))
	if cResult == nil {
		return "", fmt.Errorf("failed to generate completion")
	}

	result := C.GoString(cResult)
	C.go_llama_free_string(cResult) // Use the wrapper's free string function

	return result, nil
}

// Free frees the model's resources
func (m *Model) Free() {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.handle != nil {
		C.GoFreeModel(m.handle)
		m.handle = nil
		runtime.SetFinalizer(m, nil)
	}
}

// Free frees the context's resources
func (c *Context) Free() {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.handle != nil {
		C.GoFreeContext(c.handle)
		c.handle = nil
		runtime.SetFinalizer(c, nil)
	}
}

// finalizeContext is a finalizer for Context
func finalizeContext(c *Context) {
	c.Free()
}

// finalizeModel is a finalizer for Model
func finalizeModel(m *Model) {
	m.Free()
}

// Functions to bridge to the Flutter FFI expected functions

// DownloadModel downloads a model
func DownloadModel(modelPath string) (string, error) {
	cModelPath := C.CString(modelPath)
	defer C.free(unsafe.Pointer(cModelPath))

	cResult := C.GGUF_DownloadModel(cModelPath)
	if cResult == nil {
		return "", fmt.Errorf("failed to download model")
	}

	result := C.GoString(cResult)
	C.FreeString(cResult)

	return result, nil
}

// HasModel checks if a model exists
func HasModel() (string, error) {
	cResult := C.GGUF_HasModel()
	if cResult == nil {
		return "", fmt.Errorf("failed to check if model exists")
	}

	result := C.GoString(cResult)
	C.FreeString(cResult)

	return result, nil
}

// HandleNewSuggestion handles a new suggestion
func HandleNewSuggestion() (string, error) {
	cResult := C.GGUF_HandleNewSuggestion()
	if cResult == nil {
		return "", fmt.Errorf("failed to handle new suggestion")
	}

	result := C.GoString(cResult)
	C.FreeString(cResult)

	return result, nil
}
