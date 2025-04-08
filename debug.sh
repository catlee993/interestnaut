#!/bin/bash
# Build with debug symbols
echo "Building with debug symbols..."
wails build -debug

# Run with Delve attached
echo "Starting Delve debugger..."
dlv --listen=:2345 --headless=true --api-version=2 --accept-multiclient exec ./build/bin/interestnaut.app/Contents/MacOS/interestnaut -- -debug &

# Wait for Delve to start
sleep 2

# Connect to the debugger and continue execution
echo "Connecting to debugger and continuing execution..."
dlv connect localhost:2345 --continue 