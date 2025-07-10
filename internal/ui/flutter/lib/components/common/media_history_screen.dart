import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/sqlite_db.dart';
import '../../services/recommendation_service.dart'; // Import for MediaSuggestion
import '../../models.dart';
import 'media_detail_drawer.dart';
import 'media_section_wrapper.dart';

/// Screen for reviewing all user's past media interactions
/// Provides access to liked, disliked, favorited, and watchlisted items
class MediaHistoryScreen extends StatefulWidget {
  final String initialMediaType;

  const MediaHistoryScreen({
    Key? key,
    this.initialMediaType = 'music',
  }) : super(key: key);

  @override
  State<MediaHistoryScreen> createState() => _MediaHistoryScreenState();
}

class _MediaHistoryScreenState extends State<MediaHistoryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late TabController _mediaTypeController;
  final SQLiteDatabase _db = SQLiteDatabase();

  final List<String> _mediaTypes = ['music', 'movie', 'tv_show', 'book', 'video_game'];
  late String _currentMediaType;

  // Map header media types to database media types
  String _mapHeaderToDbMediaType(String headerMediaType) {
    switch (headerMediaType) {
      case 'movies': return 'movie';
      case 'tv': return 'tv_show';
      case 'games': return 'video_game';
      case 'books': return 'book';
      case 'music': return 'music';
      default: return headerMediaType; // fallback to original
    }
  }

  Map<String, List<MediaSuggestion>> _likedItems = {};
  Map<String, List<MediaSuggestion>> _dislikedItems = {};
  Map<String, List<MediaSuggestion>> _favoritedItems = {};
  Map<String, List<MediaSuggestion>> _watchlistedItems = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Convert header media type to database media type
    _currentMediaType = _mapHeaderToDbMediaType(widget.initialMediaType);
    _tabController = TabController(length: 4, vsync: this);
    
    // Ensure we have a valid initial index for the media type controller
    int initialMediaIndex = _mediaTypes.indexOf(_currentMediaType);
    if (initialMediaIndex == -1) {
      // If the media type isn't found, default to the first one (music)
      initialMediaIndex = 0;
      _currentMediaType = _mediaTypes[0];
    }
    
    _mediaTypeController = TabController(
      length: _mediaTypes.length,
      vsync: this,
      initialIndex: initialMediaIndex,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mediaTypeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      await _db.init();

      for (final mediaType in _mediaTypes) {
        final liked = await _db.getLikedRecommendations(mediaType);
        final disliked = await _db.getDislikedRecommendations(mediaType);
        final favorited = await _db.getAllFavorites(mediaType);
        final watchlisted = await _db.getWatchlist(mediaType);

        _likedItems[mediaType] = liked;
        _dislikedItems[mediaType] = disliked;
        _favoritedItems[mediaType] = favorited;
        _watchlistedItems[mediaType] = watchlisted;
      }
    } catch (e) {
      debugPrint('Error loading history data: $e');
    }

    setState(() => _isLoading = false);
  }

  void _onMediaTypeChanged() {
    setState(() {
      _currentMediaType = _mediaTypes[_mediaTypeController.index];
    });
  }

  Widget _buildMediaCard(MediaSuggestion item, String category) {
    return GestureDetector(
      onTap: () => _showMediaDrawer(item, category),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border: Border.all(
            color: _getCategoryColor(category).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Cover art placeholder
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
              child: item.coverArtUrl != null && item.coverArtUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                      child: Image.network(
                        item.coverArtUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholderIcon(),
                      ),
                    )
                  : _buildPlaceholderIcon(),
            ),
            const SizedBox(width: AppTheme.spacingMD),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title ?? 'Unknown',
                    style: AppTheme.mediaTitleStyle.copyWith(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.artist != null && item.artist!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.artist!,
                      style: AppTheme.mediaArtistStyle.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            // Status indicator
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSM,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: _getCategoryColor(category).withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getCategoryIcon(category),
                    size: 16,
                    color: _getCategoryColor(category),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getCategoryLabel(category),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getCategoryColor(category),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Icon(
      AppTheme.getMediaIcon(_currentMediaType),
      size: 30,
      color: AppTheme.textSecondary,
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'liked': return AppTheme.likeColor;
      case 'disliked': return AppTheme.dislikeColor;
      case 'favorited': return AppTheme.favoriteColor;
      case 'watchlisted': return AppTheme.watchlistColor;
      default: return AppTheme.textSecondary;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'liked': return Icons.thumb_up;
      case 'disliked': return Icons.thumb_down;
      case 'favorited': return Icons.favorite;
      case 'watchlisted': return Icons.bookmark;
      default: return Icons.circle;
    }
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'liked': return 'Liked';
      case 'disliked': return 'Disliked';
      case 'favorited': return 'Favorited';
      case 'watchlisted': return AppTheme.getMediaListName(_currentMediaType);
      default: return category;
    }
  }

  void _showMediaDrawer(MediaSuggestion item, String category) {
    // Determine current status based on category
    final hasLiked = category == 'liked';
    final hasDisliked = category == 'disliked';
    final hasFavorited = category == 'favorited';
    final isInWatchlist = category == 'watchlisted';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaDetailDrawer(
        title: item.title ?? 'Unknown',
        artist: item.artist,
        description: item.description,
        coverArtUrl: item.coverArtUrl,
        themes: item.themes,
        mediaType: item.mediaType,
        hasLiked: hasLiked,
        hasDisliked: hasDisliked,
        hasFavorited: hasFavorited,
        isInWatchlist: isInWatchlist,
        hasSkipped: false,
        onAction: (action) async {
          // Handle the action and refresh data
          await _handleDrawerAction(item, action);
          _loadData(); // Refresh the data
        },
      ),
    );
  }

  Future<void> _handleDrawerAction(MediaSuggestion item, String action) async {
    try {
      // This would use similar logic to MediaSectionWrapper._handleDrawerAction
      // For now, just print the action
      debugPrint('Action $action for item: ${item.title}');
      
      // TODO: Implement the actual database updates based on action
      // This would involve updating recommendations, favorites, watchlist tables
      
    } catch (e) {
      debugPrint('Error handling drawer action: $e');
    }
  }

  Widget _buildTabContent(String category) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    List<MediaSuggestion> items;
    switch (category) {
      case 'liked':
        items = _likedItems[_currentMediaType] ?? [];
        break;
      case 'disliked':
        items = _dislikedItems[_currentMediaType] ?? [];
        break;
      case 'favorited':
        items = _favoritedItems[_currentMediaType] ?? [];
        break;
      case 'watchlisted':
        items = _watchlistedItems[_currentMediaType] ?? [];
        break;
      default:
        items = [];
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getCategoryIcon(category),
              size: 64,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              'No ${_getCategoryLabel(category).toLowerCase()} ${AppTheme.getMediaPluralDisplayName(_currentMediaType).toLowerCase()} yet',
              style: AppTheme.bodyStyle.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildMediaCard(items[index], category),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: AppTheme.wideLibraryHeaderMedium('YOUR HISTORY'),
        centerTitle: true,
        foregroundColor: AppTheme.textPrimary,
      ),
      body: Column(
        children: [
          // Media type tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            ),
            child: TabBar(
              controller: _mediaTypeController,
              isScrollable: true,
              indicator: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
              ),
              indicatorPadding: const EdgeInsets.all(4),
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: AppTheme.headerSelectorStyle.copyWith(fontSize: 12),
              onTap: (_) => _onMediaTypeChanged(),
              tabs: _mediaTypes.map((type) => Tab(
                text: AppTheme.getMediaHeaderDisplayName(type),
              )).toList(),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingMD),
          
          // Category tabs (Liked, Disliked, Favorited, Watchlisted)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
              ),
              indicatorPadding: const EdgeInsets.all(4),
              labelColor: AppTheme.accentColor,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: AppTheme.headerSelectorStyle.copyWith(fontSize: 12),
              tabs: const [
                Tab(text: 'LIKED'),
                Tab(text: 'DISLIKED'),
                Tab(text: 'FAVORITED'),
                Tab(text: 'WATCHLISTED'),
              ],
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingMD),
          
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabContent('liked'),
                _buildTabContent('disliked'),
                _buildTabContent('favorited'),
                _buildTabContent('watchlisted'),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 