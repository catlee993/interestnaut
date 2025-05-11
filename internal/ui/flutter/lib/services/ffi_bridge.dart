import 'dart:convert';
import 'dart:ffi' as ffi;
import 'package:flutter/foundation.dart';
import 'package:ffi/ffi.dart';
import 'ffi_init.dart';

/// Base class for FFI bindings
class FFIBindingBase {
  /// Check if FFI is initialized
  static void checkInitialized() {
    if (!FFIInitializer.isInitialized) {
      throw Exception("FFI not initialized.");
    }
  }
  
  /// Free memory allocated by the Go side
  static void freeString(ffi.Pointer<ffi.Char> ptr) {
    var freeStringFn = FFIInitializer.dylib.lookupFunction<
        ffi.Void Function(ffi.Pointer<ffi.Char>),
        void Function(ffi.Pointer<ffi.Char>)>('FreeString');
    freeStringFn(ptr);
  }
  
  /// Parse JSON from string pointer, freeing memory afterwards
  static dynamic parseJSONFromPtr(ffi.Pointer<ffi.Char> ptr) {
    checkInitialized();
    
    var stringValue = ptr.cast<Utf8>().toDartString();
    freeString(ptr);
    
    if (stringValue.isEmpty) {
      return null;
    }
    
    try {
      return jsonDecode(stringValue);
    } catch (e) {
      debugPrint('Error parsing JSON: $e');
      debugPrint('Raw string: $stringValue');
      return null;
    }
  }
  
  /// Legacy alias for parseJSONFromPtr to maintain compatibility with existing code
  static dynamic parseJsonResponse(ffi.Pointer<ffi.Char> ptr) {
    return parseJSONFromPtr(ptr);
  }
  
  /// Check if the result contains an error and throw if it does
  static void checkForError(dynamic result) {
    if (result is Map && result.containsKey('error')) {
      var error = result['error'];
      if (error != null && error is String && error.isNotEmpty) {
        throw Exception(error);
      }
    }
  }
  
  /// Convert a Dart string to a C string
  static ffi.Pointer<ffi.Char> toCString(String string) {
    return string.toNativeUtf8().cast<ffi.Char>();
  }
  
  /// Check if initialized, for isolate compatibility
  static bool get isInitializedInIsolate => FFIInitializer.isInitialized;
}

/// To eliminate ambiguity between identical signatures
/// from different classes in FFI, we need a unified class
class GoFFILibrary {
  static ffi.DynamicLibrary get dylib => FFIInitializer.dylib;
}