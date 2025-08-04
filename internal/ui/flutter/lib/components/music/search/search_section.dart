import 'package:flutter/material.dart';
import '../../../models/track_models.dart';
import '../tracks/search_result_card.dart';
import '../../common/media_grid.dart';
import '../../common/standard_close_button.dart';
import '../../common/spotify_branding.dart';

class SearchSection extends StatelessWidget {
  final List<BaseTrack> searchResults;
  final bool isLoading;
  final String? error;
  final Future<void> Function(String) onSearch;
  final Future<void> Function(BaseTrack) onPlay;
  final Future<void> Function(BaseTrack) onSave;
  final Future<void> Function(BaseTrack) onRemove;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  final bool limitToSpotifyActions;
  final bool? spotifySearchEnabled;
  final ValueChanged<bool>? onSpotifySearchToggle;

  const SearchSection({
    Key? key,
    required this.searchResults,
    this.isLoading = false,
    this.error,
    required this.onSearch,
    required this.onPlay,
    required this.onSave,
    required this.onRemove,
    required this.onRetry,
    required this.onClose,
    this.limitToSpotifyActions = false,
    this.spotifySearchEnabled,
    this.onSpotifySearchToggle,
  }) : super(key: key);

  String _getSearchResultsText(int count) {
    if (count == 0) return 'No results';
    if (count == 1) {
      return 'Found 1 track';
    }
    return 'Found $count tracks';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Colors.white70),
          ),
        ),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 120, // Constrain to minimum height like one result row
          child: Stack(
            children: [
              // Centered "No results" text
              Center(
                child: Transform.scale(
                  scaleX: 1.15, // Same horizontal stretch as stylized headers
                  child: const Text(
                    'No results',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              // X button positioned in top right
              Positioned(
                top: -6,
                right: -6,
                child: StandardCloseButton(
                  onPressed: onClose,
                  size: 18,
                  padding: const EdgeInsets.all(6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Display search results with sticky X button at top
    return Column(
      children: [
        // Sticky header with results count and X button - minimal top padding
        Container(
          padding: const EdgeInsets.fromLTRB(32.0, 4.0, 16.0, 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Spotify search toggle - positioned left
                  if (onSpotifySearchToggle != null) ...[
                    _SpotifyToggleButton(
                      spotifySearchEnabled: spotifySearchEnabled ?? false,
                      onToggle: onSpotifySearchToggle!,
                    ),
                    const SizedBox(width: 24), // More spacing
                  ],
                  // Results count text
                  Transform.scale(
                    scaleX: 1.15, // Same horizontal stretch as stylized headers
                    child: Text(
                      _getSearchResultsText(searchResults.length),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  // Info icon with tooltip for Spotify searches - positioned to the right
                  if (limitToSpotifyActions && searchResults.isNotEmpty) ...[
                    const SizedBox(width: 16), // Spacing before info icon
                    Tooltip(
                      message: 'Spotify content can be added to your Spotify library but cannot be used with Interestnaut reactions',
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                      ),
                      preferBelow: false,
                      child: Icon(
                        Icons.info_outline,
                        color: Colors.lightBlue.withOpacity(0.7),
                        size: 16,
                      ),
                    ),
                  ],
                ],
              ),
              StandardCloseButton(
                onPressed: onClose,
                size: 20,
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
        ),
        // Scrollable results area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 24.0),
            child: SingleChildScrollView(
              child: MediaGrid(
                columns: 3,  // Using 3 columns for better readability
                children: searchResults
                    .map((track) => SearchResultCard(
                          track: track,
                          isSaved: false,
                          onPlay: (t) => onPlay(t),
                          onSave: (t) => onSave(t),
                          onRemove: (t) => onRemove(t),
                          limitToSpotifyActions: limitToSpotifyActions,
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Interactive toggle button with hover effects
class _SpotifyToggleButton extends StatefulWidget {
  final bool spotifySearchEnabled;
  final ValueChanged<bool> onToggle;

  const _SpotifyToggleButton({
    required this.spotifySearchEnabled,
    required this.onToggle,
  });

  @override
  State<_SpotifyToggleButton> createState() => _SpotifyToggleButtonState();
}

class _SpotifyToggleButtonState extends State<_SpotifyToggleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final Color activeColor = widget.spotifySearchEnabled 
        ? const Color(0xFF1ED760) 
        : const Color(0xFF7B68EE);
        
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: OutlinedButton(
        onPressed: () => widget.onToggle(!widget.spotifySearchEnabled),
        style: OutlinedButton.styleFrom(
          foregroundColor: activeColor,
          backgroundColor: _isHovered ? activeColor.withOpacity(0.1) : Colors.transparent,
          side: BorderSide(color: activeColor.withOpacity(0.7)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.8,
            fontFamily: 'Inter',
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.spotifySearchEnabled) ...[
              SpotifyBranding(
                type: SpotifyBrandingType.iconOnly,
                size: SpotifyBrandingSize.small,
                color: SpotifyBrandingColor.green,
                showAttribution: false,
              ),
              const SizedBox(width: 6),
              const Text('SPOTIFY'),
            ] else ...[
              SizedBox(
                width: 21,
                height: 21,
                child: Image.asset(
                  'assets/images/logo/interestnaut-icon.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 6),
              const Text('INTERESTNAUT'),
            ],
          ],
        ),
      ),
    );
  }
}

