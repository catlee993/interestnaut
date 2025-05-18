#include "llama_wrapper.h"
#include <llama.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Initialize the llama library
int GoInitLlamaLib(void) {
    llama_backend_init(); // Initialize with default settings
    return 1;
}

// Load a model from the given path
void* GoLoadModel(const char* path) {
    struct llama_model_params model_params = llama_model_default_params();
    struct llama_model* model = llama_model_load_from_file(path, model_params);
    return model;
}

// Free a model
void GoFreeModel(void* model) {
    llama_model_free((struct llama_model*)model);
}

// Create a new context from a model
void* GoNewContextFromModel(void* model, int n_ctx) {
    struct llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = n_ctx;
    struct llama_context* ctx = llama_init_from_model((struct llama_model*)model, ctx_params);
    return ctx;
}

// Free a context
void GoFreeContext(void* ctx) {
    llama_free((struct llama_context*)ctx);
}

// Generate text using the model
char* GoLlamaGenerate(const char* model_path, const char* prompt, int max_tokens) {
    // Initialize llama.cpp
    llama_backend_init();
    
    // Load the model
    struct llama_model_params model_params = llama_model_default_params();
    struct llama_model* model = llama_model_load_from_file(model_path, model_params);
    if (!model) {
        fprintf(stderr, "Failed to load model '%s'\n", model_path);
        llama_backend_free();
        return NULL;
    }
    
    // Get the vocabulary from the model
    const struct llama_vocab* vocab = llama_model_get_vocab(model);
    if (!vocab) {
        fprintf(stderr, "Failed to get vocabulary from model\n");
        llama_model_free(model);
        llama_backend_free();
        return NULL;
    }
    
    // Create a context for the model
    struct llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 2048; // Context size
    struct llama_context* ctx = llama_init_from_model(model, ctx_params);
    if (!ctx) {
        fprintf(stderr, "Failed to create context\n");
        llama_model_free(model);
        llama_backend_free();
        return NULL;
    }
    
    // Tokenize the prompt
    llama_token tokens[2048];
    int n_tokens = llama_tokenize(vocab, prompt, strlen(prompt), tokens, 2048, true, false);
    if (n_tokens < 0) {
        fprintf(stderr, "Failed to tokenize prompt\n");
        llama_free(ctx);
        llama_model_free(model);
        llama_backend_free();
        return NULL;
    }
    
    // Create a batch to evaluate the prompt
    struct llama_batch batch = llama_batch_init(n_tokens, 0, 1);
    
    // Add tokens to the batch
    for (int i = 0; i < n_tokens; i++) {
        batch.token[i] = tokens[i];
        batch.pos[i] = i;
        batch.seq_id[i][0] = 0;
        batch.logits[i] = false;
    }
    batch.n_tokens = n_tokens;
    
    // Process the batch (evaluate the prompt)
    if (llama_decode(ctx, batch) != 0) {
        fprintf(stderr, "Failed to decode\n");
        llama_batch_free(batch);
        llama_free(ctx);
        llama_model_free(model);
        llama_backend_free();
        return NULL;
    }
    
    // Allocate space for the generated text
    // (prompt + generated tokens with some extra space)
    size_t result_size = strlen(prompt) + max_tokens * 5;
    char* result = (char*)malloc(result_size);
    if (!result) {
        fprintf(stderr, "Failed to allocate memory for result\n");
        llama_batch_free(batch);
        llama_free(ctx);
        llama_model_free(model);
        llama_backend_free();
        return NULL;
    }
    
    // Copy the original prompt to the result
    strcpy(result, prompt);
    
    // Initialize a greedy sampler
    struct llama_sampler* sampler = llama_sampler_init_greedy();
    if (!sampler) {
        fprintf(stderr, "Failed to initialize greedy sampler\n");
        free(result);
        llama_batch_free(batch);
        llama_free(ctx);
        llama_model_free(model);
        llama_backend_free();
        return NULL;
    }
    
    char buffer[1024];
    int token_count = n_tokens;
    
    // Generate tokens
    for (int i = 0; i < max_tokens; i++) {        
        // Sample a token using the greedy sampler
        llama_token new_token_id = llama_sampler_sample(sampler, ctx, 0);
        
        // Break if end of text token is generated
        if (new_token_id == llama_vocab_eos(vocab)) {
            break;
        }
        
        // Store the new token
        tokens[token_count++] = new_token_id;
        
        // Get the string representation of the token
        int len = llama_token_to_piece(vocab, new_token_id, buffer, sizeof(buffer) - 1, 0, false);
        if (len < 0) {
            len = 0;
        }
        buffer[len] = '\0';
        
        // Append the token text to the result
        if (strlen(result) + len < result_size - 1) {
            strcat(result, buffer);
        } else {
            break; // Avoid buffer overflow
        }
        
        // Prepare a new batch with just the sampled token
        batch.n_tokens = 1;
        batch.token[0] = new_token_id;
        batch.pos[0] = token_count - 1;
        batch.seq_id[0][0] = 0;
        batch.logits[0] = true;
        
        // Process the batch
        if (llama_decode(ctx, batch) != 0) {
            fprintf(stderr, "Failed to decode\n");
            break;
        }
    }
    
    // Clean up
    llama_sampler_free(sampler);
    llama_batch_free(batch);
    llama_free(ctx);
    llama_model_free(model);
    llama_backend_free();
    
    return result;
}

// Legacy functions
// The following functions are kept for backward compatibility with go_ prefix

bool llama_init_with_signal_handling(void) {
    llama_backend_init();
    return true;
}

void* go_llama_load_model(const char* path) {
    return GoLoadModel(path);
}

void* go_llama_create_context(void* model) {
    return GoNewContextFromModel(model, 2048); // Default context size
}

char* go_llama_complete_text(void* ctx, const char* prompt, int max_tokens) {
    // Not implemented directly - would duplicate GoLlamaGenerate
    // This is just a stub
    fprintf(stderr, "go_llama_complete_text is not fully implemented\n");
    return NULL;
}

void go_llama_free_string(char* str) {
    free(str);
}

void go_llama_free_context(void* ctx) {
    GoFreeContext(ctx);
}

void go_llama_free_model(void* model) {
    GoFreeModel(model);
}

// Flutter FFI bridging functions
// These are called by Flutter directly through FFI

// Implementation of model download function for Flutter
char* GGUF_DownloadModel(const char* model_path) {
    // Allocate a buffer for result - should be freed by caller
    char* result = (char*)malloc(1024);
    if (result == NULL) {
        return NULL;
    }
    
    // For now, we just return a simple response
    // In a real implementation, this would fetch the model
    sprintf(result, "{\"status\":\"success\", \"path\":\"%s\"}", model_path);
    
    return result;
}

// Implementation of model check function for Flutter
char* GGUF_HasModel(void) {
    // Allocate a buffer for result - should be freed by caller
    char* result = (char*)malloc(1024);
    if (result == NULL) {
        return NULL;
    }
    
    // This would check if the model exists on disk
    // For now we'll just return a fixed response
    sprintf(result, "{\"exists\":true}");
    
    return result;
}

// Implementation of suggestion handler for Flutter
char* GGUF_HandleNewSuggestion(void) {
    // Allocate a buffer for result - should be freed by caller
    char* result = (char*)malloc(1024);
    if (result == NULL) {
        return NULL;
    }
    
    // This would handle a new suggestion
    // For now we'll just return a fixed response
    sprintf(result, "{\"suggestion\":\"Hello, how can I help you today?\"}");
    
    return result;
}

// Free a string allocated by any of the GGUF_* functions
void FreeString(char* str) {
    free(str);
}
