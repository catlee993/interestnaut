import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'ffi_bridge.dart';

/// Initialize the FFI bindings
/// This should be called early in the app's lifecycle, ideally before any UI is shown
class FFIInitializer {
  static bool _initialized = false;
  static ffi.DynamicLibrary? _dylib;
  static final List<String> _searchPaths = [];
  
  /// Whether FFI bindings are initialized successfully
  static bool get isInitialized => _initialized && _dylib != null;
  
  /// Get the search paths tried
  static List<String> get searchPaths => List.unmodifiable(_searchPaths);
  
  /// Get the loaded library
  static ffi.DynamicLibrary get dylib {
    if (!isInitialized) {
      throw Exception("FFI library not initialized. Call initialize() first.");
    }
    return _dylib!;
  }
  
  /// Verify that the library is usable by trying to load a known function
  static bool _verifyLibrary(ffi.DynamicLibrary library) {
    try {
      // Try to look up a known function to validate the library
      final freeString = library.lookup<
        ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Char>)>
      >('FreeString');
      return freeString != null;
    } catch (e) {
      debugPrint('Library verification failed: $e');
      return false;
    }
  }
  
  /// Initialize the FFI bindings
  static Future<void> initialize() async {
    if (isInitialized) {
      debugPrint('FFI bindings already initialized and verified, skipping');
      return;
    }
    
    _searchPaths.clear();
    debugPrint('Initializing FFI bindings...');
    
    // Try direct project root approach first
    final projectRoot = '/Users/catastrophe/stuff/interestnaut';
    final libraryName = 'libinterestnaut.dylib';
    final libPath = path.join(projectRoot, libraryName);
    _searchPaths.add(libPath);
    
    if (File(libPath).existsSync()) {
      try {
        debugPrint('Attempting to load library from: $libPath');
        final lib = ffi.DynamicLibrary.open(libPath);
        if (_verifyLibrary(lib)) {
          _dylib = lib;
          _initialized = true;
          debugPrint('Successfully loaded and verified library from project root');
          return;
        } else {
          debugPrint('Library verification failed for: $libPath');
        }
      } catch (e) {
        debugPrint('Failed to load from project root: $e');
      }
    } else {
      debugPrint('Library not found at: $libPath');
    }
    
    // Check environment variable path (set by Go launcher)
    final envLibPath = Platform.environment['FLUTTER_DYLIB_PATH'];
    if (envLibPath != null && File(envLibPath).existsSync()) {
      _searchPaths.add(envLibPath);
      try {
        debugPrint('Attempting to load library from environment path: $envLibPath');
        final lib = ffi.DynamicLibrary.open(envLibPath);
        if (_verifyLibrary(lib)) {
          _dylib = lib;
          _initialized = true;
          debugPrint('Successfully loaded and verified library from environment path');
          return;
        } else {
          debugPrint('Library verification failed for: $envLibPath');
        }
      } catch (e) {
        debugPrint('Failed to load from environment path: $e');
      }
    } else {
      debugPrint('Environment path not set or library not found');
    }
    
    // Try to find the library inside the app bundle
    if (Platform.isMacOS) {
      final appBundle = path.dirname(Platform.resolvedExecutable);
      
      // List of places to search
      final possibleLocations = [
        // Frameworks directory in macOS app bundle
        path.join(path.dirname(appBundle), 'Frameworks', libraryName),
        path.join(appBundle, '..', 'Frameworks', libraryName),
        
        // Current directory and up
        path.join(Directory.current.path, libraryName),
        path.join(Directory.current.path, '..', libraryName),
        path.join(Directory.current.path, '..', '..', libraryName),
        
        // App bundle directory
        path.join(appBundle, libraryName),
      ];
      
      for (final location in possibleLocations) {
        _searchPaths.add(location);
        if (File(location).existsSync()) {
          try {
            debugPrint('Attempting to load library from: $location');
            final lib = ffi.DynamicLibrary.open(location);
            if (_verifyLibrary(lib)) {
              _dylib = lib;
              _initialized = true;
              debugPrint('Successfully loaded and verified library from: $location');
              return;
            } else {
              debugPrint('Library verification failed for: $location');
            }
          } catch (e) {
            debugPrint('Failed to load from: $location');
          }
        } else {
          debugPrint('Library not found at: $location');
        }
      }
    }
    
    // If we get here, we failed to initialize
    _initialized = false;
    _dylib = null;
    throw Exception('Failed to load FFI library. The library could not be found or is inaccessible. Searched paths: ${_searchPaths.join(", ")}');
  }
} 