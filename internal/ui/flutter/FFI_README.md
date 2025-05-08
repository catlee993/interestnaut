# Go-Flutter FFI Bridge

This document explains how Foreign Function Interface (FFI) is implemented between Go and Flutter in the Interestnaut app.

## Overview

The FFI implementation allows direct communication between the Flutter UI and Go backend without a separate service layer. Go exports functions that are called directly from Dart code.

## Architecture

The architecture consists of three main components:

1. **Go FFI Exports**: Go functions exported with CGO annotations
2. **Shared Library**: Compiled Go code as a dynamic library (.dylib, .dll, or .so)
3. **Dart FFI Bindings**: Dart code that loads the library and maps to Go functions

## Directory Structure

```
internal/
  ├── app/
  │   └── ffi/                  # Go FFI implementation
  │       ├── bridge.go         # Core FFI utilities
  │       ├── music.go          # Music-specific FFI exports
  │       ├── movies.go         # Movie-specific FFI exports
  │       └── ...               # Other service-specific exports
  └── ui/
      └── flutter/
          └── lib/
              └── services/
                  ├── ffi_bridge.dart    # Library loading and base utilities
                  ├── ffi_init.dart      # Initialization logic
                  ├── go_bindings.dart   # High-level API for Dart
                  └── ...
```

## How It Works

### 1. Go Side

The Go code exports functions using CGO with the `//export` annotation:

```go
//export Movies_GetMovieDetails
func Movies_GetMovieDetails(movieIDC C.int) *C.char {
    // Implementation...
}
```

These exported functions are compiled into a shared library using:

```bash
go build -buildmode=c-shared -o libinterestnaut.dylib ./cmd/interestnaut/
```

### 2. Flutter Side

Dart code loads the shared library and maps Go functions:

```dart
class MoviesFFI extends FFIBindingBase {
  late final _getMovieDetails = GoFFILibrary.dylib
    .lookupFunction<
      Pointer<Char> Function(Int),
      Pointer<Char> Function(int)
    >('Movies_GetMovieDetails');
    
  // Public API that uses the FFI function
  Future<Map<String, dynamic>> getMovieDetails(int id) async {
    // Implementation...
  }
}
```

## Library Loading

The shared library is placed in different locations based on the platform:

- **macOS**: 
  - Development: In the Flutter app directory
  - Production: In the app bundle's Frameworks, Resources, and MacOS directories
- **Windows**: Next to the executable
- **Linux**: Next to the executable

The `GoFFILibrary` class handles searching for the library in multiple locations.

## Debugging

Use the `DebugFFI` class to diagnose library loading issues:

```dart
DebugFFI.verifyLibraryLoading();
```

## Building and Deploying

For macOS, use the `bundle_dylib.sh` script to bundle the library with the app:

```bash
# For development
./macos/bundle_dylib.sh

# For release builds
./macos/bundle_dylib.sh release
```

## Common Issues

1. **Library Not Found**: Ensure the library is in the correct location
2. **Symbol Not Found**: Check that the function name matches exactly between Go and Dart
3. **String Handling**: Remember to free C strings allocated by Go

## Memory Management

Go allocates C strings that must be freed by Dart. The `FFIBindingBase` class provides utility methods for handling this:

```dart
// Helper to free a string allocated by Go
final _freeString = GoFFILibrary.dylib
  .lookupFunction<
    Void Function(Pointer<Char>),
    void Function(Pointer<Char>)
  >('FreeString');
```

## Security Considerations

The FFI bindings expose Go functions directly to Dart, so ensure that:

1. Input validation is performed on both sides
2. Sensitive operations are properly authenticated
3. Error handling is robust to prevent crashes

## References

- [Dart FFI Documentation](https://dart.dev/guides/libraries/c-interop)
- [Go CGO Documentation](https://pkg.go.dev/cmd/cgo) 