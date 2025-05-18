#ifndef INTERESTNAUT_LLAMA_H
#define INTERESTNAUT_LLAMA_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>

// Simple wrapper for llama.cpp functionality
typedef struct interestnaut_llama_model interestnaut_llama_model;
typedef struct interestnaut_llama_context interestnaut_llama_context;

// Initialize the library
bool interestnaut_llama_init(void);

// Load a model from a file
interestnaut_llama_model* interestnaut_llama_load_model(const char* model_path);

// Create a context from a model
interestnaut_llama_context* interestnaut_llama_create_context(interestnaut_llama_model* model);

// Get a completion from the model
char* interestnaut_llama_complete(interestnaut_llama_context* ctx, const char* prompt, int max_tokens);

// Free a completion string
void interestnaut_llama_free_completion(char* completion);

// Free a context
void interestnaut_llama_free_context(interestnaut_llama_context* ctx);

// Free a model
void interestnaut_llama_free_model(interestnaut_llama_model* model);

#ifdef __cplusplus
}
#endif

#endif // INTERESTNAUT_LLAMA_H
