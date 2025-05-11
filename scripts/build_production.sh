#!/bin/bash
# Production build script for Interestnaut app
# This script builds both the Go backend and Flutter frontend for production

set -e  # Exit on error

# Configuration
APP_NAME="Interestnaut"
GO_MAIN_PATH="cmd/interestnaut"
FLUTTER_APP_PATH="internal/ui/flutter"
OUTPUT_DIR="dist"

# Define platform-specific settings
case "$(uname)" in
  "Darwin")  # macOS
    PLATFORM="macos"
    GO_OUTPUT="interestnaut"
    SHARED_LIB="libinterestnaut.dylib"
    FLUTTER_BUILD_CMD="flutter build macos --release"
    APP_BUNDLE_PATH="$FLUTTER_APP_PATH/build/macos/Build/Products/Release/$APP_NAME.app"
    FRAMEWORKS_PATH="$APP_BUNDLE_PATH/Contents/Frameworks"
    ;;
  "Linux")
    PLATFORM="linux"
    GO_OUTPUT="interestnaut"
    SHARED_LIB="libinterestnaut.so"
    FLUTTER_BUILD_CMD="flutter build linux --release"
    APP_BUNDLE_PATH="$FLUTTER_APP_PATH/build/linux/x64/release/bundle"
    LIB_PATH="$APP_BUNDLE_PATH/lib"
    ;;
  "MINGW"*|"MSYS"*)  # Windows
    PLATFORM="windows"
    GO_OUTPUT="interestnaut.exe"
    SHARED_LIB="interestnaut.dll"
    FLUTTER_BUILD_CMD="flutter build windows --release"
    APP_BUNDLE_PATH="$FLUTTER_APP_PATH/build/windows/runner/Release"
    ;;
  *)
    echo "Unsupported platform: $(uname)"
    exit 1
    ;;
esac

echo "Building for platform: $PLATFORM"

# Create output directory
mkdir -p $OUTPUT_DIR

# Step 1: Build Go binary and shared library
echo "Building Go application..."
go build -o $OUTPUT_DIR/$GO_OUTPUT $GO_MAIN_PATH
echo "Building Go shared library..."
go build -buildmode=c-shared -o $OUTPUT_DIR/$SHARED_LIB $GO_MAIN_PATH

# Step 2: Build Flutter app
echo "Building Flutter app..."
cd $FLUTTER_APP_PATH
$FLUTTER_BUILD_CMD
cd ../../../

# Step 3: Copy shared library to Flutter app bundle
echo "Copying shared library to Flutter app bundle..."
if [ "$PLATFORM" == "macos" ]; then
  mkdir -p "$FRAMEWORKS_PATH"
  cp "$OUTPUT_DIR/$SHARED_LIB" "$FRAMEWORKS_PATH/"
  # Sign the library with the same identity as the app
  echo "Adjusting library permissions..."
  chmod +x "$FRAMEWORKS_PATH/$SHARED_LIB"
elif [ "$PLATFORM" == "linux" ]; then
  mkdir -p "$LIB_PATH"
  cp "$OUTPUT_DIR/$SHARED_LIB" "$LIB_PATH/"
elif [ "$PLATFORM" == "windows" ]; then
  cp "$OUTPUT_DIR/$SHARED_LIB" "$APP_BUNDLE_PATH/"
fi

# Step 4: Create the final distribution package
echo "Creating final distribution package..."
if [ "$PLATFORM" == "macos" ]; then
  # For macOS, create a disk image (.dmg) or zip file
  mkdir -p "$OUTPUT_DIR/Interestnaut"
  cp -R "$APP_BUNDLE_PATH" "$OUTPUT_DIR/Interestnaut/"
  cp "$OUTPUT_DIR/$GO_OUTPUT" "$OUTPUT_DIR/Interestnaut/"
  # Create a launcher script
  cat > "$OUTPUT_DIR/Interestnaut/launch.sh" << EOF
#!/bin/bash
cd "\$(dirname "\$0")"
./interestnaut
EOF
  chmod +x "$OUTPUT_DIR/Interestnaut/launch.sh"
  
  # Create a ZIP archive
  cd "$OUTPUT_DIR"
  zip -r Interestnaut-macOS.zip Interestnaut
  cd ..
  echo "Created macOS package: $OUTPUT_DIR/Interestnaut-macOS.zip"
elif [ "$PLATFORM" == "linux" ]; then
  # For Linux, create a tar.gz archive
  mkdir -p "$OUTPUT_DIR/Interestnaut"
  cp -R "$APP_BUNDLE_PATH"/* "$OUTPUT_DIR/Interestnaut/"
  cp "$OUTPUT_DIR/$GO_OUTPUT" "$OUTPUT_DIR/Interestnaut/"
  # Create a launcher script
  cat > "$OUTPUT_DIR/Interestnaut/launch.sh" << EOF
#!/bin/bash
cd "\$(dirname "\$0")"
./interestnaut
EOF
  chmod +x "$OUTPUT_DIR/Interestnaut/launch.sh"
  
  # Create a tar.gz archive
  cd "$OUTPUT_DIR"
  tar -czf Interestnaut-Linux.tar.gz Interestnaut
  cd ..
  echo "Created Linux package: $OUTPUT_DIR/Interestnaut-Linux.tar.gz"
elif [ "$PLATFORM" == "windows" ]; then
  # For Windows, create a zip file
  mkdir -p "$OUTPUT_DIR/Interestnaut"
  cp -R "$APP_BUNDLE_PATH"/* "$OUTPUT_DIR/Interestnaut/"
  cp "$OUTPUT_DIR/$GO_OUTPUT" "$OUTPUT_DIR/Interestnaut/"
  
  # Create a launcher batch file
  cat > "$OUTPUT_DIR/Interestnaut/launch.bat" << EOF
@echo off
cd /d "%~dp0"
start interestnaut.exe
EOF
  
  # Create a ZIP archive
  cd "$OUTPUT_DIR"
  # Use zip command if available, or powershell otherwise
  if command -v zip &> /dev/null; then
    zip -r Interestnaut-Windows.zip Interestnaut
  else
    powershell Compress-Archive -Path Interestnaut -DestinationPath Interestnaut-Windows.zip
  fi
  cd ..
  echo "Created Windows package: $OUTPUT_DIR/Interestnaut-Windows.zip"
fi

echo "Build completed successfully!"
echo "Distribution package created in $OUTPUT_DIR" 