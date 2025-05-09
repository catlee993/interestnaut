#!/bin/bash
# bundle_ffi.sh - Generic script to bundle FFI libraries for different platforms

set -e  # Exit on any errors

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$SCRIPT_DIR"

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
go build -buildmode=c-shared -o "$DYLIB_NAME" "./cmd/interestnaut/"

# Function to bundle for macOS
bundle_macos() {
    local is_release=$1
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
    
    echo "Found app bundle at: $app_bundle"
    
    # Create necessary directories
    local frameworks_dir="$app_bundle/Contents/Frameworks"
    local resources_dir="$app_bundle/Contents/Resources"
    local macos_dir="$app_bundle/Contents/MacOS"
    
    mkdir -p "$frameworks_dir"
    mkdir -p "$resources_dir"
    mkdir -p "$MACOS_DEV_DIR"
    
    # Move the library to app bundle and header to dev directory
    echo "Moving FFI files..."
    mv "$SRC_DYLIB" "$frameworks_dir/$DYLIB_NAME"
    mv "$SRC_HEADER" "$MACOS_DEV_DIR/$HEADER_NAME"
    
    if [ "$is_release" = true ]; then
        cp "$frameworks_dir/$DYLIB_NAME" "$resources_dir/$DYLIB_NAME"
        cp "$frameworks_dir/$DYLIB_NAME" "$macos_dir/$DYLIB_NAME"
    fi
    
    echo "Checking install name tool settings..."
    otool -L "$frameworks_dir/$DYLIB_NAME" || true
    
    echo "FFI files bundled successfully for macOS!"
}

# Main script logic
case "$1" in
    "macos")
        bundle_macos false
        ;;
    "macos-release")
        bundle_macos true
        ;;
    *)
        echo "Usage: $0 [macos|macos-release]"
        echo "  macos         - Bundle for macOS development"
        echo "  macos-release - Bundle for macOS distribution"
        exit 1
        ;;
esac 