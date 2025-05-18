#!/bin/bash
# bundle_ffi.sh - Build and bundle the Go FFI library with llama.cpp integrated
# This builds shared or static libraries containing Go code with direct llama.cpp integration

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

# Set up llama.cpp paths
LLAMA_DIR="$ROOT_DIR/dependencies/llama.cpp"
LLAMA_BUILD_DIR="$LLAMA_DIR/build"
LLAMA_STATIC_LIB="$LLAMA_BUILD_DIR/libllama.a"
GGML_STATIC_LIB="$LLAMA_BUILD_DIR/libggml.a"

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

# Function to ensure llama.cpp is built as a static library with signal handlers disabled
ensure_llama_built() {
    print_status "Ensuring llama.cpp is built correctly..."
    
    # Run the build script
    "$SCRIPT_DIR/build_llama.sh" ${PLATFORM}
    
    # Check if the build succeeded
    if [ ! -f "$LLAMA_STATIC_LIB" ]; then
        print_error "Failed to find llama.cpp static library at $LLAMA_STATIC_LIB"
        return 1
    fi
    
    if [ ! -f "$GGML_STATIC_LIB" ]; then
        print_error "Failed to find ggml static library at $GGML_STATIC_LIB"
        return 1
    fi
    
    print_status "llama.cpp libraries are ready"
    return 0
}

# Function to find all static libs in the llama.cpp build directory
find_llama_libs() {
    # Find all relevant static libraries
    LLAMA_LIBS=()
    
    # Main libraries
    LLAMA_LIBS+=("$LLAMA_BUILD_DIR/libllama.a")
    LLAMA_LIBS+=("$LLAMA_BUILD_DIR/libggml.a")
    
    # Additional libraries if they exist
    for lib in "$LLAMA_BUILD_DIR/ggml/src/libggml-base.a" \
               "$LLAMA_BUILD_DIR/ggml/src/libggml-cpu.a" \
               "$LLAMA_BUILD_DIR/common/libcommon.a" \
               "$LLAMA_BUILD_DIR/ggml/src/ggml-metal/libggml-metal.a" \
               "$LLAMA_BUILD_DIR/ggml/src/ggml-blas/libggml-blas.a"; do
        if [ -f "$lib" ]; then
            LLAMA_LIBS+=("$lib")
        fi
    done
    
    # Create an include directory for all header files
    INCLUDE_DIR="$ROOT_DIR/internal/llama/include"
    mkdir -p "$INCLUDE_DIR"
    
    # Copy header files to the include directory
    cp -f "$LLAMA_DIR/include/"*.h "$INCLUDE_DIR/" 2>/dev/null || true
    cp -f "$LLAMA_DIR/common/"*.h "$INCLUDE_DIR/" 2>/dev/null || true
    cp -f "$LLAMA_DIR/ggml/include/"*.h "$INCLUDE_DIR/" 2>/dev/null || true
    
    return 0
}

# Build and compile the llama wrapper into a static library
build_llama_wrapper() {
    print_status "Compiling C wrapper code into static library..."
    
    # Create a build directory if it doesn't exist
    WRAPPER_DIR="$ROOT_DIR/internal/llama"
    WRAPPER_BUILD_DIR="$WRAPPER_DIR/build"
    mkdir -p "$WRAPPER_BUILD_DIR"
    
    # Compile the wrapper with direct access to llama.cpp
    CC=${CC:-clang}
    
    # First compile the wrapper
    $CC -c \
        -I"$LLAMA_DIR/include" \
        -I"$LLAMA_DIR/common" \
        -I"$LLAMA_DIR/ggml/include" \
        -fPIC -o "$WRAPPER_BUILD_DIR/llama_wrapper.o" \
        "$WRAPPER_DIR/llama_wrapper.c"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to compile C wrapper code"
        exit 1
    fi
    
    # Then create static library from it
    ar rcs "$WRAPPER_BUILD_DIR/libllama_wrapper.a" "$WRAPPER_BUILD_DIR/llama_wrapper.o"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to create wrapper static library"
        exit 1
    fi
    
    print_status "Successfully built wrapper static library: $WRAPPER_BUILD_DIR/libllama_wrapper.a"
    return 0
}

# Build for macOS - creates a shared library
build_macos_shared() {
    print_status "Building shared library for macOS..."
    
    # Ensure llama.cpp is built as a static library with signal handlers disabled
    ensure_llama_built
    if [ $? -ne 0 ]; then
        print_error "Failed to build llama.cpp static library"
        exit 1
    fi
    
    # Find all llama.cpp libraries and headers
    find_llama_libs
    
    # Make sure our llama wrapper files are available
    WRAPPER_DIR="$ROOT_DIR/internal/llama"
    if [ ! -f "$WRAPPER_DIR/llama_wrapper.h" ] || [ ! -f "$WRAPPER_DIR/llama_wrapper.c" ]; then
        print_error "Wrapper files not found in $WRAPPER_DIR"
        exit 1
    fi
    
    # Build the wrapper into a static library
    build_llama_wrapper
    
    print_status "Building Go shared library for macOS..."
    
    # Move to the Go code directory
    cd "$ROOT_DIR/cmd/interestnaut"
    
    # Generate a list of additional linked libraries
    ADDITIONAL_LIBS=""
    for lib in "${LLAMA_LIBS[@]}"; do
        ADDITIONAL_LIBS="$ADDITIONAL_LIBS -L$(dirname "$lib") -l$(basename "${lib%.a}" | sed 's/^lib//')"
    done
    
    # Add the wrapper object file directly to the link
    WRAPPER_LIB="$WRAPPER_BUILD_DIR/libllama_wrapper.a"
    
    # Use CGO_LDFLAGS to specify all the libraries and flags needed
    CGO_CFLAGS="-I$LLAMA_DIR/include -I$LLAMA_DIR/common -I$LLAMA_DIR/ggml/include -I$WRAPPER_DIR" \
    CGO_LDFLAGS="-L$LLAMA_BUILD_DIR -L$WRAPPER_BUILD_DIR -lllama_wrapper -lllama -lggml $ADDITIONAL_LIBS -lstdc++ -lm -framework Accelerate -framework Foundation -framework Metal" \
    go build -buildmode=c-shared -o "$OUTPUT_DIR/libinterestnaut.dylib" .
    
    if [ $? -ne 0 ]; then
        print_error "Failed to build Go shared library"
        exit 1
    fi
    
    # Create a simple C header file for external use if go did not generate one
    if [ ! -f "$OUTPUT_DIR/libinterestnaut.h" ]; then
        print_status "Generating C header file for the library..."
        cat > "$OUTPUT_DIR/libinterestnaut.h" << EOF
// Generated libinterestnaut header
#ifndef LIBINTERESTNAUT_H
#define LIBINTERESTNAUT_H

#ifdef __cplusplus
extern "C" {
#endif

// Go exported functions will be declared here
void InterestnautInitialize();
void* InterestnautLoadModel(const char* path);
void InterestnautFreeModel(void* model);
void* InterestnautNewContext(void* model, int n_ctx);
void InterestnautFreeContext(void* ctx);
char* InterestnautGenerate(const char* model_path, const char* prompt, int max_tokens);
void InterestnautFreeString(char* str);

#ifdef __cplusplus
}
#endif

#endif // LIBINTERESTNAUT_H
EOF
    fi
    
    print_status "Successfully built Go shared library: $OUTPUT_DIR/libinterestnaut.dylib"
    return 0
}

# Build for iOS - creates a static library
build_ios_static() {
    print_status "Building static library for iOS..."
    
    # Ensure llama.cpp is built as a static library
    ensure_llama_built
    if [ $? -ne 0 ]; then
        print_error "Failed to build llama.cpp static library"
        exit 1
    fi
    
    # Find all llama.cpp libraries and headers
    find_llama_libs
    
    # Make sure our llama wrapper files are available
    WRAPPER_DIR="$ROOT_DIR/internal/llama"
    if [ ! -f "$WRAPPER_DIR/llama_wrapper.h" ] || [ ! -f "$WRAPPER_DIR/llama_wrapper.c" ]; then
        print_error "Wrapper files not found in $WRAPPER_DIR"
        exit 1
    fi
    
    # Compile the wrapper with direct access to llama.cpp for iOS
    print_status "Compiling C wrapper code for iOS..."
    
    # Create a build directory if it doesn't exist
    WRAPPER_BUILD_DIR="$WRAPPER_DIR/build/ios"
    mkdir -p "$WRAPPER_BUILD_DIR"
    
    # Compile the wrapper with direct access to llama.cpp for iOS
    IOS_SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
    CC=${CC:-clang}
    $CC -c \
        -isysroot "$IOS_SDK_PATH" \
        -arch arm64 \
        -I"$LLAMA_DIR/include" \
        -I"$LLAMA_DIR/common" \
        -I"$LLAMA_DIR/ggml/include" \
        -fPIC -o "$WRAPPER_BUILD_DIR/llama_wrapper_ios.o" \
        "$WRAPPER_DIR/llama_wrapper.c"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to compile C wrapper code for iOS"
        exit 1
    fi
    
    # Then create static library from it
    ar rcs "$WRAPPER_BUILD_DIR/libllama_wrapper.a" "$WRAPPER_BUILD_DIR/llama_wrapper_ios.o"
    
    # Use gomobile for iOS
    export PATH=$PATH:$(go env GOPATH)/bin
    
    # Make sure gomobile is installed
    if ! command -v gomobile >/dev/null 2>&1; then
        print_status "Installing gomobile..."
        go install golang.org/x/mobile/cmd/gomobile@latest
        gomobile init
    fi
    
    # Move to the Go code directory
    cd "$ROOT_DIR/cmd/interestnaut"
    
    # Generate a list of additional linked libraries
    ADDITIONAL_LIBS=""
    for lib in "${LLAMA_LIBS[@]}"; do
        ADDITIONAL_LIBS="$ADDITIONAL_LIBS -L$(dirname "$lib") -l$(basename "${lib%.a}" | sed 's/^lib//')"
    done
    
    print_status "Building Go framework for iOS with gomobile..."
    
    # Build for iOS using gomobile
    GOOS=darwin GOARCH=arm64 CGO_ENABLED=1 \
    CGO_CFLAGS="-I$LLAMA_DIR/include -I$LLAMA_DIR/common -I$LLAMA_DIR/ggml/include -I$WRAPPER_DIR" \
    CGO_LDFLAGS="-L$LLAMA_BUILD_DIR -L$WRAPPER_BUILD_DIR -lllama_wrapper -lllama -lggml $ADDITIONAL_LIBS -lstdc++ -lm" \
    gomobile bind -target=ios -o "$OUTPUT_DIR/Interestnaut.framework" ./...
    
    if [ $? -ne 0 ]; then
        print_error "Failed to build Go framework for iOS"
        exit 1
    fi
    
    print_status "Successfully built Go framework for iOS: $OUTPUT_DIR/Interestnaut.framework"
    return 0
}

# Deploy the shared library to the Flutter app for macOS
bundle_macos() {
    print_status "Bundling for macOS..."
    
    # Build the shared library for macOS
    build_macos_shared
    
    # Copy the shared library to the Flutter package dev directory
    mkdir -p "$MACOS_DEV_DIR"
    cp -f "$OUTPUT_DIR/libinterestnaut.dylib" "$MACOS_DEV_DIR/"
    cp -f "$OUTPUT_DIR/libinterestnaut.h" "$MACOS_DEV_DIR/"
    
    # Check if any Flutter bundle exists
    for bundle_path in "${MACOS_BUNDLE_PATHS[@]}"; do
        if [ -d "$bundle_path" ]; then
            print_status "Found Flutter macOS bundle at $bundle_path"
            mkdir -p "$bundle_path/Contents/Frameworks/"
            cp -f "$OUTPUT_DIR/libinterestnaut.dylib" "$bundle_path/Contents/Frameworks/"
            print_status "Copied shared library to macOS app bundle"
        fi
    done
    
    print_status "macOS FFI library bundling complete!"
    return 0
}

# Deploy the static library to the Flutter iOS app
bundle_ios() {
    print_status "Bundling for iOS..."
    
    # Build the static library for iOS
    build_ios_static
    
    # Copy the framework to the Flutter Runner directory
    mkdir -p "$IOS_DEV_DIR/Frameworks"
    cp -R "$OUTPUT_DIR/Interestnaut.framework" "$IOS_DEV_DIR/Frameworks/"
    
    # Update the Runner Xcode project to include the framework - requires pbxproj gem
    if command -v xcodeproj > /dev/null; then
        print_status "Adding framework to Xcode project..."
        xcodeproj add-framework --project "$IOS_DEV_DIR/../Runner.xcodeproj" --target Runner "$IOS_DEV_DIR/Frameworks/Interestnaut.framework"
    else
        print_warning "xcodeproj command not found. You'll need to manually add the framework to the Runner target in Xcode."
    fi
    
    print_status "iOS FFI library bundling complete!"
    return 0
}

# Main script logic
case "$PLATFORM" in
    "macos")
        bundle_macos
        ;;
    "ios")
        bundle_ios
        ;;
    *)
        print_error "Unknown platform: $PLATFORM. Valid options are 'macos' or 'ios'."
        exit 1
        ;;
esac

print_status "FFI library bundling complete for $PLATFORM!"
exit 0
