package llama

/*
#cgo CFLAGS: -I${SRCDIR}/../../../dependencies/wrapper
#cgo LDFLAGS: -L${SRCDIR}/../../../dependencies/wrapper -linterestnaut_llama -Wl,-rpath,${SRCDIR}/../../../dependencies/wrapper

#include "interestnaut_llama.h"
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
	handle *C.interestnaut_llama_model
	mu     sync.Mutex
}

// Context represents a llama context
type Context struct {
	handle *C.interestnaut_llama_context
	mu     sync.Mutex
}

var (
	initOnce sync.Once
	initErr  error
)

// Initialize initializes the llama library
func Initialize() error {
	initOnce.Do(func() {
		if !C.interestnaut_llama_init() {
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

	handle := C.interestnaut_llama_load_model(cModelPath)
	if handle == nil {
		return nil, fmt.Errorf("failed to load model from %s", modelPath)
	}

	model := &Model{handle: handle}
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

	handle := C.interestnaut_llama_create_context(m.handle)
	if handle == nil {
		return nil, fmt.Errorf("failed to create context")
	}

	ctx := &Context{handle: handle}
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

	cMaxTokens := C.int(maxTokens)

	cCompletion := C.interestnaut_llama_complete(c.handle, cPrompt, cMaxTokens)
	if cCompletion == nil {
		return "", fmt.Errorf("failed to generate completion")
	}
	
	// Convert to Go string and free C memory
	completion := C.GoString(cCompletion)
	C.interestnaut_llama_free_completion(cCompletion)

	return completion, nil
}

// Free frees the model's resources
func (m *Model) Free() {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.handle != nil {
		runtime.SetFinalizer(m, nil)
		C.interestnaut_llama_free_model(m.handle)
		m.handle = nil
	}
}

// Free frees the context's resources
func (c *Context) Free() {
	c.mu.Lock()
	defer c.mu.Unlock()

	if c.handle != nil {
		runtime.SetFinalizer(c, nil)
		C.interestnaut_llama_free_context(c.handle)
		c.handle = nil
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
