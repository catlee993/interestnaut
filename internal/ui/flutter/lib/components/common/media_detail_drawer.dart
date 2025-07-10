import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/sqlite_db.dart';

/// Reusable media display area component with side-by-side layout
class MediaDisplayArea extends StatelessWidget {
  final String? coverArtUrl;
  final String? description;
  final String mediaType;

  const MediaDisplayArea({
    Key? key,
    this.coverArtUrl,
    this.description,
    required this.mediaType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), // Much darker gray background
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.3,
        padding: const EdgeInsets.all(AppTheme.spacingSM),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Static image - 1/3 of width
            Container(
              width: MediaQuery.of(context).size.width * 0.95 * 0.33 * 0.8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                  child: coverArtUrl != null && coverArtUrl!.isNotEmpty
                      ? Image.network(
                          coverArtUrl!,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholderIcon(),
                        )
                      : _buildPlaceholderIcon(),
                ),
              ),
            ),
            
            const SizedBox(width: AppTheme.spacingMD),
            
            // Scrollable summary area - 2/3 of width
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description != null && description!.isNotEmpty) ...[
                      Text(
                        description!,
                        style: AppTheme.bodyStyle.copyWith(
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Icon(
      AppTheme.getMediaIcon(mediaType),
      size: 60,
      color: AppTheme.textSecondary,
    );
  }
}

/// Compact media detail drawer with side-by-side image and summary layout
class MediaDetailDrawer extends StatefulWidget {
  final String title;
  final String? artist;
  final String? description;
  final String? coverArtUrl;
  final String? themes;
  final String mediaType;
  final bool hasLiked;
  final bool hasDisliked;
  final bool hasFavorited;
  final bool isInWatchlist;
  final bool hasSkipped;
  final Function(String) onAction;

  const MediaDetailDrawer({
    Key? key,
    required this.title,
    this.artist,
    this.description,
    this.coverArtUrl,
    this.themes,
    required this.mediaType,
    required this.hasLiked,
    required this.hasDisliked,
    required this.hasFavorited,
    required this.isInWatchlist,
    required this.hasSkipped,
    required this.onAction,
  }) : super(key: key);

  @override
  State<MediaDetailDrawer> createState() => _MediaDetailDrawerState();
}

class _MediaDetailDrawerState extends State<MediaDetailDrawer> {
  final SQLiteDatabase _db = SQLiteDatabase();
  
  late bool _currentLiked;
  late bool _currentDisliked;
  late bool _currentFavorited;
  late bool _currentWatchlisted;

  @override
  void initState() {
    super.initState();
    _currentLiked = widget.hasLiked;
    _currentDisliked = widget.hasDisliked;
    _currentFavorited = widget.hasFavorited;
    _currentWatchlisted = widget.isInWatchlist;
  }

  void _handleAction(String action) {
    setState(() {
      switch (action) {
        case 'like':
          _currentLiked = !_currentLiked;
          if (_currentLiked) _currentDisliked = false;
          break;
        case 'dislike':
          _currentDisliked = !_currentDisliked;
          if (_currentDisliked) {
            _currentLiked = false;
            _currentFavorited = false;
            _currentWatchlisted = false;
          }
          break;
        case 'favorite':
          _currentFavorited = !_currentFavorited;
          break;
        case 'watchlist':
          _currentWatchlisted = !_currentWatchlisted;
          break;
      }
    });
    
    widget.onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Print current state to understand heart color issue
    print('MediaDetailDrawer Debug: favorited=$_currentFavorited, watchlisted=$_currentWatchlisted, title=${widget.title}');
    
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.55,
        margin: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Title and status at top
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTheme.mediaTitleStyle.copyWith(fontSize: 18),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  // Status text in interestnaut style
                  _buildStatusText(),
                ],
              ),
            ),
            
            // Media display area component
            MediaDisplayArea(
              coverArtUrl: widget.coverArtUrl,
              description: widget.description,
              mediaType: widget.mediaType,
            ),
            
            // Developer/themes section - exact same structure as title
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Artist/Creator
                        if (widget.artist != null && widget.artist!.isNotEmpty) ...[
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${_getCreatorLabel().toUpperCase()}: ',
                                  style: AppTheme.bodyStyle.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                TextSpan(
                                  text: widget.artist!,
                                  style: AppTheme.bodyStyle.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingXS),
                        ],
                        
                        // Themes
                        if (widget.themes != null && widget.themes!.isNotEmpty) ...[
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'THEMES: ',
                                  style: AppTheme.bodyStyle.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                TextSpan(
                                  text: widget.themes!,
                                  style: AppTheme.bodyStyle.copyWith(
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Divider line matching display area border
            Container(
              margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
              height: 1,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
              ),
            ),
            
            // Spacer to push controls to bottom
            const Spacer(),
            
            // Simple action icons at bottom - no square wrappers
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSimpleActionIcon(
                    icon: Icons.thumb_up,
                    isActive: _currentLiked,
                    activeColor: AppTheme.likeColor,
                    onPressed: () => _handleAction('like'),
                  ),
                  _buildSimpleActionIcon(
                    icon: Icons.thumb_down,
                    isActive: _currentDisliked,
                    activeColor: AppTheme.dislikeColor,
                    onPressed: () => _handleAction('dislike'),
                  ),
                  _buildSimpleActionIcon(
                    icon: Icons.favorite,
                    isActive: _currentFavorited, // Only active when favorited, not just watchlisted
                    activeColor: AppTheme.favoriteColor,
                    onPressed: () => _handleAction('favorite'),
                  ),
                  _buildSimpleActionIcon(
                    icon: _currentWatchlisted ? Icons.bookmark_added : Icons.bookmark_add,
                    isActive: _currentWatchlisted,
                    activeColor: AppTheme.watchlistColor,
                    onPressed: () => _handleAction('watchlist'),
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
      AppTheme.getMediaIcon(widget.mediaType),
      size: 60,
      color: AppTheme.textSecondary,
    );
  }

  String _getCreatorLabel() {
    switch (widget.mediaType) {
      case 'video_game':
        return 'Developer';
      case 'movie':
        return 'Director';
      case 'tv_show':
        return 'Creator';
      case 'book':
        return 'Author';
      case 'music':
        return 'Artist';
      default:
        return 'Creator';
    }
  }

  Widget _buildStatusText() {
    if (_currentFavorited) {
      return Text(
        'FAVORITED',
        style: AppTheme.bodyStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.favoriteColor,
        ),
      );
    } else if (_currentLiked) {
      return Text(
        'LIKED',
        style: AppTheme.bodyStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.likeColor,
        ),
      );
    } else if (_currentWatchlisted) {
      return Text(
        'WATCHLISTED',
        style: AppTheme.bodyStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.watchlistColor,
        ),
      );
    } else if (_currentDisliked) {
      return Text(
        'DISLIKED',
        style: AppTheme.bodyStyle.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.dislikeColor,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSimpleActionIcon({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Icon(
        icon,
        color: isActive ? activeColor : Colors.white60,
        size: 28,
      ),
    );
  }
} 