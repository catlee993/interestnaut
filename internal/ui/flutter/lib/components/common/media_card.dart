import 'package:flutter/material.dart';
import '../../models.dart';
import '../../theme.dart';

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
    final hasPoster = item.posterPath != null && item.posterPath!.isNotEmpty;
    final isMovie = item.mediaType == 'movie';
    final isBook = item.mediaType == 'book';
    final isTV = item.mediaType == 'tv';
    final isGame = item.mediaType == 'game';
    final isAudiobook = item.mediaType == 'audiobook';
    
    final mediaIcon = isMovie 
        ? Icons.movie 
        : isBook 
            ? Icons.menu_book 
            : isTV 
                ? Icons.tv 
                : isGame 
                    ? Icons.sports_esports
                    : Icons.headphones;

    return Card(
      elevation: 8,
      color: AppTheme.surfaceColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.2), width: 1),
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
            
            // Gradient overlay for text readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.95),  // More opaque at bottom
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.5),
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.0),
                      Colors.transparent,             // Transparent at top
                    ],
                    stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
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
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with optional tooltip for overview
                    Tooltip(
                      message: item.overview ?? '',
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
                    
                    const SizedBox(height: 4),
                    
                    // Author for books/audiobooks, Release date for others
                    if (isBook && item.author != null)
                      Text(
                        item.author!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else if (!isBook && item.releaseDate != null)
                      Text(
                        item.releaseDate!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    
                    const SizedBox(height: 12),
                    
                    // Bottom row with rating/genre and controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Rating pill or genre tag
                        _buildRatingOrGenreTag(),
                        
                        // Controls based on view mode
                        if (view == 'default')
                          Row(
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
                        else
                          // Feedback controls for watchlist/saved view
                          _FeedbackControls(
                            onLike: onLike != null ? () => onLike!(item.id) : null,
                            onDislike: onDislike != null ? () => onDislike!(item.id) : null,
                            onAddToFavorites: () => onSave(item.id),
                            isSaved: isSaved,
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
              style: TextStyle(
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
      return item.posterPath!;
    } else if (item.mediaType == 'movie' || item.mediaType == 'tv') {
      return 'https://image.tmdb.org/t/p/w500${item.posterPath}';
    } else {
      return item.posterPath!;
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
            style: TextStyle(
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
              '${item.voteAverage!.toStringAsFixed(1)}',
              style: TextStyle(
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
          isInLibrary ? Icons.favorite : Icons.favorite_border,
          color: isInLibrary ? AppTheme.primaryColor : AppTheme.textPrimary,
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
        color: isInWatchlist ? AppTheme.spotifyGreen.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconButton(
        icon: Icon(
          isInWatchlist ? Icons.playlist_add_check : Icons.playlist_add,
          color: isInWatchlist ? AppTheme.spotifyGreen : AppTheme.textPrimary,
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
                Icons.thumb_up,
                color: AppTheme.textPrimary,
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
                Icons.thumb_down,
                color: AppTheme.textPrimary,
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
              color: isSaved ? AppTheme.primaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              icon: Icon(
                isSaved ? Icons.favorite : Icons.favorite_border,
                color: isSaved ? AppTheme.primaryColor : AppTheme.textPrimary,
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