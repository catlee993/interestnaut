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
      // Determine if this action will move the item to a different category
      final willMoveItem = _willActionMoveItem(item, action);
      String? moveToCategory;
      
      if (willMoveItem) {
        moveToCategory = _getTargetCategory(action, item);
      }

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
            // When removing favorite, revert to original state (likely skipped)
            await _updateRecommendationStatus(mediaItemId, 'skipped');
          } else {
            await _db.addToFavorites(mediaItemId);
            // Favorite clears dislike and skip by setting to liked
            await _updateRecommendationStatus(mediaItemId, 'liked');
          }
          break;
        case 'liked':
          final isLiked = _isItemInCategory(item, 'liked');
          if (isLiked) {
            // When unliking, check if item should revert to skipped
            await _updateRecommendationStatus(mediaItemId, await _getRevertStatus(mediaItemId, 'liked'));
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
            // When removing from watchlist, revert to original state if no other actions
            await _updateRecommendationStatus(mediaItemId, await _getRevertStatus(mediaItemId, 'watchlisted'));
          } else {
            await _db.addToWatchlist(mediaItemId);
            // Watchlist clears dislike and skip but keeps item accessible
            await _updateRecommendationStatus(mediaItemId, 'pending');
          }
          break;
        case 'disliked':
          final isDisliked = _isItemInCategory(item, 'disliked');
          if (isDisliked) {
            // When removing dislike, revert to skipped (most items were originally skipped)
            await _updateRecommendationStatus(mediaItemId, 'skipped');
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
            // Skip clears favorites and watchlist 
            await _db.removeFromFavorites(mediaItemId);
            await _db.removeFromWatchlist(mediaItemId);
          }
          break;
      }

      // Refresh all data to update the UI
      await _loadData();

      // Show toast if item moved to different category
      if (willMoveItem && moveToCategory != null && mounted) {
        _showMoveToast(item.title ?? 'Item', moveToCategory);
      }
    } catch (e) {
      debugPrint('Error handling item action: $e');
    }
  }

  bool _willActionMoveItem(MediaSuggestion item, String action) {
    // Check if the action will move the item away from current selected category
    final isCurrentlyInSelectedCategory = _isItemInCategory(item, _selectedCategory);
    
    if (!isCurrentlyInSelectedCategory) {
      return false; // Item is not in current view anyway
    }

    // Determine if action will remove item from current category
    switch (action) {
      case 'favorited':
        final isFavorited = _isItemInCategory(item, 'favorited');
        // Will move if: adding to favorited OR removing from favorited and currently viewing favorited
        if (!isFavorited) {
          return _selectedCategory != 'favorited'; // Adding to favorited when not viewing favorited
        } else {
          return _selectedCategory == 'favorited'; // Removing from favorited when viewing favorited
        }
      case 'liked':
        final isLiked = _isItemInCategory(item, 'liked');
        if (!isLiked) {
          return _selectedCategory != 'liked'; // Adding to liked when not viewing liked
        } else {
          return _selectedCategory == 'liked'; // Removing from liked when viewing liked
        }
      case 'watchlisted':
        final isWatchlisted = _isItemInCategory(item, 'watchlisted');
        if (!isWatchlisted) {
          return _selectedCategory != 'watchlisted'; // Adding to watchlist when not viewing watchlist
        } else {
          return _selectedCategory == 'watchlisted'; // Removing from watchlist when viewing watchlist
        }
      case 'disliked':
        final isDisliked = _isItemInCategory(item, 'disliked');
        if (!isDisliked) {
          return _selectedCategory != 'disliked'; // Adding to disliked when not viewing disliked
        } else {
          return _selectedCategory == 'disliked'; // Removing from disliked when viewing disliked
        }
      case 'skipped':
        final isSkipped = _isItemInCategory(item, 'skipped');
        if (!isSkipped) {
          return _selectedCategory != 'skipped'; // Adding to skipped when not viewing skipped
        } else {
          return _selectedCategory == 'skipped'; // Removing from skipped when viewing skipped
        }
      default:
        return false;
    }
  }

  String? _getTargetCategory(String action, MediaSuggestion item) {
    // Show where the item is moving TO when it's being added to a new category
    switch (action) {
      case 'favorited': 
        return !_isItemInCategory(item, 'favorited') ? 'Favorited' : null;
      case 'liked': 
        return !_isItemInCategory(item, 'liked') ? 'Liked' : null;
      case 'watchlisted': 
        return !_isItemInCategory(item, 'watchlisted') ? AppTheme.getMediaListName(_currentMediaType) : null;
      case 'disliked': 
        return !_isItemInCategory(item, 'disliked') ? 'Disliked' : null;
      case 'skipped': 
        return !_isItemInCategory(item, 'skipped') ? 'Skipped' : null;
      default: return null;
    }
  }

  void _showMoveToast(String itemTitle, String targetCategory) {
    if (!mounted) return;
    
    // Show toast WITHOUT closing drawer - use root navigator to appear above drawer
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"${itemTitle.length > 30 ? '${itemTitle.substring(0, 30)}...' : itemTitle}" moved to $targetCategory',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        backgroundColor: Colors.grey[800],
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 60, left: 16, right: 16, bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Determine what status to revert to when removing a reaction
  /// Returns 'skipped' if item has no other active states, 'pending' otherwise
  Future<String> _getRevertStatus(int mediaItemId, String removingAction) async {
    try {
      // Check current states after the action we're removing
      final isFavorited = await _db.isInFavorites(mediaItemId);
      final isInWatchlist = await _db.isInWatchlist(mediaItemId);
      
      // If removing liked and item is still favorited or in watchlist, keep as pending
      if (removingAction == 'liked' && (isFavorited || isInWatchlist)) {
        return 'pending';
      }
      
      // If removing watchlisted and item is still favorited or liked, keep as pending  
      if (removingAction == 'watchlisted') {
        final isCurrentlyLiked = _isItemInCategory(
          _getCurrentItems().firstWhere((item) => item.mediaItemId == mediaItemId, 
            orElse: () => _getCurrentItems().first), 'liked'
        );
        if (isFavorited || isCurrentlyLiked) {
          return 'pending';
        }
      }
      
      // If no other active states, revert to skipped (original state for most items)
      return 'skipped';
    } catch (e) {
      debugPrint('Error determining revert status: $e');
      // Default to skipped if we can't determine states
      return 'skipped';
    }
  }

  Future<void> _updateRecommendationStatus(int mediaItemId, String status) async {
    try {
      debugPrint('🔄 Updating recommendation status for media item $mediaItemId to $status');
      
      // First, find the existing recommendation record for this media item
      final allSuggestions = await _db.getAllMediaSuggestions(_currentMediaType);
      final existingRecommendation = allSuggestions.firstWhere(
        (suggestion) => suggestion.mediaItemId == mediaItemId,
        orElse: () => MediaSuggestion(
          id: 0,
          query: 'User action',
          mediaType: _currentMediaType,
          mediaId: 'temp_user_action_${DateTime.now().millisecondsSinceEpoch}',
          status: SuggestionStatus.pending,
        ),
      );

      if (existingRecommendation.id > 0) {
        // Update existing recommendation
        debugPrint('📝 Found existing recommendation (ID: ${existingRecommendation.id}), updating status to $status');
        
        final newStatus = SuggestionStatus.values.firstWhere(
          (s) => s.toString().split('.').last == status,
          orElse: () => SuggestionStatus.pending,
        );
        
        final success = await _db.updateMediaSuggestionStatus(existingRecommendation.id, newStatus);
        if (success) {
          debugPrint('✅ Successfully updated recommendation status to $status for media item $mediaItemId');
        } else {
          debugPrint('❌ Failed to update recommendation status for media item $mediaItemId');
        }
      } else {
        // Create new recommendation if none exists
        debugPrint('💡 No existing recommendation found, creating new one with status $status');
        
        final suggestion = MediaSuggestion(
          mediaItemId: mediaItemId,
          query: 'User action',
          mediaType: _currentMediaType,
          mediaId: 'user_action_${_currentMediaType}_${DateTime.now().millisecondsSinceEpoch}',
          status: SuggestionStatus.values.firstWhere(
            (s) => s.toString().split('.').last == status,
            orElse: () => SuggestionStatus.pending,
          ),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        try {
          await _db.saveMediaSuggestion(suggestion);
          debugPrint('✅ Successfully created new recommendation with status $status for media item $mediaItemId');
        } catch (constraintError) {
          if (constraintError.toString().contains('UNIQUE constraint failed')) {
            debugPrint('⚠️ Recommendation already exists for media item $mediaItemId, this is expected');
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error updating recommendation status: $e');
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