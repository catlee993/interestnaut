import 'package:flutter/material.dart';
import '../../core/responsive.dart';
import 'media_header.dart';

/// Adaptive wrapper for MediaHeader that provides mobile-specific layout
/// while preserving the original desktop layout unchanged
class AdaptiveMediaHeader extends StatelessWidget {
  final Widget? additionalControl;
  final void Function(String) onSearch;
  final VoidCallback? onClearSearch;
  final String currentMedia;
  final void Function(String)? onMediaChange;
  final String searchQuery;
  final bool? spotifySearchEnabled;
  final ValueChanged<bool>? onSpotifySearchToggle;

  const AdaptiveMediaHeader({
    Key? key,
    this.additionalControl,
    required this.onSearch,
    this.onClearSearch,
    this.currentMedia = 'music',
    this.onMediaChange,
    this.searchQuery = '',
    this.spotifySearchEnabled,
    this.onSpotifySearchToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (Responsive.isMobile(context)) {
      // Mobile-specific header layout
      return _MobileMediaHeader(
        additionalControl: additionalControl,
        onSearch: onSearch,
        onClearSearch: onClearSearch,
        currentMedia: currentMedia,
        onMediaChange: onMediaChange,
        searchQuery: searchQuery,
        spotifySearchEnabled: spotifySearchEnabled,
        onSpotifySearchToggle: onSpotifySearchToggle,
      );
    } else {
      // Use existing desktop MediaHeader unchanged
      return MediaHeader(
        additionalControl: additionalControl,
        onSearch: onSearch,
        onClearSearch: onClearSearch,
        currentMedia: currentMedia,
        onMediaChange: onMediaChange,
        searchQuery: searchQuery,
        spotifySearchEnabled: spotifySearchEnabled,
        onSpotifySearchToggle: onSpotifySearchToggle,
      );
    }
  }
}

/// Mobile-specific media header implementation
class _MobileMediaHeader extends StatelessWidget {
  final Widget? additionalControl;
  final void Function(String) onSearch;
  final VoidCallback? onClearSearch;
  final String currentMedia;
  final void Function(String)? onMediaChange;
  final String searchQuery;
  final bool? spotifySearchEnabled;
  final ValueChanged<bool>? onSpotifySearchToggle;

  const _MobileMediaHeader({
    this.additionalControl,
    required this.onSearch,
    this.onClearSearch,
    this.currentMedia = 'music',
    this.onMediaChange,
    this.searchQuery = '',
    this.spotifySearchEnabled,
    this.onSpotifySearchToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color.fromRGBO(18, 18, 18, 0.95),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Mobile header with hamburger menu and title
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Hamburger menu
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                  const SizedBox(width: 8),
                  // Media type and title
                  Expanded(
                    child: Text(
                      _getMediaDisplayName(currentMedia),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.2,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  // Settings button
                  IconButton(
                    icon: const Icon(Icons.settings, color: Color(0xFF7b68ee)),
                    onPressed: () {
                      // Same settings logic as desktop
                    },
                  ),
                ],
              ),
            ),
            // Mobile search bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: _getSearchPlaceholder(currentMedia),
                  hintStyle: const TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                  ),
                  filled: true,
                  fillColor: const Color.fromRGBO(40, 40, 40, 0.8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                onChanged: onSearch,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMediaDisplayName(String mediaType) {
    switch (mediaType) {
      case 'music':
        return 'Music';
      case 'movies':
        return 'Movies';
      case 'tv':
        return 'TV Shows';
      case 'games':
        return 'Games';
      case 'books':
        return 'Books';
      default:
        return 'Media';
    }
  }

  String _getSearchPlaceholder(String mediaType) {
    switch (mediaType) {
      case 'music':
        return 'Search tracks...';
      case 'movies':
        return 'Search movies...';
      case 'tv':
        return 'Search TV shows...';
      case 'books':
        return 'Search books...';
      case 'games':
        return 'Search games...';
      default:
        return 'Search...';
    }
  }
}