import 'dart:ffi';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'ffi_bridge.dart';
import 'ffi_init.dart';

/// The FFI bindings for Settings-related functions
class SettingsFFI extends FFIBindingBase {
  /// Singleton instance
  static final SettingsFFI _instance = SettingsFFI._();
  factory SettingsFFI() => _instance;
  
  // Function pointers for all Settings FFI functions
  Pointer<Char> Function()? _getSettings;
  Pointer<Char> Function(Pointer<Char>)? _updateSettings;
  Pointer<Char> Function()? _resetSettings;
  Pointer<Char> Function()? _getAvailableLanguages;
  Pointer<Char> Function(Pointer<Char>)? _setLanguage;
  Pointer<Char> Function()? _getAvailableThemes;
  Pointer<Char> Function(Pointer<Char>)? _setTheme;
  Pointer<Char> Function()? _getPrivacySettings;
  Pointer<Char> Function(Pointer<Char>)? _updatePrivacySettings;
  bool _initialized = false;
  
  // Private constructor - initialize all function pointers eagerly
  SettingsFFI._() {
    try {
      // Initialize all function pointers with try-catch for each one
      try {
        _getSettings = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(),
            Pointer<Char> Function()
          >('Settings_GetSettings');
        debugPrint('SettingsFFI: Successfully loaded Settings_GetSettings');
      } catch (e) {
        debugPrint('SettingsFFI: Error loading Settings_GetSettings: $e');
      }
      
      try {
        _updateSettings = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(Pointer<Char>),
            Pointer<Char> Function(Pointer<Char>)
          >('Settings_UpdateSettings');
        debugPrint('SettingsFFI: Successfully loaded Settings_UpdateSettings');
      } catch (e) {
        debugPrint('SettingsFFI: Error loading Settings_UpdateSettings: $e');
      }
      
      try {
        _resetSettings = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(),
            Pointer<Char> Function()
          >('Settings_ResetSettings');
        debugPrint('SettingsFFI: Successfully loaded Settings_ResetSettings');
      } catch (e) {
        debugPrint('SettingsFFI: Error loading Settings_ResetSettings: $e');
      }
      
      try {
        _getAvailableLanguages = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(),
            Pointer<Char> Function()
          >('Settings_GetAvailableLanguages');
        debugPrint('SettingsFFI: Successfully loaded Settings_GetAvailableLanguages');
      } catch (e) {
        debugPrint('SettingsFFI: Error loading Settings_GetAvailableLanguages: $e');
      }
      
      try {
        _setLanguage = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(Pointer<Char>),
            Pointer<Char> Function(Pointer<Char>)
          >('Settings_SetLanguage');
        debugPrint('SettingsFFI: Successfully loaded Settings_SetLanguage');
      } catch (e) {
        debugPrint('SettingsFFI: Error loading Settings_SetLanguage: $e');
      }
      
      try {
        _getAvailableThemes = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(),
            Pointer<Char> Function()
          >('Settings_GetAvailableThemes');
        debugPrint('SettingsFFI: Successfully loaded Settings_GetAvailableThemes');
      } catch (e) {
        debugPrint('SettingsFFI: Error loading Settings_GetAvailableThemes: $e');
      }
      
      try {
        _setTheme = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(Pointer<Char>),
            Pointer<Char> Function(Pointer<Char>)
          >('Settings_SetTheme');
        debugPrint('SettingsFFI: Successfully loaded Settings_SetTheme');
      } catch (e) {
        debugPrint('SettingsFFI: Error loading Settings_SetTheme: $e');
      }
      
      try {
        _getPrivacySettings = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(),
            Pointer<Char> Function()
          >('Settings_GetPrivacySettings');
        debugPrint('SettingsFFI: Successfully loaded Settings_GetPrivacySettings');
      } catch (e) {
        debugPrint('SettingsFFI: Error loading Settings_GetPrivacySettings: $e');
      }
      
      try {
        _updatePrivacySettings = GoFFILibrary.dylib
          .lookupFunction<
            Pointer<Char> Function(Pointer<Char>),
            Pointer<Char> Function(Pointer<Char>)
          >('Settings_UpdatePrivacySettings');
        debugPrint('SettingsFFI: Successfully loaded Settings_UpdatePrivacySettings');
      } catch (e) {
        debugPrint('SettingsFFI: Error loading Settings_UpdatePrivacySettings: $e');
      }
      
      // If we have at least the critical functions, consider SettingsFFI initialized
      // For now, check if we have at least the basic functions
      if (_getSettings != null || _updateSettings != null) {
        _initialized = true;
        debugPrint('SettingsFFI: Critical functions loaded, SettingsFFI is considered initialized');
      } else {
        debugPrint('SettingsFFI: Critical functions not loaded, SettingsFFI is NOT initialized');
      }
      
    } catch (e) {
      debugPrint('SettingsFFI: Error during initialization: $e');
      _initialized = false;
    }
  }
  
  /// Check if SettingsFFI was initialized correctly
  bool get isInitialized => _initialized;
  
  /// Verify the FFI is initialized
  void _verifyFFI() {
    // In the main isolate, check FFIInitializer.isInitialized
    // In other isolates, check if dylib is accessible
    if (!FFIInitializer.isInitialized && !FFIBindingBase.isInitializedInIsolate) {
      throw Exception("FFI library not initialized. Call initialize() first.");
    }
    
    if (!_initialized) {
      throw Exception("SettingsFFI is not properly initialized. Required functions may be missing.");
    }
  }
  
  /// Get all settings
  Future<Map<String, dynamic>> getSettings() async {
    _verifyFFI();
    
    if (_getSettings == null) {
      throw Exception("Settings_GetSettings function is not available");
    }
    
    final result = await compute(_computeGetSettings, null);
    return result;
  }
  
  /// Compute function to run in isolate
  static dynamic _computeGetSettings(Object? _) {
    final instance = SettingsFFI();
    instance._verifyFFI();
    if (instance._getSettings == null) {
      return {'error': 'Settings_GetSettings function is not available'};
    }
    final response = instance._getSettings!();
    return FFIBindingBase.parseJsonResponse(response);
  }
  
  /// Update settings
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    _verifyFFI();
    
    if (_updateSettings == null) {
      throw Exception("Settings_UpdateSettings function is not available");
    }
    
    await compute(_computeUpdateSettings, jsonEncode(settings));
  }
  
  /// Compute function to run in isolate
  static dynamic _computeUpdateSettings(String settingsJson) {
    final instance = SettingsFFI();
    instance._verifyFFI();
    if (instance._updateSettings == null) {
      return {'error': 'Settings_UpdateSettings function is not available'};
    }
    final settingsJsonPtr = FFIBindingBase.toCString(settingsJson);
    final response = instance._updateSettings!(settingsJsonPtr);
    return FFIBindingBase.parseJsonResponse(response);
  }
  
  /// Reset settings to default
  Future<void> resetSettings() async {
    _verifyFFI();
    
    if (_resetSettings == null) {
      throw Exception("Settings_ResetSettings function is not available");
    }
    
    await compute(_computeResetSettings, null);
  }
  
  /// Compute function to run in isolate
  static dynamic _computeResetSettings(Object? _) {
    final instance = SettingsFFI();
    instance._verifyFFI();
    if (instance._resetSettings == null) {
      return {'error': 'Settings_ResetSettings function is not available'};
    }
    final response = instance._resetSettings!();
    return FFIBindingBase.parseJsonResponse(response);
  }
  
  /// Get available languages
  Future<List<dynamic>> getAvailableLanguages() async {
    _verifyFFI();
    
    if (_getAvailableLanguages == null) {
      throw Exception("Settings_GetAvailableLanguages function is not available");
    }
    
    final result = await compute(_computeGetAvailableLanguages, null);
    FFIBindingBase.checkForError(result);
    if (result is List) {
      return result;
    } else {
      return [];
    }
  }
  
  /// Compute function to run in isolate
  static dynamic _computeGetAvailableLanguages(Object? _) {
    final instance = SettingsFFI();
    instance._verifyFFI();
    if (instance._getAvailableLanguages == null) {
      return {'error': 'Settings_GetAvailableLanguages function is not available'};
    }
    final response = instance._getAvailableLanguages!();
    return FFIBindingBase.parseJsonResponse(response);
  }
  
  /// Set the language
  Future<void> setLanguage(String languageCode) async {
    _verifyFFI();
    
    if (_setLanguage == null) {
      throw Exception("Settings_SetLanguage function is not available");
    }
    
    await compute(_computeSetLanguage, languageCode);
  }
  
  /// Compute function to run in isolate
  static dynamic _computeSetLanguage(String languageCode) {
    final instance = SettingsFFI();
    instance._verifyFFI();
    if (instance._setLanguage == null) {
      return {'error': 'Settings_SetLanguage function is not available'};
    }
    final languageCodePtr = FFIBindingBase.toCString(languageCode);
    final response = instance._setLanguage!(languageCodePtr);
    return FFIBindingBase.parseJsonResponse(response);
  }
  
  /// Get available themes
  Future<List<dynamic>> getAvailableThemes() async {
    _verifyFFI();
    
    if (_getAvailableThemes == null) {
      throw Exception("Settings_GetAvailableThemes function is not available");
    }
    
    final result = await compute(_computeGetAvailableThemes, null);
    FFIBindingBase.checkForError(result);
    if (result is List) {
      return result;
    } else {
      return [];
    }
  }
  
  /// Compute function to run in isolate
  static dynamic _computeGetAvailableThemes(Object? _) {
    final instance = SettingsFFI();
    instance._verifyFFI();
    if (instance._getAvailableThemes == null) {
      return {'error': 'Settings_GetAvailableThemes function is not available'};
    }
    final response = instance._getAvailableThemes!();
    return FFIBindingBase.parseJsonResponse(response);
  }
  
  /// Set the theme
  Future<void> setTheme(String themeName) async {
    _verifyFFI();
    
    if (_setTheme == null) {
      throw Exception("Settings_SetTheme function is not available");
    }
    
    await compute(_computeSetTheme, themeName);
  }
  
  /// Compute function to run in isolate
  static dynamic _computeSetTheme(String themeName) {
    final instance = SettingsFFI();
    instance._verifyFFI();
    if (instance._setTheme == null) {
      return {'error': 'Settings_SetTheme function is not available'};
    }
    final themeNamePtr = FFIBindingBase.toCString(themeName);
    final response = instance._setTheme!(themeNamePtr);
    return FFIBindingBase.parseJsonResponse(response);
  }
  
  /// Get privacy settings
  Future<Map<String, dynamic>> getPrivacySettings() async {
    _verifyFFI();
    
    if (_getPrivacySettings == null) {
      throw Exception("Settings_GetPrivacySettings function is not available");
    }
    
    final result = await compute(_computeGetPrivacySettings, null);
    return result;
  }
  
  /// Compute function to run in isolate
  static dynamic _computeGetPrivacySettings(Object? _) {
    final instance = SettingsFFI();
    instance._verifyFFI();
    if (instance._getPrivacySettings == null) {
      return {'error': 'Settings_GetPrivacySettings function is not available'};
    }
    final response = instance._getPrivacySettings!();
    return FFIBindingBase.parseJsonResponse(response);
  }
  
  /// Update privacy settings
  Future<void> updatePrivacySettings(Map<String, dynamic> privacySettings) async {
    _verifyFFI();
    
    if (_updatePrivacySettings == null) {
      throw Exception("Settings_UpdatePrivacySettings function is not available");
    }
    
    await compute(_computeUpdatePrivacySettings, jsonEncode(privacySettings));
  }
  
  /// Compute function to run in isolate
  static dynamic _computeUpdatePrivacySettings(String privacySettingsJson) {
    final instance = SettingsFFI();
    instance._verifyFFI();
    if (instance._updatePrivacySettings == null) {
      return {'error': 'Settings_UpdatePrivacySettings function is not available'};
    }
    final privacySettingsJsonPtr = FFIBindingBase.toCString(privacySettingsJson);
    final response = instance._updatePrivacySettings!(privacySettingsJsonPtr);
    return FFIBindingBase.parseJsonResponse(response);
  }
}
