#!/bin/bash
# build_llama.sh - Script to build llama.cpp directly
set -e  # Exit on any errors

# Output colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
  echo -e "${GREEN}[*]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
  echo -e "${RED}[X]${NC} $1"
}

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"  # Parent directory of scripts

# Set up the dependencies directory
DEPS_DIR="$ROOT_DIR/dependencies"
LLAMA_CPP_DIR="$DEPS_DIR/llama.cpp"
WRAPPER_DIR="$DEPS_DIR/wrapper"

# Create directories if they don't exist
mkdir -p "$DEPS_DIR"
mkdir -p "$WRAPPER_DIR"

# Use a specific tag/commit for stability
# You can update this to a newer version as needed
LLAMA_CPP_VERSION="b2246e47aab68df0e09cdf649db2d9a883ab42c9"  # March 2024 stable release

# Remove old llama.cpp directory if it exists
if [ -d "$LLAMA_CPP_DIR" ]; then
    print_status "Removing existing llama.cpp directory..."
    rm -rf "$LLAMA_CPP_DIR"
fi

print_status "Cloning llama.cpp repository..."
cd "$DEPS_DIR"
git clone https://github.com/ggerganov/llama.cpp.git
cd "$LLAMA_CPP_DIR"

# Checkout a stable version
print_status "Checking out stable version: $LLAMA_CPP_VERSION..."
git checkout $LLAMA_CPP_VERSION

# Build llama.cpp with CMake
print_status "Building llama.cpp library..."
mkdir -p build
cd build
cmake .. -DBUILD_SHARED_LIBS=ON -DLLAMA_METAL=ON
cmake --build . --config Release

# Verify the library was built successfully
if [ -f "$LLAMA_CPP_DIR/build/libllama.dylib" ]; then
    print_status "Successfully built llama.cpp library!"
else
    print_error "Failed to build llama.cpp library."
    exit 1
fi

# Create the wrapper directory
print_status "Creating wrapper directory..."
mkdir -p "$WRAPPER_DIR/include"
mkdir -p "$WRAPPER_DIR/lib"

# Copy the library and headers
print_status "Copying library and headers..."
cp "$LLAMA_CPP_DIR/build/libllama.dylib" "$WRAPPER_DIR/lib/"
cp -r "$LLAMA_CPP_DIR/llama.h" "$WRAPPER_DIR/include/"
cp -r "$LLAMA_CPP_DIR/ggml.h" "$WRAPPER_DIR/include/"
cp -r "$LLAMA_CPP_DIR/ggml-backend.h" "$WRAPPER_DIR/include/"

# Create a simple C wrapper for the functionality you need
print_status "Creating C wrapper for llama.cpp..."
cat > "$WRAPPER_DIR/interestnaut_llama.h" << 'EOF'
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
EOF

# Create the C wrapper implementation
cat > "$WRAPPER_DIR/interestnaut_llama.cpp" << 'EOF'
#include "interestnaut_llama.h"
#include "include/llama.h"
#include <string>
#include <vector>
#include <cstring>
#include <cstdlib>

struct interestnaut_llama_model {
    llama_model* model;
};

struct interestnaut_llama_context {
    llama_context* ctx;
    llama_model* model; // Reference to the model
};

bool interestnaut_llama_init(void) {
    llama_backend_init(false);
    return true;
}

interestnaut_llama_model* interestnaut_llama_load_model(const char* model_path) {
    llama_model_params params = llama_model_default_params();
    
    llama_model* model = llama_load_model_from_file(model_path, params);
    if (!model) {
        return nullptr;
    }
    
    interestnaut_llama_model* wrapper = new interestnaut_llama_model();
    wrapper->model = model;
    
    return wrapper;
}

interestnaut_llama_context* interestnaut_llama_create_context(interestnaut_llama_model* model) {
    if (!model) {
        return nullptr;
    }
    
    llama_context_params params = llama_context_default_params();
    
    llama_context* ctx = llama_new_context_with_model(model->model, params);
    if (!ctx) {
        return nullptr;
    }
    
    interestnaut_llama_context* wrapper = new interestnaut_llama_context();
    wrapper->ctx = ctx;
    wrapper->model = model->model; // Keep a reference to the model
    
    return wrapper;
}

char* interestnaut_llama_complete(interestnaut_llama_context* ctx, const char* prompt, int max_tokens) {
    if (!ctx || !ctx->ctx || !prompt) {
        return nullptr;
    }
    
    // Convert the prompt to tokens
    std::vector<llama_token> tokens(llama_n_ctx(ctx->ctx));
    int num_tokens = llama_tokenize(ctx->model, prompt, strlen(prompt), tokens.data(), tokens.size(), true);
    if (num_tokens < 0) {
        return nullptr;
    }
    
    tokens.resize(num_tokens);
    
    // Evaluate the tokens
    if (llama_eval(ctx->ctx, tokens.data(), tokens.size(), 0, 1) != 0) {
        return nullptr;
    }
    
    // Generate completion
    std::string result;
    
    for (int i = 0; i < max_tokens; ++i) {
        // Get logits for the last token
        const float* logits = llama_get_logits(ctx->ctx);
        
        // Sample token
        llama_token new_token = llama_sample_token(ctx->ctx);
        
        // Check if we've hit the end of the text
        if (new_token == llama_token_eos(ctx->model)) {
            break;
        }
        
        // Convert token to text
        char buffer[8];
        int len = llama_token_to_piece(ctx->model, new_token, buffer, sizeof(buffer));
        if (len < 0) {
            len = 0;
        }
        buffer[len] = '\0';
        
        // Append to result
        result += buffer;
        
        // Evaluate the new token
        if (llama_eval(ctx->ctx, &new_token, 1, tokens.size() + i, 1) != 0) {
            break;
        }
    }
    
    // Allocate memory for the result
    char* completion = (char*)malloc(result.size() + 1);
    if (!completion) {
        return nullptr;
    }
    
    // Copy the result
    strcpy(completion, result.c_str());
    
    return completion;
}

void interestnaut_llama_free_completion(char* completion) {
    if (completion) {
        free(completion);
    }
}

void interestnaut_llama_free_context(interestnaut_llama_context* ctx) {
    if (ctx) {
        if (ctx->ctx) {
            llama_free(ctx->ctx);
        }
        delete ctx;
    }
}

void interestnaut_llama_free_model(interestnaut_llama_model* model) {
    if (model) {
        if (model->model) {
            llama_free_model(model->model);
        }
        delete model;
    }
}
EOF

# Compile the wrapper
print_status "Compiling the wrapper..."
cd "$WRAPPER_DIR"
c++ -std=c++11 -I. -I"$LLAMA_CPP_DIR" -fPIC -shared -o libinterestnaut_llama.dylib \
    interestnaut_llama.cpp -L"$LLAMA_CPP_DIR/build" -lllama

# Verify the wrapper was built successfully
if [ -f "$WRAPPER_DIR/libinterestnaut_llama.dylib" ]; then
    print_status "Successfully built the wrapper library!"
    print_status "Wrapper location: $WRAPPER_DIR/libinterestnaut_llama.dylib"
    exit 0
else
    print_error "Failed to build the wrapper library."
    exit 1
fi
