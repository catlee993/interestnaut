import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'ffi_init.dart';
import 'ffi_bridge.dart';

/// Implementation of the Minstral GGUF FFI functionality
/// Handles downloading, checking, and using GGUF models
class MistralFFI {
  /// Singleton instance
  static final MistralFFI _instance = MistralFFI._();
  factory MistralFFI() => _instance;
  
  // Function pointers for the GGUF methods - eagerly initialized to prevent race conditions
  final ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>) _downloadModelPtr;
  final ffi.Pointer<ffi.Char> Function() _hasModelPtr;
  final ffi.Pointer<ffi.Char> Function() _handleNewSuggestionPtr;
  
  /// Private constructor that initializes the needed function pointers
  MistralFFI._() :
    _downloadModelPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>),
        ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)>('GGUF_DownloadModel'),
    _hasModelPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('GGUF_HasModel'),
    _handleNewSuggestionPtr = FFIInitializer.dylib.lookupFunction<
        ffi.Pointer<ffi.Char> Function(),
        ffi.Pointer<ffi.Char> Function()>('GGUF_HandleNewSuggestion') {
    debugPrint('MinstralFFI initialized with function pointers');
  }

  /// Download a GGUF model to the specified path
  /// 
  /// IMPORTANT: This is a synchronous, blocking operation that can take several minutes
  /// to complete since the model is ~4.6GB. Call this method from an isolate or background
  /// thread to avoid freezing the UI.
  /// 
  /// Returns a Map with status information after completion.
  Future<Map<String, dynamic>> downloadModel(String modelPath) async {
    FFIBindingBase.checkInitialized();
    
    // Use compute() or a separate isolate to call this in production
    debugPrint('Starting GGUF model download (4.6GB) - this will block until complete');
    
    // Convert the path to a native string - properly cast as Pointer<Char>
    final pathUtf8 = modelPath.toNativeUtf8();
    // Cast to Pointer<Char> since that's what the FFI function expects
    final pathPtr = pathUtf8.cast<ffi.Char>();
    
    try {
      final resultPtr = _downloadModelPtr(pathPtr);
      final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
      
      if (result == null) {
        debugPrint('Error: Failed to download model - null result');
        return {'status': 'error', 'error': 'Failed to download model'};
      }
      
      return result;
    } finally {
      // Clean up the allocated memory
      calloc.free(pathUtf8);
    }
  }
  
  /// Check if the GGUF model is available
  /// 
  /// Returns a Map with a boolean 'hasModel' key
  Future<Map<String, dynamic>> hasModel() async {
    FFIBindingBase.checkInitialized();
    final resultPtr = _hasModelPtr();
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      debugPrint('Error: Failed to check model availability - null result');
      return {'hasModel': false, 'error': 'Failed to check model'};
    }
    
    return result;
  }
  
  /// Handle a new suggestion request using the GGUF model
  /// 
  /// Returns a Map with title and artist for the suggestion
  Future<Map<String, dynamic>> handleNewSuggestion() async {
    FFIBindingBase.checkInitialized();
    final resultPtr = _handleNewSuggestionPtr();
    final result = FFIBindingBase.parseJSONFromPtr(resultPtr);
    
    if (result == null) {
      debugPrint('Error: Failed to handle new suggestion - null result');
      return {'error': 'Failed to generate suggestion'};
    }
    
    return result;
  }
}
