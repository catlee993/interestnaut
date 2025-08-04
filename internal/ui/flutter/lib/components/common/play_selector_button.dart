import 'package:flutter/material.dart';
import '../../theme.dart';
import 'wide_text.dart';

/// Smart play selector button that adapts based on available sources
/// - Single source: Shows colored play button with tooltip
/// - Multiple sources: Shows dropdown menu with options
class PlaySelectorButton extends StatefulWidget {
  final String? youtubeId;
  final String? spotifyId;
  final VoidCallback? onYouTubePressed;
  final VoidCallback? onSpotifyPressed;
  final double size;

  const PlaySelectorButton({
    Key? key,
    this.youtubeId,
    this.spotifyId,
    this.onYouTubePressed,
    this.onSpotifyPressed,
    this.size = 28,
  }) : super(key: key);

  @override
  State<PlaySelectorButton> createState() => _PlaySelectorButtonState();
}

class _PlaySelectorButtonState extends State<PlaySelectorButton> {
  bool isMenuOpen = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  bool get hasYouTube => widget.youtubeId != null;
  bool get hasSpotify => widget.spotifyId != null;
  bool get hasMultipleSources => hasYouTube && hasSpotify;

  Color get _buttonColor {
    if (hasMultipleSources) return Colors.white.withOpacity(0.8);
    if (hasSpotify) return AppTheme.spotifyGreen;
    if (hasYouTube) return const Color(0xFF4FC3F7);
    return Colors.white.withOpacity(0.8);
  }

  String get _tooltipText {
    if (hasMultipleSources) return 'Play options';
    if (hasSpotify) return 'Play on Spotify';
    if (hasYouTube) return 'Play on YouTube';
    return 'Play';
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    // Don't call setState in dispose - just update the variable
    isMenuOpen = false;
  }

  void _showMenu() {
    if (!hasMultipleSources) return;

    setState(() => isMenuOpen = true);

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _removeOverlay,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Invisible background to catch taps
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
            // Menu positioned dynamically above or below button
            Positioned(
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: _calculateMenuOffset(),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFF2A2A2A),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasYouTube)
                          GestureDetector(
                            onTap: () {
                              _removeOverlay();
                              widget.onYouTubePressed?.call();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_arrow,
                                    color: const Color(0xFF4FC3F7),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  WideText(
                                    text: 'YOUTUBE',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (hasSpotify)
                          GestureDetector(
                            onTap: () {
                              _removeOverlay();
                              widget.onSpotifyPressed?.call();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.play_arrow,
                                    color: AppTheme.spotifyGreen,
                                    size: 16,
                                    shadows: [
                                      Shadow(
                                        color: AppTheme.spotifyGreen.withOpacity(0.6),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  WideText(
                                    text: 'SPOTIFY',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  String _getSourceText() {
    List<String> sources = [];
    if (hasSpotify) sources.add('SPOTIFY');
    if (hasYouTube) sources.add('YOUTUBE'); 
    return sources.join(' ');
  }

  Offset _calculateMenuOffset() {
    // Get render box to determine button position
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return const Offset(-30, 40);

    // Get button position relative to screen
    final buttonPosition = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;
    
    // Estimate menu height (approximate based on number of items)
    final menuHeight = (hasYouTube && hasSpotify) ? 70.0 : 35.0;
    
    // Check if menu would go below screen
    final wouldOverflow = buttonPosition.dy + 40 + menuHeight > screenSize.height;
    
    if (wouldOverflow) {
      // Position menu above the button
      return Offset(-30, -menuHeight - 10);
    } else {
      // Position menu below the button (default)
      return const Offset(-30, 40);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!hasYouTube && !hasSpotify) {
      return const SizedBox.shrink();
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: _tooltipText,
        child: GestureDetector(
          onTap: () {
            if (hasMultipleSources) {
              _showMenu();
            } else if (hasSpotify) {
              widget.onSpotifyPressed?.call();
            } else if (hasYouTube) {
              widget.onYouTubePressed?.call();
            }
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (hasMultipleSources) {
                      _showMenu();
                    } else if (hasSpotify) {
                      widget.onSpotifyPressed?.call();
                    } else if (hasYouTube) {
                      widget.onYouTubePressed?.call();
                    }
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow,
                          color: _buttonColor,
                          size: widget.size,
                          shadows: hasSpotify && !hasMultipleSources ? [
                            Shadow(
                              color: AppTheme.spotifyGreen.withOpacity(0.6),
                              blurRadius: 12,
                            ),
                          ] : null,
                        ),
                        if (hasMultipleSources) ...[
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: _buttonColor,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}