import 'dart:ffi';
import 'package:flutter/foundation.dart';
import 'ffi_bridge.dart' show FFIBindingBase, GoFFILibrary;
import 'ffi_init.dart';

// Import all FFI bindings
import 'music_ffi.dart';

/// GoBindings provides direct access to the Go backend functions
/// Similar to the Wails bindings in frontend/wailsjs/go/bindings
class GoBindings {
  static GoBindings? _instance;
  static bool _isInitialized = false;
  
  // Direct bindings to Go services
  late MusicBindings music;
  
  // Private constructor for singleton
  GoBindings._() {
    music = MusicBindings();
  }
  
  /// Returns the singleton instance
  static GoBindings get instance {
    if (_instance == null) {
      if (!FFIInitializer.isInitialized) {
        throw Exception("FFI not initialized. Call initialize() first.");
      }
      _instance = GoBindings._();
      _isInitialized = true;
    }
    
    // Double-check FFI is still valid
    if (!FFIInitializer.isInitialized) {
      _isInitialized = false;
      _instance = null;
      throw Exception("FFI library is no longer valid. Please reinitialize.");
    }
    
    return _instance!;
  }
  
  /// Initialize the bindings
  static Future<void> initialize() async {
    if (_isInitialized && _instance != null) {
      if (FFIInitializer.isInitialized) {
        debugPrint('GoBindings already initialized and FFI is valid, skipping');
        return;
      } else {
        debugPrint('GoBindings marked as initialized but FFI is invalid, reinitializing');
        _isInitialized = false;
        _instance = null;
      }
    }
    
    debugPrint('Initializing GoBindings...');
    
    if (!FFIInitializer.isInitialized) {
      debugPrint('FFI not initialized, initializing now...');
      await FFIInitializer.initialize();
      debugPrint('FFI initialized, FFI status: isInitialized=${FFIInitializer.isInitialized}');
    }
    
    if (!FFIInitializer.isInitialized) {
      throw Exception("FFI failed to initialize properly. Cannot create GoBindings.");
    }
    
    _instance = GoBindings._();
    _isInitialized = true;
    debugPrint('GoBindings initialized successfully');
  }
  
  /// Signal the Go app to shut down
  static void signalShutdown() {
    if (!FFIInitializer.isInitialized) {
      debugPrint('FFI not initialized, cannot signal shutdown');
      return;
    }
    
    try {
      final signalShutdown = GoFFILibrary.dylib
          .lookupFunction<Void Function(), void Function()>('SignalShutdown');
      signalShutdown();
      debugPrint('Signaled Go app to shut down');
    } catch (e) {
      debugPrint('Error signaling Go app shutdown: $e');
    }
  }
  
  /// Check if FFI is available
  static bool get ffiAvailable => FFIInitializer.isInitialized && _isInitialized;
}

/// MusicBindings provides direct access to the Go Music functions
/// Simplified to only include Spotify authentication, as all other
/// functionality is now handled via direct API calls in spotify_service.dart
class MusicBindings {
  final _ffi = MusicFFI();
  
  /// Ensure FFI is initialized before making a call
  Future<void> _ensureInitialized() async {
    if (!GoBindings.ffiAvailable) {
      debugPrint("FFI not initialized or valid in MusicBindings, attempting initialization...");
      
      // Log FFI status for diagnosis
      debugPrint('FFI status before init: ${FFIInitializer.isInitialized}');
      
      try {
        // First ensure FFI is initialized
        if (!FFIInitializer.isInitialized) {
          await FFIInitializer.initialize();
          debugPrint('FFI initialized successfully');
        }
        
        // Then ensure GoBindings is initialized
        await GoBindings.initialize();
        debugPrint('GoBindings initialized successfully');
        
        // Verify initialization was successful
        if (!GoBindings.ffiAvailable) {
          final paths = FFIInitializer.searchPaths.join(', ');
          throw Exception('FFI initialization completed but verification failed. Searched paths: $paths');
        }
        
        debugPrint('FFI and GoBindings successfully initialized');
      } catch (e) {
        debugPrint('Error during initialization: $e');
        throw Exception('Failed to initialize FFI: $e');
      }
    }
  }
  
  /// Explicitly initiate Spotify authentication
  /// This is the only FFI function retained in our streamlined architecture
  Future<void> initiateSpotifyAuth() async {
    try {
      debugPrint('Initiating Spotify auth in MusicBindings...');
      await _ensureInitialized();
      debugPrint('FFI initialized, calling _ffi.initiateSpotifyAuth()');
      // The Go function will now return immediately, and the auth status
      // will be communicated via the event bus
      await _ffi.initiateSpotifyAuth();
      debugPrint('Spotify auth initiated - waiting for event bus updates');
    } catch (e) {
      debugPrint('Error initiating Spotify auth: $e');
      debugPrint('FFI status: initialized=${FFIInitializer.isInitialized}');
      // Don't rethrow - the UI should be listening to the event bus for auth status
    }
  }
}