#!/bin/bash

# Flutter protobuf generation script
# Generates Dart protobuf files from .proto definitions

set -e

# Ensure protoc-gen-dart is in PATH
export PATH="$PATH:$HOME/.pub-cache/bin"

# Check if protoc is available
if ! command -v protoc &> /dev/null; then
    echo "Error: protoc is not installed or not in PATH"
    exit 1
fi

# Check if protoc-gen-dart is available
if ! command -v protoc-gen-dart &> /dev/null; then
    echo "Error: protoc-gen-dart is not installed"
    echo "Run: flutter pub global activate protoc_plugin"
    exit 1
fi

# Clean existing generated files
echo "Cleaning existing generated files..."
rm -f lib/generated/recommendation.*

# Generate protobuf files
echo "Generating protobuf files..."
cd lib/proto
protoc --dart_out=grpc:../generated recommendation.proto
cd ../..

echo "Protobuf files generated successfully in lib/generated/"
ls -la lib/generated/recommendation.*