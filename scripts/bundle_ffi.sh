#!/bin/bash
# bundle_ffi.sh - Generic script to bundle FFI libraries for different platforms

set -e  # Exit on any errors

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"  # Parent directory of scripts

# Dependencies paths
DEPS_DIR="$ROOT_DIR/dependencies"
LLAMA_CPP_DIR="$DEPS_DIR/llama.cpp"
WRAPPER_DIR="$DEPS_DIR/wrapper"
WRAPPER_LIB="$WRAPPER_DIR/libinterestnaut_llama.dylib"

# Library names
DYLIB_NAME="libinterestnaut.dylib"
HEADER_NAME="libinterestnaut.h"
SRC_DYLIB="$ROOT_DIR/$DYLIB_NAME"
SRC_HEADER="$ROOT_DIR/$HEADER_NAME"

# Platform-specific paths
MACOS_FLUTTER_DIR="$ROOT_DIR/internal/ui/flutter"
MACOS_DEV_DIR="$MACOS_FLUTTER_DIR/ffi"
MACOS_BUNDLE_PATHS=(
    "$MACOS_FLUTTER_DIR/build/macos/Build/Products/Release/interestnaut.app"
    "$MACOS_FLUTTER_DIR/build/macos/Build/Products/Debug/interestnaut.app"
)

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

# Function to ensure llama.cpp wrapper is built
ensure_wrapper_built() {
    # Run the build script
    bash "$SCRIPT_DIR/build_llama.sh"
    if [ $? -ne 0 ]; then
        print_error "Failed to build llama.cpp wrapper. Please check the build log."
        return 1
    fi
    
    # Verify the library exists
    if [ ! -f "$WRAPPER_LIB" ]; then
        print_error "Error: libinterestnaut_llama.dylib not found at $WRAPPER_LIB"
        return 1
    fi
    
    return 0
}

print_status "Building FFI library..."
# Ensure llama.cpp wrapper is built
ensure_wrapper_built || exit 1

# Copy the wrapper library to the root directory
print_status "Copying wrapper library to FFI bundle..."
cp "$WRAPPER_LIB" "$SRC_DYLIB"
cp "$WRAPPER_DIR/interestnaut_llama.h" "$SRC_HEADER"

# Function to bundle for macOS
bundle_macos() {
    print_status "Bundling for macOS..."

    # Find the app bundle
    for BUNDLE_PATH in "${MACOS_BUNDLE_PATHS[@]}"; do
        if [ -d "$BUNDLE_PATH" ]; then
            # Copy the dylib and header to the Flutter macOS dev directory first
            mkdir -p "$MACOS_DEV_DIR"
            cp "$SRC_DYLIB" "$MACOS_DEV_DIR/"
            cp "$SRC_HEADER" "$MACOS_DEV_DIR/"
            
            # Copy the dylib to the app bundle
            mkdir -p "$BUNDLE_PATH/Contents/Frameworks"
            cp "$SRC_DYLIB" "$BUNDLE_PATH/Contents/Frameworks/"
            
            print_status "Successfully bundled FFI library for macOS at: $BUNDLE_PATH/Contents/Frameworks/$DYLIB_NAME"
            return 0
        fi
    done
    
    print_warning "No macOS app bundle found at expected paths. FFI library was built but not bundled."
    print_warning "Please build the Flutter app for macOS first, or copy the library manually."
    return 0
}

# Main script logic
case "$1" in
    "macos")
        bundle_macos
        ;;
    *)
        print_error "Usage: $0 [macos|ios|android|windows|linux]"
        print_error "Only 'macos' is currently supported."
        exit 1
        ;;
esac

print_status "FFI bundling complete!"
exit 0
