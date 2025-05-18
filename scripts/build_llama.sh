#!/bin/bash
# build_llama.sh - Script to build llama.cpp directly
set -e  # Exit on any errors

# Platform selection
PLATFORM=${1:-"macos"}  # Default to macOS if not specified

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
mkdir -p "$WRAPPER_DIR/include"
mkdir -p "$WRAPPER_DIR/lib"

# Use a specific tag/commit for stability
# Updated to the latest stable version as of May 2025
LLAMA_CPP_VERSION="6a2bc8bfb7cd502e5ebc72e36c97a6f848c21c2c"  # May 2025 stable release

# Set platform-specific variables
case $PLATFORM in
  macos)
    LIBRARY_EXTENSION="dylib"
    CMAKE_FLAGS="-DLLAMA_METAL=ON"
    COMPILER_FLAGS="-std=c++11 -fPIC -shared"
    TARGET_NAME="libinterestnaut_llama.dylib"
    ;;
  ios)
    LIBRARY_EXTENSION="a"  # Static library for iOS
    CMAKE_FLAGS="-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES=arm64 -DLLAMA_METAL=ON -DBUILD_SHARED_LIBS=OFF"
    COMPILER_FLAGS="-std=c++11 -fPIC -isysroot $(xcrun --sdk iphoneos --show-sdk-path)"
    TARGET_NAME="libinterestnaut_llama.a"
    ;;
  android)
    LIBRARY_EXTENSION="so"
    CMAKE_FLAGS="-DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-21"
    COMPILER_FLAGS="-std=c++11 -fPIC -shared"
    TARGET_NAME="libinterestnaut_llama.so"
    ;;
  *)
    print_error "Unknown platform: $PLATFORM"
    print_status "Usage: $0 [macos|ios|android]"
    exit 1
    ;;
esac

# Check if wrapper library already exists
if [ -f "$WRAPPER_DIR/$TARGET_NAME" ]; then
    print_status "Wrapper library for $PLATFORM already exists, skipping build."
    print_status "Wrapper location: $WRAPPER_DIR/$TARGET_NAME"
    exit 0
fi

# Check if llama.cpp repo is already cloned
FORCE_REBUILD=${2:-false}
if [ "$FORCE_REBUILD" != "true" ] && [ -d "$LLAMA_CPP_DIR" ]; then
    print_status "llama.cpp directory already exists, checking for library..."
    
    # Try to find the library
    LLAMA_LIB=$(find "$LLAMA_CPP_DIR" -name "libllama*.$LIBRARY_EXTENSION" | head -1)
    
    if [ -n "$LLAMA_LIB" ]; then
        print_status "Found existing library at: $LLAMA_LIB"
    else
        print_warning "No library found, will rebuild llama.cpp"
        FORCE_REBUILD=true
    fi
else
    FORCE_REBUILD=true
fi

# Only rebuild if necessary or forced
if [ "$FORCE_REBUILD" = "true" ]; then
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
    print_status "Building llama.cpp library for $PLATFORM..."
    mkdir -p build
    cd build
    
    # Apply platform-specific CMake flags
    cmake .. -DBUILD_SHARED_LIBS=ON $CMAKE_FLAGS
    cmake --build . --config Release
    
    # Find the built library
    LLAMA_LIB=$(find "$LLAMA_CPP_DIR" -name "libllama*.$LIBRARY_EXTENSION" | head -1)
    
    if [ -z "$LLAMA_LIB" ]; then
        print_error "Failed to build or find llama.cpp library for $PLATFORM."
        exit 1
    fi
    
    print_status "Found library at: $LLAMA_LIB"
fi

# Find header files with find
print_status "Locating header files..."
LLAMA_H=$(find "$LLAMA_CPP_DIR" -name "llama.h" | head -1)
GGML_H=$(find "$LLAMA_CPP_DIR" -name "ggml.h" | head -1)
GGML_BACKEND_H=$(find "$LLAMA_CPP_DIR" -name "ggml-backend.h" | head -1)
GGML_CPU_H=$(find "$LLAMA_CPP_DIR" -name "ggml-cpu.h" | head -1)

# Copy all header files from llama.cpp include directory
LLAMA_INCLUDE_DIR=$(dirname "$LLAMA_H")
if [ -d "$LLAMA_INCLUDE_DIR" ]; then
    print_status "Found include directory at: $LLAMA_INCLUDE_DIR"
    cp -r "$LLAMA_INCLUDE_DIR"/* "$WRAPPER_DIR/include/" || true
fi

# Copy all GGML headers
GGML_INCLUDE_DIR=$(dirname "$GGML_H")
if [ -d "$GGML_INCLUDE_DIR" ]; then
    print_status "Found GGML include directory at: $GGML_INCLUDE_DIR"
    cp -r "$GGML_INCLUDE_DIR"/* "$WRAPPER_DIR/include/" || true
fi

# Handle missing critical headers
if [ ! -f "$WRAPPER_DIR/include/llama.h" ]; then
    print_error "Required header llama.h could not be copied"
    exit 1
fi

# Check for critical missing headers and display warnings
for header in "ggml.h" "ggml-backend.h" "ggml-cpu.h"; do
    if [ ! -f "$WRAPPER_DIR/include/$header" ]; then
        print_warning "Header $header not found in include directory"
    else
        print_status "Successfully copied $header"
    fi
done

# Copy the library
print_status "Copying library..."
cp "$LLAMA_LIB" "$WRAPPER_DIR/lib/$TARGET_NAME"

# Create the C wrapper for llama.cpp
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
#include <mutex>  // For thread safety

// Global mutex for thread safety
static std::mutex llama_mutex;

// Eager initialization flag to prevent race conditions
static bool llama_initialized = false;

struct interestnaut_llama_model {
    llama_model* model;
    const llama_vocab* vocab; // Store vocab pointer for token operations
};

struct interestnaut_llama_context {
    llama_context* ctx;
    llama_model* model; // Reference to the model
    const llama_vocab* vocab; // Reference to vocabulary
};

bool interestnaut_llama_init(void) {
    // Thread-safe initialization
    std::lock_guard<std::mutex> lock(llama_mutex);
    
    if (!llama_initialized) {
        llama_backend_init();
        llama_initialized = true;
    }
    return true;
}

interestnaut_llama_model* interestnaut_llama_load_model(const char* model_path) {
    std::lock_guard<std::mutex> lock(llama_mutex);
    
    if (!llama_initialized) {
        interestnaut_llama_init();
    }
    
    llama_model_params params = llama_model_default_params();
    
    // Use the updated function from the API
    llama_model* model = llama_load_model_from_file(model_path, params);
    if (!model) {
        return nullptr;
    }
    
    interestnaut_llama_model* wrapper = new interestnaut_llama_model();
    wrapper->model = model;
    wrapper->vocab = llama_model_get_vocab(model);
    
    return wrapper;
}

interestnaut_llama_context* interestnaut_llama_create_context(interestnaut_llama_model* model) {
    std::lock_guard<std::mutex> lock(llama_mutex);
    
    if (!model) {
        return nullptr;
    }
    
    llama_context_params params = llama_context_default_params();
    
    // Setting reasonable default parameters
    params.n_ctx = 2048; // Context size
    params.n_batch = 512; // Batch size
    
    // Create a new context with the model
    llama_context* ctx = llama_new_context_with_model(model->model, params);
    if (!ctx) {
        return nullptr;
    }
    
    interestnaut_llama_context* wrapper = new interestnaut_llama_context();
    wrapper->ctx = ctx;
    wrapper->model = model->model; // Keep a reference to the model
    wrapper->vocab = model->vocab; // Keep reference to vocabulary
    
    return wrapper;
}

char* interestnaut_llama_complete(interestnaut_llama_context* ctx, const char* prompt, int max_tokens) {
    std::lock_guard<std::mutex> lock(llama_mutex);
    
    if (!ctx || !ctx->ctx || !prompt) {
        return nullptr;
    }
    
    // Convert the prompt to tokens
    std::vector<llama_token> tokens;
    tokens.resize(strlen(prompt) + 1); // Approximate size
    
    int num_tokens = llama_tokenize(ctx->vocab, prompt, strlen(prompt), tokens.data(), tokens.size(), true, false);
    if (num_tokens < 0) {
        return nullptr;
    }
    
    tokens.resize(num_tokens);
    
    // Create a batch for the input
    llama_batch batch = llama_batch_init(tokens.size(), 0, 1);
    for (int i = 0; i < num_tokens; i++) {
        batch.token[i] = tokens[i];
        batch.pos[i] = i;
        batch.n_seq_id[i] = 1;
        batch.seq_id[i][0] = 0;
        batch.logits[i] = 0;
    }
    batch.n_tokens = num_tokens;
    
    // Process the prompt tokens through the model
    if (llama_decode(ctx->ctx, batch) != 0) {
        llama_batch_free(batch);
        return nullptr;
    }
    
    llama_batch_free(batch);
    
    // Generate completion tokens one by one
    std::string result;
    
    // Get vocabulary size
    const int n_vocab = llama_vocab_n_tokens(ctx->vocab);
    
    // Single token batch for generation
    for (int i = 0; i < max_tokens; ++i) {
        // Find the highest probability token using logits
        llama_token token_id = 0;
        {
            const float* logits = llama_get_logits(ctx->ctx);
            
            float max_logit = -INFINITY;
            for (int j = 0; j < n_vocab; ++j) {
                if (logits[j] > max_logit) {
                    max_logit = logits[j];
                    token_id = j;
                }
            }
        }
        
        // Break if we hit token 0 (typically represents end of sequence in many models)
        // or if it's the EOS token
        if (token_id == 0 || token_id == llama_vocab_eos(ctx->vocab)) {
            break;
        }
        
        // Create a small buffer for the token text
        char piece[64] = {0};
        
        // Convert token to string using the vocab
        // Using the llama_vocab_token_to_piece function that takes the right number of arguments
        int len = llama_token_to_piece(ctx->vocab, token_id, piece, sizeof(piece) - 1, 0, false);
        if (len > 0) {
            piece[len] = 0; // Ensure proper null termination
            result += piece;
        }
        
        // Create a batch for just this new token
        llama_batch next_batch = llama_batch_init(1, 0, 1);
        next_batch.token[0] = token_id;
        next_batch.pos[0] = num_tokens + i;
        next_batch.n_seq_id[0] = 1;
        next_batch.seq_id[0][0] = 0;
        next_batch.logits[0] = 1;  // Request logits for this token
        next_batch.n_tokens = 1;
        
        // Evaluate the new token
        if (llama_decode(ctx->ctx, next_batch) != 0) {
            llama_batch_free(next_batch);
            break;
        }
        
        llama_batch_free(next_batch);
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
    std::lock_guard<std::mutex> lock(llama_mutex);
    
    if (ctx) {
        if (ctx->ctx) {
            llama_free(ctx->ctx);
        }
        delete ctx;
    }
}

void interestnaut_llama_free_model(interestnaut_llama_model* model) {
    std::lock_guard<std::mutex> lock(llama_mutex);
    
    if (model) {
        if (model->model) {
            // Use llama_model_free instead of deprecated llama_free_model
            llama_model_free(model->model);
        }
        delete model;
    }
}
EOF

# Extract library directory for compilation
LLAMA_LIB_DIR=$(dirname "$LLAMA_LIB")

# Compile the wrapper
print_status "Compiling the wrapper for $PLATFORM..."
cd "$WRAPPER_DIR"

# Platform-specific compilation
case $PLATFORM in
  macos)
    c++ $COMPILER_FLAGS -I. -I"$LLAMA_CPP_DIR" -o $TARGET_NAME \
      interestnaut_llama.cpp -L"$LLAMA_LIB_DIR" -lllama
    ;;
  ios)
    c++ -c $COMPILER_FLAGS -I. -I"$LLAMA_CPP_DIR" interestnaut_llama.cpp
    ar rcs $TARGET_NAME interestnaut_llama.o
    ;;
  android)
    $ANDROID_NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android21-clang++ \
      $COMPILER_FLAGS -I. -I"$LLAMA_CPP_DIR" -o $TARGET_NAME \
      interestnaut_llama.cpp -L"$LLAMA_LIB_DIR" -lllama
    ;;
esac

# Verify the wrapper was built successfully
if [ -f "$WRAPPER_DIR/$TARGET_NAME" ]; then
    print_status "Successfully built the wrapper library for $PLATFORM!"
    print_status "Wrapper location: $WRAPPER_DIR/$TARGET_NAME"
    exit 0
else
    print_error "Failed to build the wrapper library for $PLATFORM."
    exit 1
fi
