package llama

/*
#include <stdlib.h>
#include "llama_wrapper.h"
*/
import "C"
import (
	"errors"
	"fmt"
	"runtime"
	"unsafe"
)

// Initialize initializes the llama library
func Initialize() error {
	result := C.GoInitLlamaLib()
	if result == 0 {
		return errors.New("failed to initialize llama library")
	}
	return nil
}

// Model represents a loaded llama model
type Model struct {
	handle unsafe.Pointer
}

// LoadModel loads a model from the given path
func LoadModel(modelPath string) (*Model, error) {
	cModelPath := C.CString(modelPath)
	defer C.free(unsafe.Pointer(cModelPath))

	handle := C.GoLoadModel(cModelPath)
	if handle == nil {
		return nil, fmt.Errorf("failed to load model from %s", modelPath)
	}

	model := &Model{handle: handle}
	
	// Set up finalizer to free the model when it's garbage collected
	runtime.SetFinalizer(model, freeModel)
	
	return model, nil
}

// Free explicitly frees the model resources
func (m *Model) Free() {
	if m.handle != nil {
		C.GoFreeModel(m.handle)
		m.handle = nil
	}
}

// Internal function to free model when garbage collected
func freeModel(m *Model) {
	m.Free()
}

// Context represents a llama context for inference
type Context struct {
	handle unsafe.Pointer
	model  *Model // Keep a reference to the model to prevent GC
}

// NewContext creates a new context from a model
func (m *Model) NewContext(contextSize int) (*Context, error) {
	handle := C.GoNewContextFromModel(m.handle, C.int(contextSize))
	if handle == nil {
		return nil, errors.New("failed to create context from model")
	}

	ctx := &Context{
		handle: handle,
		model:  m,
	}
	
	// Set up finalizer to free the context when it's garbage collected
	runtime.SetFinalizer(ctx, freeContext)
	
	return ctx, nil
}

// Free explicitly frees the context resources
func (c *Context) Free() {
	if c.handle != nil {
		C.GoFreeContext(c.handle)
		c.handle = nil
	}
}

// Internal function to free context when garbage collected
func freeContext(c *Context) {
	c.Free()
}

// Generate generates text using the model and prompt
func Generate(modelPath, prompt string, maxTokens int) (string, error) {
	cModelPath := C.CString(modelPath)
	cPrompt := C.CString(prompt)
	defer C.free(unsafe.Pointer(cModelPath))
	defer C.free(unsafe.Pointer(cPrompt))

	cResult := C.GoLlamaGenerate(cModelPath, cPrompt, C.int(maxTokens))
	if cResult == nil {
		return "", errors.New("failed to generate text")
	}

	// Convert the C string to a Go string and free the C memory
	result := C.GoString(cResult)
	C.free(unsafe.Pointer(cResult))

	return result, nil
}

func main() {} // Required for buildmode=c-shared
