import 'package:flutter/material.dart';

/// Centralized font definitions for the Interestnaut app
/// This ensures consistent typography with personality throughout the app
/// Prioritizes thin, wide, sleek fonts matching existing theme transformations
class InterestFonts {
  // Base font settings for the "interestnautty" aesthetic - thin, wide, sleek
  static const String _primaryFontFamily = 'Inter'; // Matching existing theme
  static const String _fullFontFamily = 'Inter, Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif';
  static const double _wideLetterSpacing = 3.0; // For headers and transformed text
  static const double _mediumLetterSpacing = 1.5; // For titles and prominent text
  static const double _baseLetterSpacing = 0.8; // For regular text
  static const double _subtleLetterSpacing = 0.4; // For body text
  
  // === TRANSFORMATION SCALING CONSTANTS ===
  // Matching the existing theme.dart transformation approach
  static const double suggestionHeaderScaleX = 1.15;
  static const double libraryHeaderScaleX = 1.25;
  static const double suggestionHeaderLetterSpacing = 1.10;
  static const double libraryHeaderLetterSpacing = 1.0;
  
  // Color definitions for text
  static const Color primaryTextColor = Colors.white;
  static final Color secondaryTextColor = Colors.white.withOpacity(0.75);
  static final Color tertiaryTextColor = Colors.white.withOpacity(0.6);
  static final Color mutedTextColor = Colors.white.withOpacity(0.5);

  /// Large display text - for main headings and hero text (thin, wide, sleek)
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w200, // Ultra thin for sleek look
    letterSpacing: _wideLetterSpacing * 1.2, // Extra wide for drama
    height: 1.1,
    color: primaryTextColor,
  );

  /// Medium display text - for section headers (thin, wide, sleek)
  static const TextStyle displayMedium = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w200, // Ultra thin
    letterSpacing: _wideLetterSpacing,
    height: 1.2,
    color: primaryTextColor,
  );

  /// Small display text - for subsection headers (thin, wide, sleek)
  static const TextStyle displaySmall = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w300, // Still thin but slightly bolder for readability
    letterSpacing: _mediumLetterSpacing,
    height: 1.3,
    color: primaryTextColor,
  );

  /// Headline text - for card titles and prominent labels (sleek)
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w300, // Thin but readable
    letterSpacing: _mediumLetterSpacing,
    height: 1.3,
    color: primaryTextColor,
  );

  /// Medium headline - for secondary titles (sleek)
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w300,
    letterSpacing: _baseLetterSpacing,
    height: 1.3,
    color: primaryTextColor,
  );

  /// Small headline - for tertiary titles (sleek)
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400, // Slightly bolder for small sizes
    letterSpacing: _baseLetterSpacing,
    height: 1.4,
    color: primaryTextColor,
  );

  /// Title text - for search card titles and media names (sleek)
  static const TextStyle titleLarge = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400, // Balanced for readability
    letterSpacing: _baseLetterSpacing,
    height: 1.2,
    color: primaryTextColor,
  );

  /// Medium title - for card titles (sleek)
  static const TextStyle titleMedium = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: _baseLetterSpacing,
    height: 1.3,
    color: primaryTextColor,
  );

  /// Small title - for compact titles (sleek)
  static const TextStyle titleSmall = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500, // Slightly bolder for small text
    letterSpacing: _baseLetterSpacing,
    height: 1.2,
    color: primaryTextColor,
  );

  /// Body text - for descriptions and content
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.4,
    color: primaryTextColor,
  );

  /// Medium body text - for secondary content
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.4,
    color: primaryTextColor,
  );

  /// Small body text - for captions and metadata
  static const TextStyle bodySmall = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.05,
    height: 1.3,
    color: primaryTextColor,
  );

  /// Label text - for artists, creators, and secondary info
  static TextStyle labelLarge = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: _subtleLetterSpacing,
    height: 1.3,
    color: secondaryTextColor,
  );

  /// Medium label - for secondary labels
  static TextStyle labelMedium = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: _subtleLetterSpacing,
    height: 1.2,
    color: secondaryTextColor,
  );

  /// Small label - for compact secondary info
  static TextStyle labelSmall = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: _subtleLetterSpacing,
    height: 1.2,
    color: secondaryTextColor,
  );

  /// Caption text - for timestamps, counts, and minimal info
  static TextStyle captionLarge = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.3,
    color: tertiaryTextColor,
  );

  /// Small caption - for very minimal info
  static TextStyle captionSmall = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.05,
    height: 1.2,
    color: tertiaryTextColor,
  );

  /// Button text - for interactive elements
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    height: 1.2,
    color: primaryTextColor,
  );

  /// Medium button text
  static const TextStyle buttonMedium = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: _baseLetterSpacing,
    height: 1.2,
    color: primaryTextColor,
  );

  /// Small button text
  static const TextStyle buttonSmall = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: _subtleLetterSpacing,
    height: 1.1,
    color: primaryTextColor,
  );

  // Specialized styles for specific use cases

  /// Search card title - optimized for search result cards
  static const TextStyle searchCardTitle = titleSmall;

  /// Search card artist - optimized for search result cards
  static TextStyle searchCardArtist = labelSmall;

  /// Media drawer title - for media detail drawer headers
  static const TextStyle mediaDrawerTitle = headlineLarge;

  /// Media drawer subtitle - for artist/creator in drawer
  static TextStyle mediaDrawerSubtitle = labelLarge;

  /// Settings label - for settings section headers
  static const TextStyle settingsLabel = headlineSmall;

  /// Tab label - for tab navigation
  static const TextStyle tabLabel = buttonMedium;

  /// Notification text - for status messages
  static const TextStyle notification = bodyMedium;

  /// History item title - for media history entries
  static const TextStyle historyTitle = titleMedium;

  /// History item subtitle - for artist/creator in history
  static TextStyle historySubtitle = labelMedium;

  /// Utility methods for creating custom variations

  /// Create a custom text style with different color
  static TextStyle withColor(TextStyle baseStyle, Color color) {
    return baseStyle.copyWith(color: color);
  }

  /// Create a custom text style with different opacity
  static TextStyle withOpacity(TextStyle baseStyle, double opacity) {
    return baseStyle.copyWith(color: baseStyle.color?.withOpacity(opacity));
  }

  /// Create a custom text style with different size
  static TextStyle withSize(TextStyle baseStyle, double fontSize) {
    return baseStyle.copyWith(fontSize: fontSize);
  }

  /// Create a custom text style with different weight
  static TextStyle withWeight(TextStyle baseStyle, FontWeight weight) {
    return baseStyle.copyWith(fontWeight: weight);
  }
  
  // === TRANSFORMED HEADER STYLES ===
  // Matching the existing theme.dart approach with Matrix transformations
  
  /// Suggestion header styles with configurable letter spacing
  static TextStyle get suggestionHeaderLarge => TextStyle(
    fontFamily: _primaryFontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 24,
    letterSpacing: 3.0 * suggestionHeaderLetterSpacing,
    color: primaryTextColor,
  );
  
  static TextStyle get suggestionHeaderMedium => TextStyle(
    fontFamily: _primaryFontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 20,
    letterSpacing: 2.5 * suggestionHeaderLetterSpacing,
    color: primaryTextColor,
  );
  
  static TextStyle get suggestionHeaderSmall => TextStyle(
    fontFamily: _primaryFontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 18,
    letterSpacing: 2.25 * suggestionHeaderLetterSpacing,
    color: primaryTextColor,
  );
  
  /// Library header styles with configurable letter spacing
  static TextStyle get libraryHeaderLarge => TextStyle(
    fontFamily: _primaryFontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 24,
    letterSpacing: 3.0 * libraryHeaderLetterSpacing,
    color: primaryTextColor,
  );
  
  static TextStyle get libraryHeaderMedium => TextStyle(
    fontFamily: _primaryFontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 20,
    letterSpacing: 2.5 * libraryHeaderLetterSpacing,
    color: primaryTextColor,
  );
  
  static TextStyle get libraryHeaderSmall => TextStyle(
    fontFamily: _primaryFontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 18,
    letterSpacing: 2.25 * libraryHeaderLetterSpacing,
    color: primaryTextColor,
  );
  
  static TextStyle get libraryHeaderStyle => TextStyle(
    fontFamily: _primaryFontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 18,
    letterSpacing: 2.3 * libraryHeaderLetterSpacing,
    color: primaryTextColor,
  );
  
  // === TRANSFORMED HEADER WIDGETS ===
  // Create widgets with Matrix transformations like the existing theme
  
  /// Create a suggestion header (SUGGESTED, etc.) with proper scaling
  static Widget themedSuggestionHeader(String text, {Color? color}) {
    return Transform(
      transform: Matrix4.identity()..scale(suggestionHeaderScaleX, 1.0),
      alignment: Alignment.center,
      child: Text(
        text,
        style: suggestionHeaderLarge.copyWith(color: color),
        textAlign: TextAlign.center,
      ),
    );
  }
  
  /// Create a library/watchlist header with proper scaling
  static Widget themedLibraryHeader(String text, {Color? color}) {
    return Transform(
      transform: Matrix4.identity()..scale(libraryHeaderScaleX, 1.0),
      alignment: Alignment.center,
      child: Text(
        text,
        style: libraryHeaderMedium.copyWith(color: color),
        textAlign: TextAlign.center,
      ),
    );
  }
  
  /// Create a search results header with library scaling
  static Widget themedSearchResultsHeader(String text, {Color? color}) {
    return Transform(
      transform: Matrix4.identity()..scale(libraryHeaderScaleX, 1.0),
      alignment: Alignment.center,
      child: Text(
        text,
        style: headlineLarge.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
  
  // === SUGGESTION CONTENT STYLES ===
  // Styles for media content cards to match the thin, wide aesthetic
  
  static const TextStyle mediaTitleStyle = TextStyle(
    fontFamily: _primaryFontFamily,
    fontWeight: FontWeight.w300,
    fontSize: 24,
    letterSpacing: 2.0,
    height: 1.3,
    color: primaryTextColor,
  );
  
  static const TextStyle mediaArtistStyle = TextStyle(
    fontFamily: _primaryFontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 15,
    letterSpacing: 1.4,
    height: 1.4,
    color: primaryTextColor,
  );
  
  static const TextStyle mediaDescriptionStyle = TextStyle(
    fontFamily: _primaryFontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 14,
    letterSpacing: 1.0,
    height: 1.6,
    color: primaryTextColor,
  );
  
  static const TextStyle botReasoningStyle = TextStyle(
    fontFamily: _primaryFontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 14,
    letterSpacing: 0.8,
    height: 1.6,
    color: primaryTextColor,
  );
  
  static const TextStyle reasoningHeaderStyle = TextStyle(
    fontFamily: _primaryFontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    letterSpacing: 1.2,
    color: primaryTextColor,
  );
  
  // === BUTTON STYLES ===
  // Suggestion button style matching the thin, wide aesthetic
  
  static TextStyle get suggestionButtonTextStyle => TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 12,
    letterSpacing: 2.0,
    fontWeight: FontWeight.w200,
    color: primaryTextColor,
  );
}