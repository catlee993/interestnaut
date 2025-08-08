import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/theme.dart';
import 'media_action_icons.dart';

class MediaCard extends StatelessWidget {
  final MediaItem item;
  final bool isSaved;
  final bool isInWatchlist;
  final String view;
  final Function(int) onSave;
  final Function(int)? onAddToWatchlist;
  final Function(int)? onRemoveFromWatchlist;
  final Function(int)? onLike;
  final Function(int)? onDislike;

  const MediaCard({
    Key? key,
    required this.item,
    required this.isSaved,
    this.isInWatchlist = false,
    this.view = 'default',
    required this.onSave,
    this.onAddToWatchlist,
    this.onRemoveFromWatchlist,
    this.onLike,
    this.onDislike,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasPoster = item.posterPath.isNotEmpty;
    final mediaIcon = AppTheme.getMediaFallbackIcon(item.mediaType);

    return Card(
      elevation: 4,
      color: AppTheme.surfaceColor,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.1), width: 1),
      ),
      child: InkWell(
        onTap: () {},
        splashColor: AppTheme.primaryColor.withOpacity(0.1),
        highlightColor: AppTheme.primaryColor.withOpacity(0.05),
        child: Stack(
          children: [
            // Poster/Image takes up the full card
            AspectRatio(
              aspectRatio: 2 / 3,
              child: hasPoster
                  ? Image.network(
                      _getImageUrl(item),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildFallbackImage(mediaIcon, item.title);
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: AppTheme.cardBackgroundColor,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        );
                      },
                    )
                  : _buildFallbackImage(mediaIcon, item.title),
            ),
            
            // Gradient overlay - darker contrast starting at title level
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.95), // Very dark at bottom for controls
                      Colors.black.withOpacity(0.9),  // Darker contrast for title
                      Colors.black.withOpacity(0.75), // Strong contrast at title top
                      Colors.transparent,             // Transparent above text area
                    ],
                    stops: const [0.0, 0.08, 0.15, 0.20],
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
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with optional tooltip for overview - positioned above controls
                    Tooltip(
                      message: item.overview ?? '',
                      child: Transform.scale(
                        scaleX: 1.2, // Horizontally stretch the title
                        child: Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 2), // ← Controls title-to-author/controls gap
                    
                    // Author/year+rating and controls row - maintains ellipsis behavior
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left side: Author/year and rating with flexible width for overflow
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Author for books/audiobooks, Release date for others
                              if ((item.mediaType == 'book' || item.mediaType == 'audiobook') && item.author != null)
                                Flexible(
                                  child: Text(
                                    item.author!,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )
                              else if (!(item.mediaType == 'book' || item.mediaType == 'audiobook') && item.releaseDate != null)
                                Flexible(
                                  child: Text(
                                    item.releaseDate!,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              
                              const SizedBox(width: 8),
                              
                              // Rating pill or genre tag
                              _buildRatingOrGenreTag(),
                            ],
                          ),
                        ),
                        
                        // Controls - pushed down slightly
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: view == 'default'
                          ? Row(
                              children: [
                                // Show watchlist control if available
                                if (onAddToWatchlist != null || onRemoveFromWatchlist != null)
                                  _WatchlistControls(
                                    isInWatchlist: isInWatchlist,
                                    onAddToWatchlist: isInWatchlist && onRemoveFromWatchlist != null
                                        ? () => onRemoveFromWatchlist!(item.id)
                                        : onAddToWatchlist != null
                                            ? () => onAddToWatchlist!(item.id)
                                            : null,
                                  ),
                                
                                // Library/save control
                                _LibraryControls(
                                  isInLibrary: isSaved,
                                  onToggleLibrary: () => onSave(item.id),
                                ),
                              ],
                            )
                          : // Feedback controls for watchlist/saved view
                            _FeedbackControls(
                              onLike: onLike != null ? () => onLike!(item.id) : null,
                              onDislike: onDislike != null ? () => onDislike!(item.id) : null,
                              onAddToFavorites: () => onSave(item.id),
                              isSaved: isSaved,
                            ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Close button for watchlist items, similar to Breaking Bad card in screenshot
            if (isInWatchlist && onRemoveFromWatchlist != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
                    ),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: () => onRemoveFromWatchlist!(item.id),
                    tooltip: 'Remove from Watchlist',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper to build a fallback image when poster is not available
  Widget _buildFallbackImage(IconData icon, String title) {
    return Container(
      color: AppTheme.cardBackgroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon, 
            size: 60, 
            color: AppTheme.textPrimary.withOpacity(0.7)
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Helper to get the correct image URL based on media type
  String _getImageUrl(MediaItem item) {
    if (item.mediaType == 'book' || item.mediaType == 'audiobook') {
      return item.posterPath;
    } else if (item.mediaType == 'movie' || item.mediaType == 'tv_show') {
      return 'https://image.tmdb.org/t/p/w500${item.posterPath}';
    } else {
      return item.posterPath;
    }
  }

  // Helper to build rating pill or genre tag
  Widget _buildRatingOrGenreTag() {
    final isBook = item.mediaType == 'book';
    final isAudiobook = item.mediaType == 'audiobook';
    
    if ((isBook || isAudiobook) && item.subjects != null && item.subjects!.isNotEmpty) {
      return Tooltip(
        message: item.subjects!.join(', '),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.accentColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            item.subjects![0],
            style: const TextStyle(
              color: AppTheme.textPrimary, 
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else if (!isBook && !isAudiobook && item.voteAverage != null && item.voteAverage! > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getScoreColor(item.voteAverage!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star,
              color: Colors.white,
              size: 12,
            ),
            const SizedBox(width: 2),
            Text(
              item.voteAverage!.toStringAsFixed(1),
              style: const TextStyle(
                color: AppTheme.textPrimary, 
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }

  // Helper to get color based on rating score
  Color _getScoreColor(double score) {
    if (score >= 8) return const Color(0xFF1DB954); // High score: Spotify green
    if (score >= 6) return const Color(0xFF1976D2); // Medium score: Blue
    if (score >= 4) return const Color(0xFFFFA000); // Lower score: Amber
    return const Color(0xFFE53935);                 // Poor score: Red
  }
}

// Control for library/saved status
class _LibraryControls extends StatelessWidget {
  final bool isInLibrary;
  final VoidCallback? onToggleLibrary;

  const _LibraryControls({
    Key? key,
    required this.isInLibrary,
    required this.onToggleLibrary,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isInLibrary ? AppTheme.primaryColor.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconButton(
        icon: Icon(
          MediaActionIcons.getFavoriteIcon(isInLibrary),
          color: MediaActionIcons.getFavoriteColor(isInLibrary),
          size: 22,
        ),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
        onPressed: onToggleLibrary,
        tooltip: isInLibrary ? 'Remove from Favorites' : 'Add to Favorites',
      ),
    );
  }
}

// Control for watchlist status
class _WatchlistControls extends StatelessWidget {
  final bool isInWatchlist;
  final VoidCallback? onAddToWatchlist;

  const _WatchlistControls({
    Key? key,
    required this.isInWatchlist,
    required this.onAddToWatchlist,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isInWatchlist ? AppTheme.watchlistColor.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconButton(
        icon: Icon(
          MediaActionIcons.getWatchlistIcon(isInWatchlist),
          color: MediaActionIcons.getWatchlistColor(isInWatchlist),
          size: 22,
        ),
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(),
        onPressed: onAddToWatchlist,
        tooltip: isInWatchlist ? 'Remove from Watchlist' : 'Add to Watchlist',
      ),
    );
  }
}

// Controls for providing feedback
class _FeedbackControls extends StatelessWidget {
  final VoidCallback? onLike;
  final VoidCallback? onDislike;
  final VoidCallback? onAddToFavorites;
  final bool isSaved;

  const _FeedbackControls({
    Key? key,
    this.onLike,
    this.onDislike,
    this.onAddToFavorites,
    this.isSaved = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onLike != null)
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              icon: Icon(
                MediaActionIcons.getLikeIcon(false), // Assume not liked for now
                color: AppTheme.textPrimary, // Keep original color for now
                size: 20,
              ),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: onLike,
              tooltip: 'Like',
            ),
          ),
        if (onDislike != null)
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              icon: Icon(
                MediaActionIcons.getDislikeIcon(),
                color: AppTheme.textPrimary, // Keep original color for now
                size: 20,
              ),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: onDislike,
              tooltip: 'Dislike',
            ),
          ),
        if (onAddToFavorites != null)
          Container(
            decoration: BoxDecoration(
              color: isSaved ? AppTheme.favoriteColor.withOpacity(0.2) : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              icon: Icon(
                MediaActionIcons.getFavoriteIcon(isSaved),
                color: MediaActionIcons.getFavoriteColor(isSaved),
                size: 20,
              ),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: onAddToFavorites,
              tooltip: isSaved ? 'Remove from Favorites' : 'Add to Favorites',
            ),
          ),
      ],
    );
  }
} 