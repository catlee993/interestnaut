#ifndef LLAMA_WRAPPER_H
#define LLAMA_WRAPPER_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Initialize llama library with custom signal handling
bool llama_init_with_signal_handling(void);

// Load a model from file
void* go_llama_load_model(const char* path);

// Create a context from a model handle
void* go_llama_create_context(void* model);

// Generate text completion
char* go_llama_complete_text(void* ctx, const char* prompt, int max_tokens);

// Free a string allocated by the library
void go_llama_free_string(char* str);

// Free a context's resources
void go_llama_free_context(void* ctx);

// Free a model's resources
void go_llama_free_model(void* model);

// Initialize the llama library
int GoInitLlamaLib(void);

// Load a model from the given path
void* GoLoadModel(const char* path);

// Free a model
void GoFreeModel(void* model);

// Create a new context from a model
void* GoNewContextFromModel(void* model, int n_ctx);

// Free a context
void GoFreeContext(void* ctx);

// Generate text using the model
char* GoLlamaGenerate(const char* model_path, const char* prompt, int max_tokens);

// Functions expected by Flutter FFI
char* GGUF_DownloadModel(const char* model_path);
char* GGUF_HasModel(void);
char* GGUF_HandleNewSuggestion(void);
void FreeString(char* str);

#ifdef __cplusplus
}
#endif

#endif // LLAMA_WRAPPER_H
