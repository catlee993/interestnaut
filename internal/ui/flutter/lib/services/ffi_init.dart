import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

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
      library.lookup<
        ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Char>)>
      >('FreeString');
      
      // If we get here, the lookup succeeded
      return true;
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

    try {
      final List<String> possibleNames = [
        // macOS
        'libinterestnaut.dylib',
        // Linux
        'libinterestnaut.so',
        // Windows
        'interestnaut.dll',
      ];
      
      // Select the appropriate library name based on platform
      String libraryName;
      if (Platform.isMacOS) {
        libraryName = possibleNames[0]; // macOS
      } else if (Platform.isLinux) {
        libraryName = possibleNames[1]; // Linux
      } else if (Platform.isWindows) {
        libraryName = possibleNames[2]; // Windows
      } else {
        throw Exception("Unsupported platform: ${Platform.operatingSystem}");
      }
      
      // Try to find the library in app's temporary directory which should be accessible
      if (Platform.isMacOS) {
        try {
          // Get the application's temp directory which should be accessible in the sandbox
          final appExecDir = path.dirname(Platform.resolvedExecutable);
          final appBundleDir = path.dirname(appExecDir); // Go up one level from MacOS dir
          final frameworksDir = path.join(appBundleDir, 'Frameworks');
          
          // Create Frameworks directory if it doesn't exist
          final frameworksDirEntity = Directory(frameworksDir);
          if (!await frameworksDirEntity.exists()) {
            await frameworksDirEntity.create(recursive: true);
            debugPrint('Created Frameworks directory: $frameworksDir');
          }
          
          // Path for the dylib in the Frameworks directory
          final targetDylibPath = path.join(frameworksDir, libraryName);
          
          // Check if we need to copy the dylib
          final targetFile = File(targetDylibPath);
          if (!await targetFile.exists()) {
            // Source dylib path
            const sourceDylibPath = '/Users/catastrophe/stuff/interestnaut/internal/ui/flutter/libinterestnaut.dylib';
            final sourceFile = File(sourceDylibPath);
            
            if (await sourceFile.exists()) {
              debugPrint('Copying dylib from: $sourceDylibPath to: $targetDylibPath');
              
              // Copy the file
              try {
                await sourceFile.copy(targetDylibPath);
                
                // Set execute permissions
                await Process.run('chmod', ['+x', targetDylibPath]);
                
                debugPrint('Successfully copied dylib to Frameworks directory');
              } catch (e) {
                debugPrint('Error copying dylib: $e');
              }
            } else {
              debugPrint('Source dylib not found at: $sourceDylibPath');
            }
          } else {
            debugPrint('Dylib already exists in Frameworks directory: $targetDylibPath');
          }
          
          // Now try to load the dylib from the Frameworks directory
          if (await targetFile.exists()) {
            try {
              debugPrint('Attempting to load library from Frameworks directory: $targetDylibPath');
              final lib = ffi.DynamicLibrary.open(targetDylibPath);
              
              if (_verifyLibrary(lib)) {
                _dylib = lib;
                _initialized = true;
                debugPrint('Successfully loaded and verified library from Frameworks directory');
                return;
              } else {
                debugPrint('Library verification failed for Framework directory copy');
              }
            } catch (e) {
              debugPrint('Failed to load from Frameworks directory: $e');
            }
          }
        } catch (e) {
          debugPrint('Error during Frameworks directory setup: $e');
        }
      }
      
      // Try the following paths
      final pathsToTry = <String>[];
      
      if (Platform.isMacOS) {
        final appBundle = path.dirname(Platform.resolvedExecutable);
        
        // Add all potential paths
        pathsToTry.addAll([
          // Frameworks directory in macOS app bundle
          path.join(path.dirname(appBundle), 'Frameworks', libraryName),
          path.join(appBundle, '..', 'Frameworks', libraryName),
          
          // App bundle directory
          path.join(appBundle, libraryName),
          
          // Current directory
          path.join(Directory.current.path, libraryName),
          
          // Original location
          '/Users/catastrophe/stuff/interestnaut/internal/ui/flutter/libinterestnaut.dylib',
        ]);
      }
      
      for (final location in pathsToTry) {
        _searchPaths.add(location);
        debugPrint('Checking location: $location');
        
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
            debugPrint('Failed to load from: $location: $e');
          }
        } else {
          debugPrint('Library not found at: $location');
        }
      }
      
      // If we get here, we failed to initialize
      _initialized = false;
      _dylib = null;
      throw Exception('Failed to load FFI library. The library could not be found or is inaccessible due to sandbox restrictions. Check the debug logs for more details.');
    } catch (e) {
      debugPrint('Error initializing FFI bindings: $e');
      rethrow;
    }
  }
}