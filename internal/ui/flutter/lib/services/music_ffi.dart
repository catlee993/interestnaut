import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'ffi_init.dart';
import 'ffi_bridge.dart';

/// Implementation of the music-specific FFI functionality
class MusicFFI {
  /// Singleton instance
  static final MusicFFI _instance = MusicFFI._();
  factory MusicFFI() => _instance;
  
  // Eagerly initialize all function pointers in constructor to avoid race conditions
  final ffi.Pointer<ffi.Char> Function() _getAuthStatusPtr;
  final ffi.Pointer<ffi.Char> Function(int, int) _getSavedTracksPtr;
  final void Function(ffi.Pointer<Utf8>) _saveTrackPtr;
  final void Function(ffi.Pointer<Utf8>) _removeTrackPtr;
  final ffi.Pointer<ffi.Char> Function() _getCurrentUserPtr;
  final ffi.Pointer<ffi.Char> Function() _getMusicSuggestionPtr;
  final void Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, 
      ffi.Pointer<Utf8>, ffi.Pointer<Utf8>) _provideMusicFeedbackPtr;
  final ffi.Pointer<ffi.Char> Function() _getValidTokenPtr;
  final void Function() _clearSpotifyCredentialsPtr;
  final void Function() _initiateSpotifyAuthPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>, int) _searchTracksPtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>) _playTrackOnDevicePtr;
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>) _pausePlaybackOnDevicePtr;
  
  /// Private constructor that initializes all function pointers eagerly
  MusicFFI._() : 
    _getAuthStatusPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Music_GetAuthStatus'),
    _getSavedTracksPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Int32, ffi.Int32),
        ffi.Pointer<ffi.Char> Function(int, int)>('Music_GetSavedTracks'),
    _saveTrackPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Void Function(ffi.Pointer<Utf8>),
        void Function(ffi.Pointer<Utf8>)>('Music_SaveTrack'),
    _removeTrackPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Void Function(ffi.Pointer<Utf8>),
        void Function(ffi.Pointer<Utf8>)>('Music_RemoveTrack'),
    _getCurrentUserPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Music_GetCurrentUser'),
    _getMusicSuggestionPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Music_RequestNewSuggestion'),
    _provideMusicFeedbackPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Void Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, 
                         ffi.Pointer<Utf8>, ffi.Pointer<Utf8>),
        void Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>, 
                     ffi.Pointer<Utf8>, ffi.Pointer<Utf8>)>('Music_ProvideSuggestionFeedback'),
    _getValidTokenPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('Music_GetValidToken'),
    _clearSpotifyCredentialsPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Void Function(),
        void Function()>('Music_ClearSpotifyCredentials'),
    _initiateSpotifyAuthPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Void Function(),
        void Function()>('Music_InitiateSpotifyAuth'),
    _searchTracksPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>, ffi.Int32),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>, int)>('Music_SearchTracks'),
    _playTrackOnDevicePtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>)>('Music_PlayTrackOnDevice'),
    _pausePlaybackOnDevicePtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<Utf8>)>('Music_PausePlaybackOnDevice');
        
  /// Get authentication status with Spotify
  Future<Map<String, dynamic>> getAuthStatus() async {
    FFIBindingBase.checkInitialized();
    
    final resultPtr = _getAuthStatusPtr();
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return {'isAuthenticated': false, 'error': 'Failed to get auth status'};
    }
    
    return result;
  }
  
  /// Get user's saved tracks from Spotify
  Future<Map<String, dynamic>> getSavedTracks(int limit, int offset) async {
    FFIBindingBase.checkInitialized();
    
    // Pass Dart ints directly to the FFI function
    final resultPtr = _getSavedTracksPtr(limit, offset);
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return {'items': [], 'total': 0, 'error': 'Failed to get saved tracks'};
    }
    
    return result;
  }
  
  /// Save a track to the user's Spotify library
  Future<void> saveTrack(String trackId) async {
    FFIBindingBase.checkInitialized();
    
    final trackIdUtf8 = trackId.toNativeUtf8();
    _saveTrackPtr(trackIdUtf8);
    calloc.free(trackIdUtf8);
  }
  
  /// Remove a track from the user's Spotify library
  Future<void> removeTrack(String trackId) async {
    FFIBindingBase.checkInitialized();
    
    final trackIdUtf8 = trackId.toNativeUtf8();
    _removeTrackPtr(trackIdUtf8);
    calloc.free(trackIdUtf8);
  }
  
  /// Get the current Spotify user profile
  Future<Map<String, dynamic>> getCurrentUser() async {
    FFIBindingBase.checkInitialized();
    
    final resultPtr = _getCurrentUserPtr();
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return {'display_name': 'User', 'error': 'Failed to get current user'};
    }
    
    return result;
  }
  
  /// Get a music suggestion from the recommendation engine
  Future<Map<String, dynamic>> requestNewSuggestion() async {
    FFIBindingBase.checkInitialized();
    
    final resultPtr = _getMusicSuggestionPtr();
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return {
        'id': 'error',
        'title': 'Error',
        'overview': 'Could not get suggestion',
        'mediaType': 'music',
      };
    }
    
    return result;
  }
  
  /// Provide feedback for a music suggestion
  Future<void> provideSuggestionFeedback(String outcome, String title, String artist, String album) async {
    FFIBindingBase.checkInitialized();
    
    final outcomeUtf8 = outcome.toNativeUtf8();
    final titleUtf8 = title.toNativeUtf8();
    final artistUtf8 = artist.toNativeUtf8();
    final albumUtf8 = album.toNativeUtf8();
    
    _provideMusicFeedbackPtr(outcomeUtf8, titleUtf8, artistUtf8, albumUtf8);
    
    calloc.free(outcomeUtf8);
    calloc.free(titleUtf8);
    calloc.free(artistUtf8);
    calloc.free(albumUtf8);
  }
  
  /// Get a valid Spotify authorization token
  Future<String> getValidToken() async {
    FFIBindingBase.checkInitialized();
    
    final resultPtr = _getValidTokenPtr();
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null || result['token'] == null) {
      throw Exception('Failed to get valid token');
    }
    
    return result['token'];
  }
  
  /// Clear all Spotify credentials
  Future<void> clearSpotifyCredentials() async {
    FFIBindingBase.checkInitialized();
    _clearSpotifyCredentialsPtr();
  }
  
  /// Start the Spotify authentication process
  Future<void> initiateSpotifyAuth() async {
    FFIBindingBase.checkInitialized();
    _initiateSpotifyAuthPtr();
  }
  
  /// Search for tracks on Spotify
  Future<List<dynamic>> searchTracks(String query, int limit) async {
    FFIBindingBase.checkInitialized();
    
    final queryUtf8 = query.toNativeUtf8();
    // Pass Dart int directly to the FFI function
    final resultPtr = _searchTracksPtr(queryUtf8, limit);
    calloc.free(queryUtf8);
    
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      return [];
    }
    
    return result;
  }
  
  /// Play a track on a specific device
  Future<Map<String, dynamic>?> playTrackOnDevice(String deviceId, String trackUri) async {
    FFIBindingBase.checkInitialized();
    
    final deviceIdUtf8 = deviceId.toNativeUtf8();
    final trackUriUtf8 = trackUri.toNativeUtf8();
    
    final resultPtr = _playTrackOnDevicePtr(deviceIdUtf8, trackUriUtf8);
    
    calloc.free(deviceIdUtf8);
    calloc.free(trackUriUtf8);
    
    return FFIBindingBase.parseJSONFromPtr(resultPtr);
  }
  
  /// Pause playback on a specific device
  Future<Map<String, dynamic>?> pausePlaybackOnDevice(String deviceId) async {
    FFIBindingBase.checkInitialized();
    
    final deviceIdUtf8 = deviceId.toNativeUtf8();
    final resultPtr = _pausePlaybackOnDevicePtr(deviceIdUtf8);
    calloc.free(deviceIdUtf8);
    
    return FFIBindingBase.parseJSONFromPtr(resultPtr);
  }
  
  /// Play a track without specifying a device (let Spotify choose the active device)
  Future<Map<String, dynamic>?> playTrack(String trackUri) async {
    FFIBindingBase.checkInitialized();
    
    // For empty device ID, Spotify will use the current active device
    // This is handled by the Go code in musicBindings.PlayTrackOnDevice
    const String defaultDeviceId = ""; // empty string = use active device
    final deviceIdUtf8 = defaultDeviceId.toNativeUtf8();
    final trackUriUtf8 = trackUri.toNativeUtf8();
    
    final resultPtr = _playTrackOnDevicePtr(deviceIdUtf8, trackUriUtf8);
    
    calloc.free(deviceIdUtf8);
    calloc.free(trackUriUtf8);
    
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    if (result == null || result['error'] != null) {
      throw Exception(result?['error'] ?? 'Failed to play track');
    }
    
    return result;
  }
}
