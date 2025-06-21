import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/recommendation_service.dart';
import '../../utils/text_utils.dart';

/// A reusable card component for displaying media items in library/watchlist sections
/// Based on the music section's beautiful styling with gradient overlay and action buttons
class MediaLibraryCard extends StatelessWidget {
  final MediaSuggestion suggestion;
  final bool isWatchlist;
  final String mediaType;
  final VoidCallback? onRemove;
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onAddToWatchlist;
  final VoidCallback? onRemoveFromWatchlist;
  final VoidCallback? onFavorite;
  final VoidCallback? onUnfavorite;
  final bool isInWatchlist;

  const MediaLibraryCard({
    Key? key,
    required this.suggestion,
    required this.isWatchlist,
    required this.mediaType,
    this.onRemove,
    this.onLike,
    this.onDislike,
    this.onAddToWatchlist,
    this.onRemoveFromWatchlist,
    this.onFavorite,
    this.onUnfavorite,
    this.isInWatchlist = false,
  }) : super(key: key);

  IconData _getMediaIcon() {
    switch (mediaType) {
      case 'music':
        return Icons.music_note;
      case 'movie':
        return Icons.movie;
      case 'book':
        return Icons.book;
      case 'game':
      case 'video_game':
        return Icons.videogame_asset;
      case 'tv':
      case 'tv_show':
        return Icons.tv;
      default:
        return Icons.media_bluetooth_on;
    }
  }

  String _getWatchlistTerminology() {
    switch (mediaType) {
      case 'music':
        return 'playlist';
      case 'movie':
      case 'tv':
      case 'tv_show':
        return 'watchlist';
      case 'book':
        return 'reading list';
      case 'game':
      case 'video_game':
        return 'wishlist';
      default:
        return 'list';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
            
            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x40000000), // rgba(0,0,0,0.25) at 70%
                      Color(0x66000000), // rgba(0,0,0,0.4) at 85%
                      Color(0x99000000), // rgba(0,0,0,0.6) at 95%
                      Colors.black,      // rgba(0,0,0,1) at 100%
                    ],
                    stops: [0.0, 0.70, 0.85, 0.95, 1.0],
                  ),
                ),
              ),
            ),
            
            // Remove button for watchlist/saved views (top-right)
            if (isWatchlist && onRemove != null)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 24,
                    height: 24,
                    child: CustomPaint(
                      painter: XButtonPainter(),
                    ),
                  ),
                ),
              ),
            
            // Content overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      suggestion.title ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Year info
                    if (suggestion.createdAt != null)
                      Text(
                        suggestion.createdAt!.year.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    
                    const SizedBox(height: 8),
                    
                    // Action buttons row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left side - metadata
                        if (suggestion.artist?.isNotEmpty == true)
                          Flexible(
                            child: Text(
                              TextUtils.formatArtistNames(suggestion.artist),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        
                        // Right side - action buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isWatchlist) ...[
                              // Add to watchlist button - blue with checkmark if in watchlist, white if not
                              if (onAddToWatchlist != null || onRemoveFromWatchlist != null)
                                IconButton(
                                  onPressed: () => isInWatchlist 
                                    ? onRemoveFromWatchlist?.call()
                                    : onAddToWatchlist?.call(),
                                  icon: Icon(
                                    isInWatchlist ? Icons.bookmark_added : Icons.bookmark_add,
                                    color: isInWatchlist ? Colors.blue : Colors.white,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                            ] else ...[
                              // Like button for watchlist items
                              if (onLike != null)
                                IconButton(
                                  onPressed: onLike,
                                  icon: const Icon(
                                    Icons.thumb_up,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                              
                              // Dislike button for watchlist items
                              if (onDislike != null)
                                IconButton(
                                  onPressed: onDislike,
                                  icon: const Icon(
                                    Icons.thumb_down,
                                    color: Colors.white70,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                            ],
                            
                            // Purple heart to unfavorite/remove from library or favorite watchlist item
                            if (onFavorite != null || onUnfavorite != null)
                              IconButton(
                                onPressed: () => isWatchlist 
                                  ? onFavorite?.call()
                                  : onUnfavorite?.call(),
                                icon: const Icon(
                                  Icons.favorite,
                                  color: Color(0xFF7B68EE), // Primary purple color
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for the X button
class XButtonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Draw X
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.25),
      Offset(size.width * 0.75, size.height * 0.75),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.25),
      Offset(size.width * 0.25, size.height * 0.75),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
} 