import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';

import 'ffi_bridge.dart'; // Provides FFIBindingBase, parseJSONFromPtr, toCString, etc.
import 'ffi_init.dart';   // Provides FFIInitializer.dylib

// Specific FFI function type definitions
typedef _FindAndSaveSuggestionNative = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> rawQuery, ffi.Pointer<Utf8> mediaType, ffi.Pointer<Utf8> botReasoning);
typedef _FindAndSaveSuggestionDart = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> rawQuery, ffi.Pointer<Utf8> mediaType, ffi.Pointer<Utf8> botReasoning);

typedef _GetAllSuggestionsNative = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> mediaType, ffi.Pointer<Utf8> statusFilter, ffi.Int32 limit, ffi.Int32 offset);
typedef _GetAllSuggestionsDart = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> mediaType, ffi.Pointer<Utf8> statusFilter, int limit, int offset);

typedef _UpdateSuggestionStatusNative = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> suggestionID, ffi.Pointer<Utf8> status);
typedef _UpdateSuggestionStatusDart = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> suggestionID, ffi.Pointer<Utf8> status);

typedef _GetPendingSuggestionsCountNative = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> mediaType);
typedef _GetPendingSuggestionsCountDart = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8> mediaType);

class RecommendationFFI extends FFIBindingBase {
  // FFI Function Lookups
  late final _FindAndSaveSuggestionDart _findAndSaveSuggestion;
  late final _GetAllSuggestionsDart _getAllSuggestions;
  late final _UpdateSuggestionStatusDart _updateSuggestionStatus;
  late final _GetPendingSuggestionsCountDart _getPendingSuggestionsCount;

  RecommendationFFI() {
    FFIBindingBase.checkInitialized(); // Ensure FFI is up

    _findAndSaveSuggestion = FFIInitializer.dylib
        .lookup<ffi.NativeFunction<_FindAndSaveSuggestionNative>>('Recommendation_FindAndSaveSuggestion')
        .asFunction<_FindAndSaveSuggestionDart>();

    _getAllSuggestions = FFIInitializer.dylib
        .lookup<ffi.NativeFunction<_GetAllSuggestionsNative>>('Recommendation_GetAllSuggestions')
        .asFunction<_GetAllSuggestionsDart>();

    _updateSuggestionStatus = FFIInitializer.dylib
        .lookup<ffi.NativeFunction<_UpdateSuggestionStatusNative>>('Recommendation_UpdateSuggestionStatus')
        .asFunction<_UpdateSuggestionStatusDart>();

    _getPendingSuggestionsCount = FFIInitializer.dylib
        .lookup<ffi.NativeFunction<_GetPendingSuggestionsCountNative>>('Recommendation_GetPendingSuggestionsCount')
        .asFunction<_GetPendingSuggestionsCountDart>();
  }

  // --- Raw FFI call wrappers ---
  // These methods handle the Pointer<Utf8> conversions and call the Go functions.
  // They return the raw JSON string pointer, which will be parsed by the calling XxxBindings class.

  Future<Map<String, dynamic>> findAndSaveSuggestion(String rawQuery, String mediaType, String botReasoning) async {
    final rawQueryPtr = rawQuery.toNativeUtf8();
    final mediaTypePtr = mediaType.toNativeUtf8();
    final botReasoningPtr = botReasoning.toNativeUtf8();

    try {
      final resultPtr = _findAndSaveSuggestion(rawQueryPtr, mediaTypePtr, botReasoningPtr);
      return FFIBindingBase.parseJSONFromPtr(resultPtr.cast<ffi.Char>()) as Map<String, dynamic>;
    } finally {
      calloc.free(rawQueryPtr);
      calloc.free(mediaTypePtr);
      calloc.free(botReasoningPtr);
    }
  }

  Future<List<dynamic>> getAllSuggestions(String mediaType, String statusFilter, int limit, int offset) async {
    final mediaTypePtr = mediaType.toNativeUtf8();
    final statusFilterPtr = statusFilter.toNativeUtf8(); // Empty string for no filter

    try {
      final resultPtr = _getAllSuggestions(mediaTypePtr, statusFilterPtr, limit, offset);
      final result = FFIBindingBase.parseJSONFromPtr(resultPtr.cast<ffi.Char>());
      if (result is List) {
        return result;
      } else if (result is Map && result.containsKey('error')) {
         throw Exception('Go Error: ${result['error']}');
      } else if (result == null) {
        return [];
      }
      throw Exception('Expected list from Go, got: ${result.runtimeType}');
    } finally {
      calloc.free(mediaTypePtr);
      calloc.free(statusFilterPtr);
    }
  }

  Future<Map<String, dynamic>> updateSuggestionStatus(String suggestionID, String status) async {
    final suggestionIDPtr = suggestionID.toNativeUtf8();
    final statusPtr = status.toNativeUtf8();

    try {
      final resultPtr = _updateSuggestionStatus(suggestionIDPtr, statusPtr);
      return FFIBindingBase.parseJSONFromPtr(resultPtr.cast<ffi.Char>()) as Map<String, dynamic>;
    } finally {
      calloc.free(suggestionIDPtr);
      calloc.free(statusPtr);
    }
  }

  Future<Map<String, dynamic>> getPendingSuggestionsCount(String mediaType) async {
    final mediaTypePtr = mediaType.toNativeUtf8();
    try {
      final resultPtr = _getPendingSuggestionsCount(mediaTypePtr);
      return FFIBindingBase.parseJSONFromPtr(resultPtr.cast<ffi.Char>()) as Map<String, dynamic>;
    } finally {
      calloc.free(mediaTypePtr);
    }
  }
}
