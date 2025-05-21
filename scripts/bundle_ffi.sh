#!/bin/bash
# bundle_ffi.sh - Build and bundle the Go FFI library
# This builds shared or static libraries containing Go code for the Flutter app
# The llama.cpp integration has been moved to a Dart implementation using llama_cpp_dart

set -e  # Exit on any errors

# Platform selection
PLATFORM=${1:-"macos"}  # Default to macOS if not specified

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"  # Parent directory of scripts

# Output paths
OUTPUT_DIR="$ROOT_DIR/build/$PLATFORM"
mkdir -p "$OUTPUT_DIR"

# Platform-specific paths for Flutter integration
MACOS_FLUTTER_DIR="$ROOT_DIR/internal/ui/flutter"
MACOS_DEV_DIR="$MACOS_FLUTTER_DIR/ffi"
MACOS_BUNDLE_PATHS=(
    "$MACOS_FLUTTER_DIR/build/macos/Build/Products/Release/interestnaut.app"
    "$MACOS_FLUTTER_DIR/build/macos/Build/Products/Debug/interestnaut.app"
)

IOS_FLUTTER_DIR="$ROOT_DIR/internal/ui/flutter"
IOS_DEV_DIR="$IOS_FLUTTER_DIR/ios/Runner"

# Colors for pretty output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'  # No Color

# Print a status message
print_status() {
    echo -e "${GREEN}[*]${NC} $1"
}

# Print a warning message
print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Print an error message
print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Build for macOS - creates a dylib
build_macos_shared() {
    print_status "Building Go library for macOS..."
    
    # Move to the cmd/interestnaut directory
    cd "$ROOT_DIR/cmd/interestnaut"
    
    # Build Go as a shared library
    CGO_ENABLED=1 go build -buildmode=c-shared -o "$OUTPUT_DIR/libinterestnaut.dylib" .
    
    if [ $? -ne 0 ]; then
        print_error "Failed to build Go library"
        exit 1
    fi
    
    print_status "Successfully built Go library for macOS"
    return 0
}

# Build for iOS - creates a static library
build_ios_static() {
    print_status "Building static library for iOS..."
    
    # Move to the cmd/interestnaut directory
    cd "$ROOT_DIR/cmd/interestnaut"
    
    # Build for iOS arm64
    CGO_ENABLED=1 GOOS=ios GOARCH=arm64 \
    go build -o "$OUTPUT_DIR/libinterestnaut_arm64.a" .
    
    if [ $? -ne 0 ]; then
        print_error "Failed to build Go static library for iOS arm64"
        exit 1
    fi
    
    print_status "Successfully built Go static library for iOS"
    return 0
}

# Deploy the shared library to the Flutter app for macOS
bundle_macos() {
    print_status "Building and deploying Go library for macOS..."
    
    # Build the macOS library
    build_macos_shared
    
    # Create the macOS dev directory if it doesn't exist
    mkdir -p "$MACOS_DEV_DIR"
    
    # Copy the library to the development directory
    cp "$OUTPUT_DIR/libinterestnaut.dylib" "$MACOS_DEV_DIR/"
    
    # IMPORTANT: Also copy directly to Flutter root directory
    # This is where Flutter is actually looking for the library during development
    cp "$OUTPUT_DIR/libinterestnaut.dylib" "$MACOS_FLUTTER_DIR/libinterestnaut.dylib"
    
    print_status "Go library deployed to dev directory: $MACOS_DEV_DIR"
    print_status "Go library also deployed to Flutter root: $MACOS_FLUTTER_DIR/libinterestnaut.dylib"
    
    # Check if there's a built app bundle to deploy to
    for bundle_path in "${MACOS_BUNDLE_PATHS[@]}"; do
        if [ -d "$bundle_path" ]; then
            print_status "Deploying to app bundle: $bundle_path"
            mkdir -p "$bundle_path/Contents/Frameworks/"
            cp "$OUTPUT_DIR/libinterestnaut.dylib" "$bundle_path/Contents/Frameworks/"
            break
        fi
    done
}

# Deploy the static library to the Flutter iOS app
bundle_ios() {
    print_status "Building and deploying Go static library for iOS..."
    
    # Build the iOS static library
    build_ios_static
    
    # Copy the static library and header to the iOS project
    mkdir -p "$IOS_DEV_DIR/Frameworks"
    cp "$OUTPUT_DIR/libinterestnaut_arm64.a" "$IOS_DEV_DIR/Frameworks/"
    
    print_status "Go static library deployed to: $IOS_DEV_DIR/Frameworks/"
}

# Main script logic
case "$PLATFORM" in
    "macos")
        bundle_macos
        ;;
    "ios")
        bundle_ios
        ;;
    "all")
        bundle_macos
        bundle_ios
        ;;
    *)
        print_error "Unknown platform: $PLATFORM"
        echo "Usage: $0 [macos|ios|all]"
        exit 1
        ;;
esac

print_status "Done bundling Go FFI library for $PLATFORM"
exit 0
