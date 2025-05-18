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

# Build the Go FFI library with all exported symbols
print_status "Building Go FFI library with exported symbols..."
cd "$ROOT_DIR"
go build -mod=mod -o "$SRC_DYLIB" -buildmode=c-shared ./cmd/interestnaut || {
    print_error "Failed to build Go FFI library"
    exit 1
}

# Verify the exported symbols
if command -v nm >/dev/null 2>&1; then
    print_status "Verifying exported FFI symbols..."
    if ! nm -g "$SRC_DYLIB" | grep -q "GGUF_"; then
        print_warning "Warning: GGUF symbols might not be properly exported!"
        print_warning "This could lead to 'symbol not found' errors at runtime."
    else
        print_status "GGUF symbols properly exported."
    fi
fi

# Copy the llama wrapper library to a consistent location
print_status "Copying wrapper library..."
cp "$WRAPPER_LIB" "$ROOT_DIR/libinterestnaut_llama.dylib"
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
            
            # Also copy libinterestnaut_llama.dylib to the app bundle's Frameworks directory
            print_status "Copying libinterestnaut_llama.dylib to app bundle Frameworks directory..."
            cp "$WRAPPER_LIB" "$BUNDLE_PATH/Contents/Frameworks/libinterestnaut_llama.dylib"
            
            # Also copy libllama.dylib to the app bundle's Frameworks directory
            LLAMA_LIB=""
            POSSIBLE_LLAMA_PATHS=(
                "$DEPS_DIR/llama.cpp/build/bin/libllama.dylib"
                "$DEPS_DIR/wrapper/lib/libllama.dylib"
            )
            
            for POSSIBLE_PATH in "${POSSIBLE_LLAMA_PATHS[@]}"; do
                if [ -f "$POSSIBLE_PATH" ]; then
                    LLAMA_LIB="$POSSIBLE_PATH"
                    break
                fi
            done
            
            if [ -n "$LLAMA_LIB" ]; then
                print_status "Found libllama.dylib at: $LLAMA_LIB"
                print_status "Copying libllama.dylib to app bundle Frameworks directory..."
                cp "$LLAMA_LIB" "$BUNDLE_PATH/Contents/Frameworks/"
                # Also copy to the Flutter dev directory
                cp "$LLAMA_LIB" "$MACOS_DEV_DIR/"
                # Also copy to the Flutter package directory
                cp "$LLAMA_LIB" "$MACOS_FLUTTER_DIR/"
            else
                print_warning "Could not find libllama.dylib in any of the expected locations."
                print_warning "The app may fail to load the FFI library."
            fi
            
            # Fix library paths using install_name_tool
            print_status "Fixing library paths with install_name_tool..."
            
            # Update libinterestnaut.dylib to look for dependencies in @rpath
            install_name_tool -change "libinterestnaut_llama.dylib" "@rpath/libinterestnaut_llama.dylib" "$BUNDLE_PATH/Contents/Frameworks/libinterestnaut.dylib" || {
                print_warning "Failed to update libinterestnaut.dylib dependency path"
            }
            
            # Update libinterestnaut_llama.dylib to look for dependencies in @rpath
            install_name_tool -change "libllama.dylib" "@rpath/libllama.dylib" "$BUNDLE_PATH/Contents/Frameworks/libinterestnaut_llama.dylib" || {
                print_warning "Failed to update libinterestnaut_llama.dylib dependency path"
            }
            
            # Add @rpath to the app binary
            install_name_tool -add_rpath "@executable_path/../Frameworks" "$BUNDLE_PATH/Contents/MacOS/interestnaut" || {
                print_warning "Failed to add @rpath to app binary"
            }
            
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
