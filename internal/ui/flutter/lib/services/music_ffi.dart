import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'ffi_init.dart';
import 'ffi_bridge.dart';

/// Implementation of the music-specific FFI functionality
/// Simplified to only include Spotify authentication which is the only
/// function that still requires the FFI bridge. All other functionality
/// is now handled through direct API calls in spotify_service.dart.
class MusicFFI {
  /// Singleton instance
  static final MusicFFI _instance = MusicFFI._();
  factory MusicFFI() => _instance;
  
  // Only initialize the function pointer we need
  final ffi.Pointer<ffi.Char> Function() _initiateSpotifyAuthPtr;
  
  /// Private constructor that initializes only the needed function pointer
  MusicFFI._() : 
    _initiateSpotifyAuthPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Music_InitiateSpotifyAuth');
  
  /// Start the Spotify authentication process
  Future<Map<String, dynamic>> initiateSpotifyAuth() async {
    FFIBindingBase.checkInitialized();
    final resultPtr = _initiateSpotifyAuthPtr();
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      debugPrint('Error: Failed to initiate Spotify authentication - null result');
      return {'isAuthenticated': false, 'error': 'Failed to initiate authentication'};
    }
    
    return result;
  }
}
