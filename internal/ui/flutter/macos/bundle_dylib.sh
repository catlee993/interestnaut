#!/bin/bash
# bundle_dylib.sh - Helper script to bundle the Go shared library into the macOS app bundle

set -e  # Exit on any errors

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FLUTTER_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(dirname "$(dirname "$(dirname "$FLUTTER_DIR")")")"

# Library filename
DYLIB_NAME="libinterestnaut.dylib"
SRC_DYLIB="$ROOT_DIR/$DYLIB_NAME"
FLUTTER_DYLIB="$FLUTTER_DIR/$DYLIB_NAME"

echo "Script directory: $SCRIPT_DIR"
echo "Flutter directory: $FLUTTER_DIR"
echo "Root directory: $ROOT_DIR"
echo "Source dylib: $SRC_DYLIB"

# Check if the library exists at the root
if [ ! -f "$SRC_DYLIB" ]; then
    echo "Building shared library..."
    pushd "$ROOT_DIR" > /dev/null
    go build -buildmode=c-shared -o "$DYLIB_NAME" "./cmd/interestnaut/"
    popd > /dev/null
fi

# Copy the library to the Flutter directory for development
echo "Copying shared library to Flutter directory..."
cp "$SRC_DYLIB" "$FLUTTER_DYLIB"

# If we're building for release/distribution, copy to the app bundle
if [ -n "$1" ] && [ "$1" = "release" ]; then
    echo "Preparing for release build..."
    
    # Check if we have a built app bundle
    APP_BUNDLE_PATHS=(
        "$FLUTTER_DIR/build/macos/Build/Products/Release/interestnaut.app"
        "$FLUTTER_DIR/build/macos/Build/Products/Debug/interestnaut.app"
    )
    
    for APP_BUNDLE in "${APP_BUNDLE_PATHS[@]}"; do
        if [ -d "$APP_BUNDLE" ]; then
            echo "Found app bundle at: $APP_BUNDLE"
            
            # Create necessary directories
            FRAMEWORKS_DIR="$APP_BUNDLE/Contents/Frameworks"
            RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
            MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
            
            mkdir -p "$FRAMEWORKS_DIR"
            mkdir -p "$RESOURCES_DIR"
            
            # Copy the library to multiple locations for redundancy
            echo "Copying shared library to app bundle locations..."
            cp "$SRC_DYLIB" "$FRAMEWORKS_DIR/$DYLIB_NAME"
            cp "$SRC_DYLIB" "$RESOURCES_DIR/$DYLIB_NAME"
            cp "$SRC_DYLIB" "$MACOS_DIR/$DYLIB_NAME"
            
            echo "Checking install name tool settings..."
            otool -L "$FRAMEWORKS_DIR/$DYLIB_NAME" || true
            
            echo "Shared library bundled successfully!"
            exit 0
        fi
    done
    
    echo "No app bundle found. Please build the app first with 'flutter build macos'."
    exit 1
fi

echo "Shared library prepared for development."
exit 0 