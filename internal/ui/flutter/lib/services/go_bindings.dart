import 'dart:ffi';
import 'package:flutter/foundation.dart';
import 'ffi_bridge.dart' show GoFFILibrary;
import 'ffi_init.dart';

// Only import the music FFI since it's the only one we're using now
import 'music_ffi.dart';

/// GoBindings provides direct access to the Go backend functions
class GoBindings {
  static GoBindings? _instance;
  static bool _isInitialized = false;
  
  // Only keep music bindings as it's the only one we need
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

/// MusicBindings provides direct access to the Spotify authentication function
class MusicBindings {
  final _ffi = MusicFFI();
  
  /// Initiate Spotify authentication using the Go FFI function
  Future<void> initiateSpotifyAuth({int port = 8080}) async {
    try {
      debugPrint('Initiating Spotify auth with port $port');
      
      // Ensure FFI is initialized
      if (!FFIInitializer.isInitialized) {
        await FFIInitializer.initialize();
      }
      
      await _ffi.initiateSpotifyAuth(port: port);
      debugPrint('Spotify auth initiated - waiting for event bus updates');
    } catch (e) {
      debugPrint('Error initiating Spotify auth: $e');
      // Don't rethrow - the UI should be listening to the event bus for auth status
    }
  }
}
