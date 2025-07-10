import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/sqlite_db.dart';
import '../../services/recommendation_service.dart';
import 'media_detail_drawer.dart';
import 'media_action_icons.dart';

/// Sleek screen for reviewing user's media history
/// Shows reactions for the current media type only
class MediaHistoryScreen extends StatefulWidget {
  final String initialMediaType;

  const MediaHistoryScreen({
    Key? key,
    this.initialMediaType = 'music',
  }) : super(key: key);

  @override
  State<MediaHistoryScreen> createState() => _MediaHistoryScreenState();
}

class _MediaHistoryScreenState extends State<MediaHistoryScreen> {
  final SQLiteDatabase _db = SQLiteDatabase();
  late String _currentMediaType;
  String _selectedCategory = 'favorited'; // Default to favorited

  // Map header media types to database media types
  String _mapHeaderToDbMediaType(String headerMediaType) {
    switch (headerMediaType) {
      case 'movies': return 'movie';
      case 'tv': return 'tv_show';
      case 'games': return 'video_game';
      case 'books': return 'book';
      case 'music': return 'music';
      default: return headerMediaType;
    }
  }

  List<MediaSuggestion> _likedItems = [];
  List<MediaSuggestion> _dislikedItems = [];
  List<MediaSuggestion> _favoritedItems = [];
  List<MediaSuggestion> _watchlistedItems = [];
  List<MediaSuggestion> _skippedItems = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentMediaType = _mapHeaderToDbMediaType(widget.initialMediaType);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await _db.init();

      // Load data for the current media type only - with explicit type safety
      final liked = await _db.getLikedRecommendations(_currentMediaType);
      final disliked = await _db.getDislikedRecommendations(_currentMediaType);
      final favorited = await _db.getAllFavorites(_currentMediaType);
      final watchlisted = await _db.getWatchlist(_currentMediaType);
      final skipped = await _db.getSkippedRecommendations(_currentMediaType);

      // Ensure proper List types
      _likedItems = List<MediaSuggestion>.from(liked);
      _dislikedItems = List<MediaSuggestion>.from(disliked);
      _favoritedItems = List<MediaSuggestion>.from(favorited);
      _watchlistedItems = List<MediaSuggestion>.from(watchlisted);
      _skippedItems = List<MediaSuggestion>.from(skipped);
    } catch (e) {
      debugPrint('Error loading history data: $e');
      // Set empty lists on error
      _likedItems = <MediaSuggestion>[];
      _dislikedItems = <MediaSuggestion>[];
      _favoritedItems = <MediaSuggestion>[];
      _watchlistedItems = <MediaSuggestion>[];
      _skippedItems = <MediaSuggestion>[];
    }

    setState(() => _isLoading = false);
  }

  List<MediaSuggestion> _getCurrentItems() {
    switch (_selectedCategory) {
      case 'liked': return _likedItems;
      case 'disliked': return _dislikedItems;
      case 'favorited': return _favoritedItems;
      case 'watchlisted': return _watchlistedItems;
      case 'skipped': return _skippedItems;
      default: return [];
    }
  }

  Widget _buildTextTab(String category, String label) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected 
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 2,
              width: 32,
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppTheme.primaryColor
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionableMediaCard(MediaSuggestion item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: GestureDetector(
        onTap: () => _showMediaDrawer(item),
        child: Row(
          children: [
            // Compact cover art
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: item.coverArtUrl != null && item.coverArtUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        item.coverArtUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(),
                      ),
                    )
                  : _buildPlaceholderIcon(),
            ),
            const SizedBox(width: 10),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title ?? 'Unknown',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.artist != null && item.artist!.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      item.artist!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            // Current state label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                _getCurrentStateLabel(item),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: _getCategoryColor(_selectedCategory),
                  letterSpacing: 0.8,
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Compact action buttons row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(item, 'favorited', Icons.favorite, AppTheme.favoriteColor),
                const SizedBox(width: 2),
                _buildActionButton(item, 'liked', Icons.thumb_up, AppTheme.likeColor),
                const SizedBox(width: 2),
                _buildActionButton(item, 'watchlisted', Icons.bookmark, AppTheme.watchlistColor),
                const SizedBox(width: 2),
                _buildActionButton(item, 'disliked', Icons.thumb_down, AppTheme.dislikeColor),
                const SizedBox(width: 2),
                _buildActionButton(item, 'skipped', Icons.skip_next, AppTheme.textSecondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(MediaSuggestion item, String action, IconData icon, Color color) {
    final isActive = _isItemInCategory(item, action);
    final isSkipped = action == 'skipped';
    
    return GestureDetector(
      onTap: () => _handleItemAction(item, action),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isActive && !isSkipped ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: isSkipped ? null : BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 14,
          color: isActive ? color : color.withOpacity(0.4),
        ),
      ),
    );
  }

  bool _isItemInCategory(MediaSuggestion item, String category) {
    switch (category) {
      case 'favorited': return _favoritedItems.any((i) => i.id == item.id);
      case 'liked': return _likedItems.any((i) => i.id == item.id);
      case 'watchlisted': return _watchlistedItems.any((i) => i.id == item.id);
      case 'disliked': return _dislikedItems.any((i) => i.id == item.id);
      case 'skipped': return _skippedItems.any((i) => i.id == item.id);
      default: return false;
    }
  }

  String _getCurrentStateLabel(MediaSuggestion item) {
    switch (_selectedCategory) {
      case 'favorited': return 'FAVORITED';
      case 'liked': return 'LIKED';
      case 'watchlisted': return AppTheme.getMediaListName(_currentMediaType).toUpperCase();
      case 'disliked': return 'DISLIKED';
      case 'skipped': return 'SKIPPED';
      default: return '';
    }
  }

  Future<void> _handleItemAction(MediaSuggestion item, String action) async {
    try {
      // Get or create media item
      int mediaItemId = await _db.createOrGetMediaItem(
        title: item.title ?? 'Unknown',
        mediaType: _currentMediaType,
        primaryCreator: item.artist ?? '',
        vectorMediaId: item.mediaId,
        coverArtUrl: item.coverArtUrl,
        description: item.description,
        themes: item.themes,
      );

      // Handle state changes based on action
      switch (action) {
        case 'favorited':
          final isFavorited = _isItemInCategory(item, 'favorited');
          if (isFavorited) {
            await _db.removeFromFavorites(mediaItemId);
          } else {
            await _db.addToFavorites(mediaItemId);
            // Favorite clears dislike
            await _updateRecommendationStatus(mediaItemId, 'liked');
          }
          break;
        case 'liked':
          final isLiked = _isItemInCategory(item, 'liked');
          if (isLiked) {
            await _updateRecommendationStatus(mediaItemId, 'pending');
          } else {
            await _updateRecommendationStatus(mediaItemId, 'liked');
            // Like clears favorite
            await _db.removeFromFavorites(mediaItemId);
          }
          break;
        case 'watchlisted':
          final isWatchlisted = _isItemInCategory(item, 'watchlisted');
          if (isWatchlisted) {
            await _db.removeFromWatchlist(mediaItemId);
          } else {
            await _db.addToWatchlist(mediaItemId);
            // Watchlist clears dislike
            await _updateRecommendationStatus(mediaItemId, 'pending');
          }
          break;
        case 'disliked':
          final isDisliked = _isItemInCategory(item, 'disliked');
          if (isDisliked) {
            await _updateRecommendationStatus(mediaItemId, 'pending');
          } else {
            await _updateRecommendationStatus(mediaItemId, 'disliked');
            // Dislike clears all other states
            await _db.removeFromFavorites(mediaItemId);
            await _db.removeFromWatchlist(mediaItemId);
          }
          break;
        case 'skipped':
          final isSkipped = _isItemInCategory(item, 'skipped');
          if (isSkipped) {
            await _updateRecommendationStatus(mediaItemId, 'pending');
          } else {
            await _updateRecommendationStatus(mediaItemId, 'skipped');
          }
          break;
      }

      // Refresh all data to update the UI
      await _loadData();
    } catch (e) {
      debugPrint('Error handling item action: $e');
    }
  }

  Future<void> _updateRecommendationStatus(int mediaItemId, String status) async {
    try {
      // Create a MediaSuggestion to save/update the recommendation
      final suggestion = MediaSuggestion(
        id: 0, // Will be set by database if new
        mediaItemId: mediaItemId,
        query: 'User action',
        mediaType: _currentMediaType,
        status: SuggestionStatus.values.firstWhere(
          (s) => s.toString().split('.').last == status,
          orElse: () => SuggestionStatus.pending,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _db.saveMediaSuggestion(suggestion);
    } catch (e) {
      debugPrint('Error updating recommendation status: $e');
    }
  }

  Widget _buildPlaceholderIcon() {
    return Icon(
      AppTheme.getMediaIcon(_currentMediaType),
      size: 20,
      color: AppTheme.textSecondary,
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'liked': return Icons.thumb_up;
      case 'disliked': return Icons.thumb_down;
      case 'favorited': return Icons.favorite;
      case 'watchlisted': return Icons.bookmark;
      case 'skipped': return Icons.skip_next;
      default: return Icons.help;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'liked': return AppTheme.likeColor;
      case 'disliked': return AppTheme.dislikeColor;
      case 'favorited': return AppTheme.favoriteColor;
      case 'watchlisted': return AppTheme.watchlistColor;
      case 'skipped': return AppTheme.textSecondary;
      default: return AppTheme.textSecondary;
    }
  }

  Future<void> _showMediaDrawer(MediaSuggestion item) async {
    // Get comprehensive status from database
    final status = await _db.getMediaItemStatusByProperties(
      title: item.title ?? 'Unknown',
      mediaType: _currentMediaType,
      primaryCreator: item.artist ?? '',
    );

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enableDrag: true,
        isDismissible: true,
        barrierColor: Colors.black54,
        builder: (context) => GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {},
              child: MediaDetailDrawer(
                title: item.title ?? 'Unknown',
                artist: item.artist,
                description: item.description,
                themes: item.themes,
                coverArtUrl: item.coverArtUrl,
                mediaType: _currentMediaType,
                hasLiked: status['hasLiked'] as bool? ?? false,
                hasDisliked: status['hasDisliked'] as bool? ?? false,
                hasFavorited: status['hasFavorited'] as bool? ?? false,
                isInWatchlist: status['isInWatchlist'] as bool? ?? false,
                hasSkipped: status['hasSkipped'] as bool? ?? false,
                onAction: (action) async {
                  // Handle action but don't close drawer
                  await _handleDrawerAction(action, item, status['mediaItemId'] as int?);
                },
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _handleDrawerAction(String action, MediaSuggestion item, int? mediaItemId) async {
    try {
      // Simple action handling - just refresh the data
      // The drawer actions are handled by the MediaDetailDrawer itself
      // We just need to refresh our local data
      await _loadData();
    } catch (e) {
      debugPrint('Error handling drawer action: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      margin: const EdgeInsets.only(top: 20),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header with drag handle and title
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 10),
                // Title with media icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      AppTheme.getMediaIcon(_currentMediaType),
                      color: AppTheme.primaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${AppTheme.getMediaDisplayName(_currentMediaType)} History',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1.0,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Clean text tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTextTab('favorited', 'Favorited'),
                _buildTextTab('liked', 'Liked'),
                _buildTextTab('watchlisted', AppTheme.getMediaListName(_currentMediaType)),
                _buildTextTab('disliked', 'Disliked'),
                _buildTextTab('skipped', 'Skipped'),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Content list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _getCurrentItems().isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _getCategoryIcon(_selectedCategory),
                              size: 48,
                              color: AppTheme.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No ${_selectedCategory} ${AppTheme.getMediaPluralDisplayName(_currentMediaType).toLowerCase()} yet',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        itemCount: _getCurrentItems().length,
                        itemBuilder: (context, index) => _buildActionableMediaCard(_getCurrentItems()[index]),
                      ),
          ),
        ],
      ),
    );
  }
}