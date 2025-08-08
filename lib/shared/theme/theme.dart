import 'package:flutter/material.dart';
import '../models/media_type_config.dart';
import '../media_type.dart';

/// Interestnaut app theme - all values are easily editable here
class AppTheme {
  // === EDITABLE COLORS ===
  static const Color primaryColor = Color(0xFF7B68EE); // Medium slate blue
  static const Color primaryHover = Color(0xFF9370DB); // Medium purple
  static const Color accentColor = Color(0xFFA855F7); // Lighter purple
  static const Color spotifyGreen = Color(0xFF1DB954); // Spotify brand color
  static const Color spotifyGreenHover = Color(0xFF1ED760); // Spotify hover
  
  static const Color backgroundColor = Color(0xFF121212); // Very dark gray
  static const Color surfaceColor = Color(0xFF282828); // Dark gray for cards
  static const Color surfaceHover = Color(0xFF383838); // Slightly lighter gray
  static const Color cardBackgroundColor = Color(0xFF282828); // Card background
  static const Color overlayColor = Color(0xAA000000); // rgba(0,0,0,0.67)
  
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFFB3B3B3); // Light gray
  static const Color textTertiary = Color(0xFF808080); // Medium gray
  
  // === NEW THEME COLORS ===
  // Replacing red/green with turquoise/violet purple scheme
  static const Color positiveColor = Color(0xFF4DD0E1); // Turquoise - for positive actions
  static const Color negativeColor = Color(0xFFC23B85); // Violet purple - for negative actions (based on Spotify clear auth)
  static const Color neutralColor = Color(0xFF9E9E9E); // Neutral gray
  
  // Legacy color definitions for backward compatibility
  static const Color errorColor = negativeColor; // Use new negative color
  static const Color warningColor = Color(0xFFFFAA00); // Orange
  static const Color successColor = positiveColor; // Use new positive color
  static const Color infoColor = Color(0xFF4A9EFF); // Bluer color to match reasoning section
  static const Color purpleRed = negativeColor; // Legacy name pointing to new negative color
  static const Color purpleBlue = Color(0xFF6A5ACD); // For specific UI elements - legacy compatibility
  
  // === ACTION BUTTON COLORS ===
  // Updated to use new theme colors
  static const Color likeColor = positiveColor; // Turquoise for like actions
  static const Color dislikeColor = negativeColor; // Violet purple for dislike actions
  static const Color favoriteColor = primaryColor; // Purple for favorite actions
  static const Color watchlistColor = infoColor; // Blue for watchlist/playlist actions
  static const Color skipColor = neutralColor; // Neutral gray for skip actions
  
  // === MATCHING COLORS ===
  // For include/exclude matching in settings
  static const Color includeColor = positiveColor; // Turquoise for include/positive matching
  static const Color excludeColor = negativeColor; // Violet purple for exclude/negative matching
  
  // === MEDIA TYPE CONFIGURATION ===
  // Centralized configuration for all media types - single source of truth
  
  // Configuration class for media types
  static const Map<String, MediaTypeConfig> mediaTypes = {
    'music': MediaTypeConfig(
      displayName: 'Music',
      pluralDisplayName: 'Music',
      icon: Icons.music_note,
      fallbackIcon: Icons.music_note,
      listName: 'Playlist',
      listActionName: 'playlist',
      searchPlaceholder: 'Search tracks...',
      estimatedDbSize: '928 MB',
      headerDisplayName: 'MUSIC',
    ),
    'movie': MediaTypeConfig(
      displayName: 'Movie',
      pluralDisplayName: 'Movies', 
      icon: Icons.movie,
      fallbackIcon: Icons.movie,
      listName: 'Watchlist',
      listActionName: 'watchlist',
      searchPlaceholder: 'Search movies...',
      estimatedDbSize: '440 MB',
      headerDisplayName: 'MOVIES',
    ),
    'tv_show': MediaTypeConfig(
      displayName: 'TV Show',
      pluralDisplayName: 'TV Shows',
      icon: Icons.tv,
      fallbackIcon: Icons.tv,
      listName: 'Watchlist', 
      listActionName: 'watchlist',
      searchPlaceholder: 'Search TV shows...',
      estimatedDbSize: '238 MB',
      headerDisplayName: 'SHOWS',
    ),
    'book': MediaTypeConfig(
      displayName: 'Book',
      pluralDisplayName: 'Books',
      icon: Icons.book,
      fallbackIcon: Icons.menu_book,
      listName: 'Reading List',
      listActionName: 'reading list',
      searchPlaceholder: 'Search books...',
      estimatedDbSize: '191 MB',
      headerDisplayName: 'BOOKS',
    ),
    'video_game': MediaTypeConfig(
      displayName: 'Video Game',
      pluralDisplayName: 'Video Games',
      icon: Icons.videogame_asset,
      fallbackIcon: Icons.sports_esports,
      listName: 'Playlist',
      listActionName: 'playlist',
      searchPlaceholder: 'Search games...',
      estimatedDbSize: '84 MB',
      headerDisplayName: 'GAMES',
    ),
    // Legacy aliases for compatibility
    'game': MediaTypeConfig(
      displayName: 'Game',
      pluralDisplayName: 'Games',
      icon: Icons.videogame_asset,
      fallbackIcon: Icons.sports_esports,
      listName: 'Playlist',
      listActionName: 'playlist',
      searchPlaceholder: 'Search games...',
      estimatedDbSize: '84 MB',
      headerDisplayName: 'GAMES',
    ),
    'tv': MediaTypeConfig(
      displayName: 'TV Show',
      pluralDisplayName: 'TV Shows',
      icon: Icons.tv,
      fallbackIcon: Icons.tv,
      listName: 'Watchlist',
      listActionName: 'watchlist',
      searchPlaceholder: 'Search TV shows...',
      estimatedDbSize: '238 MB',
      headerDisplayName: 'SHOWS',
    ),
    // Header plural form aliases
    'movies': MediaTypeConfig(
      displayName: 'Movie',
      pluralDisplayName: 'Movies',
      icon: Icons.movie,
      fallbackIcon: Icons.movie,
      listName: 'Watchlist',
      listActionName: 'watchlist',
      searchPlaceholder: 'Search movies...',
      estimatedDbSize: '440 MB',
      headerDisplayName: 'MOVIES',
    ),
    'books': MediaTypeConfig(
      displayName: 'Book',
      pluralDisplayName: 'Books',
      icon: Icons.book,
      fallbackIcon: Icons.menu_book,
      listName: 'Reading List',
      listActionName: 'reading list',
      searchPlaceholder: 'Search books...',
      estimatedDbSize: '191 MB',
      headerDisplayName: 'BOOKS',
    ),
    'games': MediaTypeConfig(
      displayName: 'Game',
      pluralDisplayName: 'Games',
      icon: Icons.videogame_asset,
      fallbackIcon: Icons.sports_esports,
      listName: 'Playlist',
      listActionName: 'playlist',
      searchPlaceholder: 'Search games...',
      estimatedDbSize: '84 MB',
      headerDisplayName: 'GAMES',
    ),
  };

  // Helper methods to access media type configuration
  static MediaTypeConfig getMediaConfig(String mediaType) {
    return mediaTypes[mediaType] ?? const MediaTypeConfig.unknown();
  }

  // Helper method to get config using the new enum
  static MediaTypeConfig getMediaConfigFromEnum(MediaType mediaType) {
    return MediaTypeConfig(
      displayName: mediaType.displayName,
      pluralDisplayName: mediaType.pluralDisplayName,
      icon: mediaType.icon,
      fallbackIcon: mediaType.fallbackIcon,
      listName: mediaType.listName,
      listActionName: mediaType.listActionName,
      searchPlaceholder: mediaType.searchPlaceholder,
      estimatedDbSize: mediaType.estimatedDbSize,
      headerDisplayName: mediaType.headerDisplayName,
    );
  }
  
  static String getMediaDisplayName(String mediaType) {
    return getMediaConfig(mediaType).displayName;
  }
  
  static String getMediaPluralDisplayName(String mediaType) {
    return getMediaConfig(mediaType).pluralDisplayName;
  }
  
  static IconData getMediaIcon(String mediaType) {
    return getMediaConfig(mediaType).icon;
  }
  
  static IconData getMediaFallbackIcon(String mediaType) {
    return getMediaConfig(mediaType).fallbackIcon;
  }
  
  static String getMediaListName(String mediaType) {
    return getMediaConfig(mediaType).listName;
  }
  
  static String getMediaListActionName(String mediaType) {
    return getMediaConfig(mediaType).listActionName;
  }
  
  static String getMediaSearchPlaceholder(String mediaType) {
    return getMediaConfig(mediaType).searchPlaceholder;
  }
  
  static String getMediaEstimatedDbSize(String mediaType) {
    return getMediaConfig(mediaType).estimatedDbSize;
  }
  
  static String getMediaHeaderDisplayName(String mediaType) {
    return getMediaConfig(mediaType).headerDisplayName;
  }

  // === EDITABLE SPACING ===
  static const double spacingXS = 4;
  static const double spacingSM = 8;
  static const double spacingMD = 16;
  static const double spacingLG = 24;
  static const double spacingXL = 32;
  
  // === EDITABLE BORDER RADIUS ===
  static const double borderRadius = 8;
  static const double cardBorderRadius = 12;
  static const double buttonBorderRadius = 24;
  
  // === EDITABLE GRADIENTS ===
  static const Gradient logoGradient = LinearGradient(
    colors: [Color(0xFFC165DD), Color(0xFF9880FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.3, 0.9],
  );

  // === EDITABLE TYPOGRAPHY ===
  static const String fontFamily = 'Inter';
  static const String fullFontFamily = 'Inter, Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif';
  
  // Logo text style
  static const TextStyle logoTextStyle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w100,
    fontSize: 14,
    letterSpacing: 1.8,
    height: 1.0,
    textBaseline: TextBaseline.alphabetic,
  );
  
  // Header selector (media type tabs)
  static const TextStyle headerSelectorStyle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w100,
    fontSize: 14,
    letterSpacing: 1.5,
    color: textPrimary,
  );
  
  // Section header styles - easily customizable
  static const TextStyle sectionHeaderLarge = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 24,
    letterSpacing: 3.0,
    color: textPrimary,
  );
  
  static const TextStyle sectionHeaderMedium = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 20,
    letterSpacing: 2.5,
    color: textPrimary,
  );
  
  static const TextStyle sectionHeaderSmall = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 18,
    letterSpacing: 2.25,
    color: textPrimary,
  );
  
  // Search results header style
  static const TextStyle searchResultsHeaderStyle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.bold,
    fontSize: 20,
    color: textPrimary,
  );
  
  // Library/Watchlist header style
  static TextStyle get libraryHeaderStyle => TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 18,
    letterSpacing: 2.3 * libraryHeaderLetterSpacing,
    color: textPrimary,
  );
  
  // API credentials header style
  static const TextStyle apiCredentialsHeaderStyle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.bold,
    fontSize: 18,
    color: infoColor,
  );
  
  // === MEDIA CONTENT TEXT STYLES ===
  // Media title style - for suggested media item titles with stylized wide letter spacing
  static const TextStyle mediaTitleStyle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w300, // Thinner weight
    fontSize: 24, // Larger for suggestion titles
    color: textPrimary,
    letterSpacing: 2.0, // More exaggerated wide letter spacing
    height: 1.3,
  );
  
  // Media artist/creator style - for artist/creator info with stylized wide letter spacing
  static const TextStyle mediaArtistStyle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w200, // Thinner weight
    fontSize: 15,
    color: textSecondary,
    letterSpacing: 1.4, // More exaggerated wide letter spacing
    height: 1.4,
  );
  
  // Media description style - for suggested media item descriptions with stylized wide letter spacing
  static const TextStyle mediaDescriptionStyle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w200, // Thinner weight
    fontSize: 14,
    color: textPrimary,
    letterSpacing: 1.0, // More exaggerated wide letter spacing
    height: 1.6,
  );
  
  // Bot reasoning style - for AI reasoning about media suggestions with stylized wide letter spacing
  static const TextStyle botReasoningStyle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w200, // Thinner weight
    fontSize: 14,
    color: textTertiary,
    letterSpacing: 0.8, // More exaggerated wide letter spacing
    height: 1.6,
  );

  // Settings drawer media header style - matches SUGGESTED header with horizontal transform
  static const TextStyle settingsMediaHeaderStyle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 20,
    letterSpacing: 3.0,
    color: textPrimary,
  );

  // Reasoning section headers style - bolder and closer letter spacing
  static const TextStyle reasoningHeaderStyle = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w600, // Thicker lines
    fontSize: 13,
    letterSpacing: 1.2, // Closer together than 2.0
    color: primaryColor,
  );


  
  // === EDITABLE SECTION HEADER SCALING ===
  // Separate scaling for different types of section headers
  static const double suggestionHeaderScaleX = 1.15; // SUGGESTED headers - original width
  static const double libraryHeaderScaleX = 1.25; // Library/Watchlist headers - original width
  
  // Letter spacing for section headers
  static const double suggestionHeaderLetterSpacing = 1.10; // Letter spacing for SUGGESTED headers
  static const double libraryHeaderLetterSpacing = 1.0; // Letter spacing for Library/Watchlist headers
  
  // SUGGESTION HEADERS (SUGGESTED, etc.)
  static Widget wideSuggestionHeaderLarge(String text) => Transform.scale(
    scaleX: suggestionHeaderScaleX,
    child: Text(text, style: suggestionHeaderLarge),
  );
  
  static Widget wideSuggestionHeaderMedium(String text) => Transform.scale(
    scaleX: suggestionHeaderScaleX,
    child: Text(text, style: suggestionHeaderMedium),
  );
  
  static Widget wideSuggestionHeaderSmall(String text) => Transform.scale(
    scaleX: suggestionHeaderScaleX,
    child: Text(text, style: suggestionHeaderSmall),
  );
  
  // LIBRARY/WATCHLIST HEADERS (Your Library, Your Watchlist, FAVORITES, etc.)
  static Widget wideLibraryHeaderLarge(String text) => Transform.scale(
    scaleX: libraryHeaderScaleX,
    child: Text(text, style: libraryHeaderLarge),
  );
  
  static Widget wideLibraryHeaderMedium(String text) => Transform.scale(
    scaleX: libraryHeaderScaleX,
    child: Text(text, style: libraryHeaderMedium),
  );
  
  static Widget wideLibraryHeaderSmall(String text) => Transform.scale(
    scaleX: libraryHeaderScaleX,
    child: Text(text, style: libraryHeaderSmall),
  );
  
  // Specific library header with its own style
  static Widget wideLibraryHeader(String text) => Transform.scale(
    scaleX: libraryHeaderScaleX,
    child: Text(text, style: libraryHeaderStyle),
  );
  
  // Search results header
  static Widget wideSearchResultsHeader(String text) => Transform.scale(
    scaleX: libraryHeaderScaleX, // Use library scale for search results
    child: Text(text, style: searchResultsHeaderStyle),
  );

  // Legacy functions for backward compatibility
  static Widget wideHeaderLarge(String text) => wideSuggestionHeaderLarge(text);
  static Widget wideHeaderMedium(String text) => wideSuggestionHeaderMedium(text);
  static Widget wideHeaderSmall(String text) => wideSuggestionHeaderSmall(text);

  // Legacy text styles for compatibility
  static const TextStyle headingStyle = TextStyle(
        fontFamily: fullFontFamily,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      );

  static const TextStyle bodyStyle = TextStyle(
        fontFamily: fullFontFamily,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      );

  // Generalized suggestion button theme (matches pagination buttons)
  static ButtonStyle get suggestionButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: accentColor, // Use accentColor (0xFFA855F7) like pagination
    side: const BorderSide(color: accentColor, width: 1),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Reduced from 24 to 16
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonBorderRadius),
    ),
    textStyle: libraryHeaderStyle.copyWith(
      fontSize: 14, // Smaller than normal library header
      letterSpacing: 2.0, // Keep wide letter spacing but slightly reduced
      fontWeight: FontWeight.w300,
    ),
  );

  // Suggestion button text style (smaller version of library header)
  static TextStyle get suggestionButtonTextStyle => libraryHeaderStyle.copyWith(
    fontSize: 12, // Reduced from 14 to 12 for more compact buttons
    letterSpacing: 2.0,
    fontWeight: FontWeight.w200, // Ultra-thin like section headers
    color: accentColor,
  );

  /// Returns the main ThemeData for the app
  static ThemeData get theme {
    return ThemeData(
      // General theme colors
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: textPrimary,
        onSecondary: textPrimary,
        onSurface: textPrimary,
        onError: textPrimary,
        brightness: Brightness.dark,
      ),
      
      // Background colors
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: backgroundColor,
      applyElevationOverlayColor: true,
      
      // Typography settings
      textTheme: _buildTextTheme(),
      
      // Card theme - updated to match MUI styling exactly
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardBorderRadius),
          side: const BorderSide(color: Color(0xFF323232), width: 1),
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
      dialogTheme: DialogThemeData(
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
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
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
      tabBarTheme: const TabBarThemeData(
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
        fontFamily: 'Inter, Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
        fontSize: 16,
        color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Inter, Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
        fontSize: 14,
        color: textPrimary,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Inter, Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
        fontSize: 12,
        color: textSecondary,
      ),
    );
    
    const TextStyle headingStyle = TextStyle(
      fontFamily: 'Inter, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
      fontWeight: FontWeight.w300,
      color: textPrimary, 
      letterSpacing: 1.0,
    );
    
    return baseTheme.copyWith(
      // Display styles
      displayLarge: headingStyle.copyWith(fontSize: 57),
      displayMedium: headingStyle.copyWith(fontSize: 45),
      displaySmall: headingStyle.copyWith(fontSize: 36),
      
      // Headline styles - using our media styles for suggestion content
      headlineLarge: mediaTitleStyle, // For suggestion titles
      headlineMedium: headingStyle.copyWith(fontSize: 28),
      headlineSmall: headingStyle.copyWith(fontSize: 24),
      
      // Title styles - using our media styles for content
      titleLarge: mediaArtistStyle, // For artist/creator info
      titleMedium: mediaDescriptionStyle, // For media descriptions
      titleSmall: botReasoningStyle, // For bot reasoning
      
      // Label styles - for buttons, tabs, etc.
      labelLarge: const TextStyle(
        fontFamily: 'Inter, Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        letterSpacing: 0.5,
      ),
      labelMedium: const TextStyle(
        fontFamily: 'Inter, Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textPrimary,
        letterSpacing: 0.5,
      ),
      labelSmall: const TextStyle(
        fontFamily: 'Inter, Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        letterSpacing: 0.5,
      ),
    ).copyWith(
      // Custom suggestion content styles
      // Using headlineSmall for suggestion title (24px with wide spacing)
      headlineSmall: const TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w400,
        fontSize: 24,
        letterSpacing: 1.2,
        color: textPrimary,
        height: 1.3,
      ),
      // Using titleMedium for suggestion artist/creator (15px with subtle spacing)
      titleMedium: const TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w300,
        fontSize: 15,
        letterSpacing: 0.8,
        color: textSecondary,
        height: 1.4,
      ),
      // Using bodyLarge for suggestion description (14px with subtle spacing)
      bodyLarge: const TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w300,
        fontSize: 14,
        letterSpacing: 0.6,
        color: textPrimary,
        height: 1.6,
      ),
      // Using bodyMedium for suggestion reasoning (14px with subtle spacing)
      bodyMedium: const TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w300,
        fontSize: 14,
        letterSpacing: 0.5,
        color: textTertiary,
        height: 1.6,
      ),
    );
  }
  
  /// Build the elevated button theme - matching MUI contained buttons
  static ElevatedButtonThemeData _buildElevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: textPrimary,
        textStyle: const TextStyle(
          fontFamily: 'Inter, Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
          fontWeight: FontWeight.w500,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonBorderRadius),
        ),
        elevation: 0,
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.hovered)) {
            return primaryHover;
          }
          if (states.contains(WidgetState.focused) || states.contains(WidgetState.pressed)) {
            return primaryHover.withOpacity(0.8);
          }
          return Colors.transparent;
        }),
      ),
    );
  }
  
  /// Build the outlined button theme - matching MUI outlined buttons
  static OutlinedButtonThemeData _buildOutlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        textStyle: const TextStyle(
          fontFamily: 'Inter, Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
          fontWeight: FontWeight.w500,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonBorderRadius),
        ),
        side: const BorderSide(color: primaryColor, width: 1),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.hovered)) {
            return primaryColor.withOpacity(0.1);
          }
          if (states.contains(WidgetState.focused) || states.contains(WidgetState.pressed)) {
            return primaryColor.withOpacity(0.2);
          }
          return Colors.transparent;
        }),
      ),
    );
  }
  
  /// Build the text button theme - matching MUI text buttons
  static TextButtonThemeData _buildTextButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        textStyle: const TextStyle(
          fontFamily: 'Inter, Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
          fontWeight: FontWeight.w500,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonBorderRadius),
        ),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.hovered)) {
            return primaryColor.withOpacity(0.1);
          }
          if (states.contains(WidgetState.focused) || states.contains(WidgetState.pressed)) {
            return primaryColor.withOpacity(0.2);
          }
          return Colors.transparent;
        }),
      ),
    );
  }
  
  /// Build the input decoration theme - matching MUI TextField and Input components
  static InputDecorationTheme _buildInputDecorationTheme() {
    return InputDecorationTheme(
      fillColor: surfaceColor,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: Color(0xFF323232), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: Color(0xFF323232), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: errorColor, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Inter, Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
        color: textSecondary,
        fontSize: 14,
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Inter, Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
        color: textSecondary,
        fontSize: 14,
      ),
      errorStyle: const TextStyle(
        fontFamily: 'Inter, Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
        color: errorColor,
        fontSize: 12,
      ),
    );
  }

  // THEMED HEADER FUNCTIONS using AppTheme scaling values
  
  /// Create a suggestion header (SUGGESTED, etc.) with proper scaling
  static Widget themedSuggestionHeader(String text) {
    return Transform(
      transform: Matrix4.identity()..scale(suggestionHeaderScaleX, 1.0),
      alignment: Alignment.center,
      child: Text(
        text,
        style: suggestionHeaderLarge, // Use the suggestion style with configurable letter spacing
        textAlign: TextAlign.center,
      ),
    );
  }
  
  /// Create a library/watchlist header with proper scaling
  static Widget themedLibraryHeader(String text) {
    return Transform(
      transform: Matrix4.identity()..scale(libraryHeaderScaleX, 1.0),
      alignment: Alignment.center,
      child: Text(
        text,
        style: libraryHeaderMedium, // Use the library style with configurable letter spacing
        textAlign: TextAlign.center,
      ),
    );
  }

  // Suggestion header styles - use configurable letter spacing
  static TextStyle get suggestionHeaderLarge => TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 24,
    letterSpacing: 3.0 * suggestionHeaderLetterSpacing,
    color: textPrimary,
  );
  
  static TextStyle get suggestionHeaderMedium => TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 20,
    letterSpacing: 2.5 * suggestionHeaderLetterSpacing,
    color: textPrimary,
  );
  
  static TextStyle get suggestionHeaderSmall => TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 18,
    letterSpacing: 2.25 * suggestionHeaderLetterSpacing,
    color: textPrimary,
  );

  // Library header styles - use configurable letter spacing
  static TextStyle get libraryHeaderLarge => TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 24,
    letterSpacing: 3.0 * libraryHeaderLetterSpacing,
    color: textPrimary,
  );
  
  static TextStyle get libraryHeaderMedium => TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 20,
    letterSpacing: 2.5 * libraryHeaderLetterSpacing,
    color: textPrimary,
  );
  
  static TextStyle get libraryHeaderSmall => TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w200,
    fontSize: 18,
    letterSpacing: 2.25 * libraryHeaderLetterSpacing,
    color: textPrimary,
  );
}