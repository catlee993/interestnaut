#!/bin/bash
set -e

# Get the path to the built app bundle
APP_PATH="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"
FRAMEWORKS_PATH="${APP_PATH}/Contents/Frameworks"
RESOURCES_PATH="${APP_PATH}/Contents/Resources"
MACOS_PATH="${APP_PATH}/Contents/MacOS"

# Create directories if they don't exist
mkdir -p "$FRAMEWORKS_PATH"
mkdir -p "$RESOURCES_PATH"
mkdir -p "$MACOS_PATH"

# Copy the shared library to multiple locations for redundancy
echo "Copying libinterestnaut.dylib to app bundle locations..."
cp "../../libinterestnaut.dylib" "$FRAMEWORKS_PATH/libinterestnaut.dylib"
cp "../../libinterestnaut.dylib" "$RESOURCES_PATH/libinterestnaut.dylib"
cp "../../libinterestnaut.dylib" "$MACOS_PATH/libinterestnaut.dylib"

echo "Shared library copied to app bundle"
