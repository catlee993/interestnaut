import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/sqlite_db.dart';
import 'media_action_icons.dart';
import '../../models.dart'; // For MediaDisplayHelper

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
          if (_currentLiked) {
            // Like clears favorite and dislike
            _currentFavorited = false;
            _currentDisliked = false;
          }
          break;
        case 'dislike':
          _currentDisliked = !_currentDisliked;
          if (_currentDisliked) {
            // Dislike clears all other states
            _currentLiked = false;
            _currentFavorited = false;
            _currentWatchlisted = false;
          }
          break;
        case 'favorite':
          _currentFavorited = !_currentFavorited;
          if (_currentFavorited) {
            // Favorite clears like and dislike
            _currentLiked = false;
            _currentDisliked = false;
          }
          break;
        case 'watchlist':
          _currentWatchlisted = !_currentWatchlisted;
          if (_currentWatchlisted) {
            // Any positive action clears dislike
            _currentDisliked = false;
          }
          break;
      }
      
      // If no positive states remain, default to skipped
      if (!_currentLiked && !_currentFavorited && !_currentWatchlisted && !_currentDisliked) {
        // No reactions left - trigger clear_all action to set to skipped
        Future.delayed(Duration.zero, () {
          widget.onAction('clear_all');
        });
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
        height: MediaQuery.of(context).size.height * 0.65, // Increased from 0.55 to 0.65 (10% more height)
        margin: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A), // Very dark background to match select from history modal
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: () {
                      final displayInfo = MediaDisplayHelper.resolveDisplayInfo(
                        title: widget.title,
                        artist: widget.artist,
                        fallbackTitle: 'Unknown Media',
                      );
                      return Text(
                        displayInfo.displayTitle,
                        style: AppTheme.mediaTitleStyle.copyWith(
                          fontSize: 18,
                          letterSpacing: 2.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      );
                    }(),
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  // Status text in interestnaut style
                  _buildStatusText(),
                ],
              ),
            ),
            
            // Media display area component - flexible to fit available space
            Expanded(
              flex: 3, // Takes most of the available space
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03), // Match other components
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                ),
                child: Container(
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
                            child: widget.coverArtUrl != null && widget.coverArtUrl!.isNotEmpty
                                ? Image.network(
                                    widget.coverArtUrl!,
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
                              if (widget.description != null && widget.description!.isNotEmpty) ...[
                                Text(
                                  widget.description!,
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
              ),
            ),
            
            // Developer/themes section - flexible for remaining space
            Expanded(
              flex: 1, // Takes less space than media display
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Row(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate expected height for artist + themes + spacing
                          final hasArtist = widget.artist != null && widget.artist!.isNotEmpty;
                          final hasThemes = widget.themes != null && widget.themes!.isNotEmpty;
                          
                          // Use available height efficiently
                          final availableHeight = constraints.maxHeight - 24; // Account for padding
                          final shouldUseScrolling = availableHeight > 0; // Always prepare for scrolling if needed
                          
                          final contentWidget = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min, // Important: only take needed space
                            children: [
                              // Artist/Creator - only show if we have a subtitle (not used as title)
                              () {
                                final displayInfo = MediaDisplayHelper.resolveDisplayInfo(
                                  title: widget.title,
                                  artist: widget.artist,
                                  fallbackTitle: 'Unknown Media',
                                );
                                
                                if (displayInfo.hasSubtitle) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
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
                                              text: displayInfo.displaySubtitle!,
                                              style: AppTheme.bodyStyle.copyWith(
                                                fontSize: 12,
                ),
              ),
            ],
          ),
                                      ),
                                      const SizedBox(height: AppTheme.spacingXS),
                                    ],
                                  );
                                } else {
                                  return const SizedBox.shrink();
                                }
                              }(),
                              
                              // Themes with proper text wrapping
                              if (hasThemes) ...[
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
                                          height: 1.4, // Better line spacing for readability
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                          
                          // Return with scrolling if content exceeds available space
                          return SingleChildScrollView(
                            child: contentWidget,
                          );
                        },
                      ),
                    ),
                  ],
                ),
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
            
            // Centralized action icons at bottom - fixed height
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  MediaActionButton(
                    type: MediaActionType.like,
                    isActive: _currentLiked,
                    onPressed: () => _handleAction('like'),
                    iconSize: 28,
                  ),
                  MediaActionButton(
                    type: MediaActionType.dislike,
                    isActive: _currentDisliked,
                    onPressed: () => _handleAction('dislike'),
                    iconSize: 28,
                  ),
                  MediaActionButton(
                    type: MediaActionType.favorite,
                    isActive: _currentFavorited,
                    onPressed: () => _handleAction('favorite'),
                    iconSize: 28,
                  ),
                  MediaActionButton(
                    type: MediaActionType.watchlist,
                    isActive: _currentWatchlisted,
                    onPressed: () => _handleAction('watchlist'),
                    iconSize: 28,
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


} 