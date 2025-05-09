import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';

/// Interestnaut app theme - matches React/MUI styling
class AppTheme {
  // Core colors from App.css and theme.ts
  static const Color primaryColor = Color(0xFF7B68EE); // Medium slate blue
  static const Color primaryHover = Color(0xFF9370DB); // Medium purple
  static const Color accentColor = Color(0xFFA855F7); // Lighter purple
  static const Color spotifyGreen = Color(0xFF1DB954); // Spotify brand color
  static const Color spotifyGreenHover = Color(0xFF1ED760); // Spotify hover
  
  static const Color backgroundColor = Color(0xFF121212); // Very dark gray - exact MUI value
  static const Color surfaceColor = Color(0xFF282828); // Dark gray for cards
  static const Color surfaceHover = Color(0xFF383838); // Slightly lighter gray
  static const Color cardBackgroundColor = Color(0xFF282828); // Card background
  static const Color overlayColor = Color(0xAA000000); // rgba(0,0,0,0.67)
  
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFFB3B3B3); // Light gray
  
  static const Color errorColor = Color(0xFFFF4444); // Red
  static const Color purpleRed = Color(0xFFC23B85); // For errors/warnings
  static const Color purpleBlue = Color(0xFF6A5ACD); // For specific UI elements

  // Spacing values from App.css
  static const double spacingXS = 4;
  static const double spacingSM = 8;
  static const double spacingMD = 16;
  static const double spacingLG = 24;
  static const double spacingXL = 32;

  // Border radius
  static const double borderRadius = 8;
  static const double cardBorderRadius = 12;
  static const double buttonBorderRadius = 24; // Matching MUI's rounded buttons - increased to match screenshot

  /// Returns the main ThemeData for the app
  static ThemeData get theme {
    return ThemeData(
      // General theme colors
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
        onPrimary: textPrimary,
        onSecondary: textPrimary,
        onSurface: textPrimary,
        onBackground: textPrimary,
        onError: textPrimary,
        brightness: Brightness.dark,
      ),
      
      // Background colors
      scaffoldBackgroundColor: backgroundColor,
      dialogBackgroundColor: surfaceColor,
      canvasColor: backgroundColor,
      applyElevationOverlayColor: true,
      
      // Typography settings
      textTheme: _buildTextTheme(),
      
      // Card theme - updated to match MUI styling exactly
      cardTheme: CardTheme(
        color: surfaceColor,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardBorderRadius),
          side: BorderSide(color: const Color(0xFF323232), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        clipBehavior: Clip.antiAlias,
      ),
      
      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      
      // Button themes
      elevatedButtonTheme: _buildElevatedButtonTheme(),
      outlinedButtonTheme: _buildOutlinedButtonTheme(),
      textButtonTheme: _buildTextButtonTheme(),
      
      // Input decoration
      inputDecorationTheme: _buildInputDecorationTheme(),
      
      // Dialog theme
      dialogTheme: DialogTheme(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        elevation: 8,
      ),
      
      // Snackbar theme
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surfaceColor,
        contentTextStyle: TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        ),
      ),
      
      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return Colors.grey;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor.withOpacity(0.5);
          }
          return Colors.grey.withOpacity(0.5);
        }),
      ),
      
      // Divider theme
      dividerTheme: const DividerThemeData(
        color: surfaceHover,
        thickness: 1,
        space: 1,
      ),
      
      // Tab bar theme - updated to match MUI tab styling
      tabBarTheme: const TabBarTheme(
        labelColor: primaryColor,
        unselectedLabelColor: textSecondary,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: primaryColor, width: 3),
          insets: EdgeInsets.symmetric(horizontal: 16),
        ),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 16,
        ),
      ),
      
      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: surfaceHover,
        circularTrackColor: surfaceHover,
      ),
      
      // Use Material3 design
      useMaterial3: true,
    );
  }

  /// Build the text theme using system fonts instead of Google Fonts
  static TextTheme _buildTextTheme() {
    // Create a base text theme with system fonts
    const TextTheme baseTheme = TextTheme(
      bodyLarge: TextStyle(
        fontFamily: 'Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
        fontSize: 16,
        color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
        fontSize: 14,
        color: textPrimary,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
        fontSize: 12,
        color: textSecondary,
      ),
    );
    
    const TextStyle headingStyle = TextStyle(
      fontFamily: '-apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
      fontWeight: FontWeight.w600,
      color: textPrimary, 
      letterSpacing: -0.01,
    );
    
    return baseTheme.copyWith(
      // Display styles
      displayLarge: headingStyle.copyWith(fontSize: 57),
      displayMedium: headingStyle.copyWith(fontSize: 45),
      displaySmall: headingStyle.copyWith(fontSize: 36),
      
      // Headline styles
      headlineLarge: headingStyle.copyWith(fontSize: 32),
      headlineMedium: headingStyle.copyWith(fontSize: 28),
      headlineSmall: headingStyle.copyWith(fontSize: 24),
      
      // Title styles
      titleLarge: headingStyle.copyWith(fontSize: 22),
      titleMedium: headingStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: headingStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      
      // Label styles
      labelLarge: headingStyle.copyWith(fontSize: 14, letterSpacing: 0.1),
      labelMedium: headingStyle.copyWith(fontSize: 12, letterSpacing: 0.5),
      labelSmall: headingStyle.copyWith(fontSize: 11, letterSpacing: 0.5),
    );
  }

  /// Build elevated button theme to match MUI styling
  static ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: textPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: spacingLG, vertical: spacingMD),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonBorderRadius),
        ),
        textStyle: const TextStyle(
          fontFamily: '-apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
          fontWeight: FontWeight.w600,
          fontSize: 16,
          letterSpacing: 0.5,
        ),
        shadowColor: Colors.transparent,
        minimumSize: const Size(140, 45),
      ),
    );
  }

  /// Build outlined button theme to match MUI styling
  static OutlinedButtonThemeData _buildOutlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: const BorderSide(color: surfaceHover, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: spacingLG, vertical: spacingMD),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonBorderRadius),
        ),
        textStyle: const TextStyle(
          fontFamily: '-apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
        minimumSize: const Size(120, 40),
      ),
    );
  }

  /// Build text button theme to match MUI styling
  static TextButtonThemeData _buildTextButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: spacingMD, vertical: spacingSM),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        textStyle: const TextStyle(
          fontFamily: '-apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
          fontWeight: FontWeight.w600,
          fontSize: 16, // Increased to match MUI
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Build input decoration theme to match MUI styling
  static InputDecorationTheme _buildInputDecorationTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor: backgroundColor,
      hoverColor: surfaceHover,
      contentPadding: const EdgeInsets.symmetric(horizontal: spacingMD, vertical: spacingMD),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: surfaceHover),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: surfaceHover),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: primaryColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: errorColor),
      ),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textSecondary),
    );
  }
} 