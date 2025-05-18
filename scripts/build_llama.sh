#!/bin/bash
# build_llama.sh - Build llama.cpp static library with signal handlers disabled

set -e

# Get the script directory and set root dir
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"  # Parent directory of scripts

# Llama.cpp directory
LLAMA_DIR="$ROOT_DIR/dependencies/llama.cpp"

# Build directory
BUILD_DIR="$LLAMA_DIR/build"

# Create build directory if it doesn't exist
mkdir -p "$BUILD_DIR"

# Colors for pretty output
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

# Navigate to the llama.cpp directory
cd "$LLAMA_DIR"

# Configure and build llama.cpp with signal handlers disabled
print_status "Configuring and building llama.cpp with signal handlers disabled..."
cmake -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release -DLLAMA_NATIVE=OFF -DBUILD_SHARED_LIBS=OFF -DLLAMA_STANDALONE=OFF

# Build the static library
cd "$BUILD_DIR"
print_status "Compiling llama.cpp static library..."
cmake --build . --config Release

# Check if the build succeeded by looking for the library files
FOUND_LIB=""
FOUND_GGML_LIB=""

# Check all potential library locations for libllama.a
POTENTIAL_LIBS=(
    "$BUILD_DIR/libllama.a"
    "$BUILD_DIR/lib/libllama.a"
    "$BUILD_DIR/src/libllama.a"
)

for lib in "${POTENTIAL_LIBS[@]}"; do
    if [ -f "$lib" ]; then
        FOUND_LIB="$lib"
        break
    fi
done

# Check all potential locations for libggml.a
POTENTIAL_GGML_LIBS=(
    "$BUILD_DIR/libggml.a"
    "$BUILD_DIR/lib/libggml.a"
    "$BUILD_DIR/ggml/src/libggml.a"
)

for lib in "${POTENTIAL_GGML_LIBS[@]}"; do
    if [ -f "$lib" ]; then
        FOUND_GGML_LIB="$lib"
        break
    fi
done

# If we couldn't find the libraries directly, search more broadly
if [ -z "$FOUND_LIB" ] || [ -z "$FOUND_GGML_LIB" ]; then
    print_status "Searching for libraries in build directory..."
    
    # Find all .a files in the build directory
    ALL_LIBS=$(find "$BUILD_DIR" -name "*.a" -type f)
    
    # Look for libllama.a if we didn't find it earlier
    if [ -z "$FOUND_LIB" ]; then
        for lib in $ALL_LIBS; do
            if [[ "$lib" == *"libllama.a" ]]; then
                FOUND_LIB="$lib"
                print_status "Found libllama.a at: $FOUND_LIB"
                break
            fi
        done
    fi
    
    # Look for libggml.a if we didn't find it earlier
    if [ -z "$FOUND_GGML_LIB" ]; then
        for lib in $ALL_LIBS; do
            if [[ "$lib" == *"libggml.a" ]]; then
                FOUND_GGML_LIB="$lib"
                print_status "Found libggml.a at: $FOUND_GGML_LIB"
                break
            fi
        done
    fi
fi

# Check if we found the libraries
if [ -n "$FOUND_LIB" ] && [ -n "$FOUND_GGML_LIB" ]; then
    # Create the link for libllama.a if needed
    if [ ! -f "$BUILD_DIR/libllama.a" ] || [ "$FOUND_LIB" != "$BUILD_DIR/libllama.a" ]; then
        ln -sf "$FOUND_LIB" "$BUILD_DIR/libllama.a"
        print_status "Created symlink from $FOUND_LIB to $BUILD_DIR/libllama.a"
    fi
    
    # Create the link for libggml.a if needed
    if [ ! -f "$BUILD_DIR/libggml.a" ] || [ "$FOUND_GGML_LIB" != "$BUILD_DIR/libggml.a" ]; then
        ln -sf "$FOUND_GGML_LIB" "$BUILD_DIR/libggml.a"
        print_status "Created symlink from $FOUND_GGML_LIB to $BUILD_DIR/libggml.a"
    fi
    
    # Copy the built libraries to internal/llama/build/ for easier linking
    LIB_OUTPUT_DIR="$ROOT_DIR/internal/llama/build"
    mkdir -p "$LIB_OUTPUT_DIR"
    cp -f "$BUILD_DIR/libllama.a" "$LIB_OUTPUT_DIR/"
    cp -f "$BUILD_DIR/libggml.a" "$LIB_OUTPUT_DIR/"
    
    # Also copy critical source files like gguf.cpp and common.cpp to internal/llama/src/ to allow direct compilation with our wrapper
    SRC_OUTPUT_DIR="$ROOT_DIR/internal/llama/src"
    mkdir -p "$SRC_OUTPUT_DIR"
    cp -f "$LLAMA_DIR/ggml/src/gguf.cpp" "$SRC_OUTPUT_DIR/" 2>/dev/null || true
    cp -f "$LLAMA_DIR/common/common.cpp" "$SRC_OUTPUT_DIR/" 2>/dev/null || true
    cp -f "$LLAMA_DIR/common/common.h" "$SRC_OUTPUT_DIR/" 2>/dev/null || true
    
    print_status "llama.cpp static libraries built successfully with signal handlers disabled"
    print_status "The static libraries are located at:"
    print_status "  - $BUILD_DIR/libllama.a"
    print_status "  - $BUILD_DIR/libggml.a"
    print_status "Header files are in: $LLAMA_DIR"
    print_status "Copied libraries to $LIB_OUTPUT_DIR"
    print_status "Copied source files to $SRC_OUTPUT_DIR"
    exit 0
else
    print_error "Failed to build llama.cpp static libraries!"
    
    if [ -z "$FOUND_LIB" ]; then
        print_error "Could not find libllama.a"
    fi
    
    if [ -z "$FOUND_GGML_LIB" ]; then
        print_error "Could not find libggml.a"
    fi
    
    # List all .a files in the build directory for debugging
    print_warning "Available .a files in the build directory:"
    find "$BUILD_DIR" -name "*.a" -type f | sort
    
    exit 1
fi
