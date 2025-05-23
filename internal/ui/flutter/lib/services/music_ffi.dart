import 'dart:ffi' as ffi;
import 'package:flutter/foundation.dart';
import 'ffi_init.dart';
import 'ffi_bridge.dart';
import 'package:ffi/ffi.dart';

/// Implementation of the music-specific FFI functionality
/// Simplified to only include Spotify authentication which is the only
/// function that remains in the Go FFI layer.
class MusicFFI extends FFIBindingBase {
  /// Singleton instance
  static final MusicFFI _instance = MusicFFI._();
  factory MusicFFI() => _instance;
  
  /// Private constructor
  MusicFFI._();
  
  /// Start the Spotify authentication process by opening a browser window
  /// This is a direct call to the Go FFI function Music_InitiateSpotifyAuth
  Future<Map<String, dynamic>> initiateSpotifyAuth({int port = 8080}) async {
    FFIBindingBase.checkInitialized();
    
    debugPrint('Calling Music_InitiateSpotifyAuth with port $port');
    
    try {
      // Use simpler approach aligned with project patterns
      final func = ffi.Pointer<
        ffi.NativeFunction<ffi.Pointer<ffi.Char> Function(ffi.Int32)>
      >.fromAddress(
        FFIInitializer.dylib.lookup<ffi.Void>('Music_InitiateSpotifyAuth').address
      ).asFunction<ffi.Pointer<ffi.Char> Function(int)>();
      
      final resultPtr = func(port);
      final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
      
      if (result == null) {
        debugPrint('Error: Failed to initiate Spotify authentication - null result');
        return {'status': 'error', 'error': 'Failed to initiate authentication'};
      }
      
      return result;
    } catch (e) {
      debugPrint('Error calling Music_InitiateSpotifyAuth: $e');
      return {'status': 'error', 'error': e.toString()};
    }
  }
}
