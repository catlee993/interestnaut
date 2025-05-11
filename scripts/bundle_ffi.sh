#!/bin/bash
# bundle_ffi.sh - Generic script to bundle FFI libraries for different platforms

set -e  # Exit on any errors

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"  # Parent directory of scripts

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

echo "Building FFI library..."
# Change to root directory before building
cd "$ROOT_DIR"
go build -buildmode=c-shared -o "$DYLIB_NAME" "./cmd/interestnaut/"

# Function to bundle for macOS
bundle_macos() {
    echo "Bundling for macOS..."
    
    # Find the app bundle
    local app_bundle=""
    for bundle in "${MACOS_BUNDLE_PATHS[@]}"; do
        if [ -d "$bundle" ]; then
            app_bundle="$bundle"
            break
        fi
    done
    
    if [ -z "$app_bundle" ]; then
        echo "No app bundle found. Please build the app first with 'flutter build macos'."
        return 1
    fi
    
    # Create necessary directories
    local frameworks_dir="$app_bundle/Contents/Frameworks"
    local resources_dir="$app_bundle/Contents/Resources"
    local macos_dir="$app_bundle/Contents/MacOS"
    
    mkdir -p "$frameworks_dir"
    mkdir -p "$resources_dir"
    mkdir -p "$MACOS_DEV_DIR"
    
    # Move the library to app bundle and header to dev directory
    mv "$SRC_DYLIB" "$frameworks_dir/$DYLIB_NAME"
    mv "$SRC_HEADER" "$MACOS_DEV_DIR/$HEADER_NAME"
    
    cp "$frameworks_dir/$DYLIB_NAME" "$resources_dir/$DYLIB_NAME"
    cp "$frameworks_dir/$DYLIB_NAME" "$macos_dir/$DYLIB_NAME"
    
    otool -L "$frameworks_dir/$DYLIB_NAME" || true
    
    echo "FFI files bundled successfully for macOS!"
}

# Main script logic
case "$1" in
    "macos")
        bundle_macos
        # Clean up the source files after bundling
        echo "Cleaning up source files from the root directory..."
        rm -f "$SRC_DYLIB" "$SRC_HEADER"
        echo "Cleanup completed."
        ;;
    *)
        echo "Usage: $0 [macos]"
        echo "  macos - Bundle for macOS development"
        exit 1
        ;;
esac
