import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/recommendation_service.dart';
import '../../utils/text_utils.dart';
import 'media_library_grid.dart'; // Import for CardFormat enum
import '../../theme.dart';
import 'media_action_icons.dart';

/// A reusable card component for displaying media items in library/watchlist sections
/// Based on the music section's beautiful styling with gradient overlay and action buttons
class MediaLibraryCard extends StatelessWidget {
  final MediaSuggestion suggestion;
  final bool isWatchlist;
  final String mediaType;
  final CardFormat cardFormat; // Add card format parameter
  final VoidCallback? onRemove;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onAddToWatchlist;
  final VoidCallback? onRemoveFromWatchlist;
  final VoidCallback? onFavorite;
  final VoidCallback? onUnfavorite;
  final bool isInWatchlist;
  final bool isFavorited; // Add favorite status parameter
  final VoidCallback? onTap; // Add tap callback for opening drawer

  const MediaLibraryCard({
    Key? key,
    required this.suggestion,
    required this.isWatchlist,
    required this.mediaType,
    required this.cardFormat, // Make it required
    this.onRemove,
    this.onLike,
    this.onDislike,
    this.onAddToWatchlist,
    this.onRemoveFromWatchlist,
    this.onFavorite,
    this.onUnfavorite,
    this.isInWatchlist = false,
    this.isFavorited = false, // Default to not favorited
    this.onTap, // Add tap callback
  }) : super(key: key);

  IconData _getMediaIcon() {
    return AppTheme.getMediaIcon(mediaType);
  }

  String _getWatchlistTerminology() {
    return AppTheme.getMediaListActionName(mediaType);
  }

  /// Extract year from media suggestion data
  String? _getMediaYear(MediaSuggestion suggestion) {
    // Try to extract year from description if it contains release/publication info
    if (suggestion.description?.isNotEmpty == true) {
      // Look for patterns like "released in 2023", "published in 1984", "(2019)", etc.
      final yearPatterns = [
        RegExp(r'released in (\d{4})'),
        RegExp(r'published in (\d{4})'),
        RegExp(r'\((\d{4})\)'),
        RegExp(r'(\d{4})'), // Fallback to any 4-digit number
      ];
      
      for (final pattern in yearPatterns) {
        final match = pattern.firstMatch(suggestion.description!);
        if (match != null) {
          final year = int.tryParse(match.group(1)!);
          // Reasonable year range for media
          if (year != null && year >= 1900 && year <= DateTime.now().year + 2) {
            return year.toString();
          }
        }
      }
    }
    
    return null;
  }

  /// Build combined artist and year text
  String _buildArtistYearText(MediaSuggestion suggestion) {
    final artist = suggestion.artist?.isNotEmpty == true 
        ? TextUtils.formatArtistNames(suggestion.artist) 
        : null;
    final year = _getMediaYear(suggestion);
    
    if (artist != null && year != null) {
      return '$artist ($year)';
    } else if (artist != null) {
      return artist;
    } else if (year != null) {
      return year;
    } else {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF7B68EE).withOpacity(0.3),
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
          children: [
            // Full image background
            Positioned.fill(
              child: suggestion.coverArtUrl?.isNotEmpty == true
                ? Image.network(
                    suggestion.coverArtUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFF7B68EE).withOpacity(0.1),
                        child: Center(
                          child: Icon(
                            _getMediaIcon(),
                            size: 60,
                            color: Colors.white54,
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    color: const Color(0xFF7B68EE).withOpacity(0.1),
                    child: Center(
                      child: Icon(
                        _getMediaIcon(),
                        size: 60,
                        color: Colors.white54,
                      ),
                    ),
                  ),
            ),
            
            // Gradient overlay - darker contrast starting at title level
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Color(0x66000000), // rgba(0,0,0,0.4) start fade earlier
                      Color(0xCC000000), // rgba(0,0,0,0.8) stronger contrast for title area
                      Color(0xFF000000), // rgba(0,0,0,1.0) fully dark at bottom
                    ],
                    stops: [0.0, 0.70, 0.80, 0.90, 1.0], // Start fade earlier at 70%
                  ),
                ),
              ),
            ),
            
            // Remove button for watchlist views ONLY (top-right)
            if (isWatchlist && onRemove != null)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 20,
                    height: 20,
                    child: CustomPaint(
                      painter: XButtonPainter(),
                    ),
                  ),
                ),
              ),
            
            // Controls - positioned independently at current location
            Positioned(
              bottom: 15,
              right: 16,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isWatchlist) ...[
                            // Add to watchlist button - using centralized icon logic
                            if (onAddToWatchlist != null || onRemoveFromWatchlist != null)
                              IconButton(
                                onPressed: () => isInWatchlist 
                                  ? onRemoveFromWatchlist?.call()
                                  : onAddToWatchlist?.call(),
                                icon: Icon(
                                  MediaActionIcons.getWatchlistIcon(isInWatchlist),
                                  color: MediaActionIcons.getWatchlistColor(isInWatchlist),
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                          ] else ...[
                            // Like button for watchlist items - using centralized logic
                            if (onLike != null)
                              IconButton(
                                onPressed: onLike,
                                icon: Icon(
                                  MediaActionIcons.getLikeIcon(false), // Assume not liked for now
                                  color: Colors.white70, // Keep current color for now
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                            
                            // Dislike button for watchlist items - using centralized logic
                            if (onDislike != null)
                              IconButton(
                                onPressed: onDislike,
                                icon: Icon(
                                  MediaActionIcons.getDislikeIcon(),
                                  color: Colors.white70, // Keep current color for now
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                              ),
                          ],
                          
                          // Favorite heart - using centralized icon logic
                          if (onFavorite != null || onUnfavorite != null)
                            IconButton(
                              onPressed: () => isWatchlist 
                                ? onFavorite?.call()
                                : onUnfavorite?.call(),
                              icon: Icon(
                                MediaActionIcons.getFavoriteIcon(isFavorited),
                                color: MediaActionIcons.getFavoriteColor(isFavorited),
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                        ],
                      ),
                ),
              ),
            
            // Title - positioned just above controls with full width
            Positioned(
              bottom: 45, // Brought title up another 5px from 40
              left: 16,
              right: 16, // Title gets full width
              child: Text(
                suggestion.title ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300, // Thinner like suggestion title
                  color: Colors.white,
                  letterSpacing: 1.2, // Wide letter spacing like suggestions
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // Author/year - positioned at control level with ellipsis protection
            if (suggestion.artist?.isNotEmpty == true || _getMediaYear(suggestion) != null)
              Positioned(
                bottom: 26, // Brought author up another 3px from 23
                left: 16,
                right: isWatchlist ? 110 : 90, // More space for watchlist controls, normal space for favorites
                child: Text(
                  _buildArtistYearText(suggestion),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w200, // Thinner like suggestion author
                    color: Colors.white.withOpacity(0.8),
                    letterSpacing: 0.9, // Wide letter spacing like suggestions
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }
}

/// Custom painter for the X button
class XButtonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Purple outline paint (thicker)
    final outlinePaint = Paint()
      ..color = const Color(0xFFA855F7)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // White X paint (thinner, on top)
    final xPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Draw purple outline first (behind)
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.25),
      Offset(size.width * 0.75, size.height * 0.75),
      outlinePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.25),
      Offset(size.width * 0.25, size.height * 0.75),
      outlinePaint,
    );

    // Draw white X on top
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.25),
      Offset(size.width * 0.75, size.height * 0.75),
      xPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.25),
      Offset(size.width * 0.25, size.height * 0.75),
      xPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
} 