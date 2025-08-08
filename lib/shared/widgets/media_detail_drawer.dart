import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'youtube_player_platform.dart';
import '../theme/theme.dart';
import '../services/sqlite_db.dart';
import '../../core/network/grpc_client.dart'; // For Interestnaut search
import '../services/wikidata_service.dart'; // For WikidataSearchResult
import 'media_action_icons.dart';
import '../models/models.dart'; // For MediaDisplayHelper
import '../../features/music/presentation/spotify_service.dart'; // For Spotify playback
import 'standard_close_button.dart';
import 'wide_text.dart';
import 'play_selector_button.dart';

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
            // Dynamic image sizing with proportional scaling
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.95 * 0.30, // Max 30% of available width
                maxHeight: MediaQuery.of(context).size.height * 0.25, // Max 25% of screen height
                minWidth: 80, // Minimum width to ensure visibility
                minHeight: 80, // Minimum height to ensure visibility
              ),
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
                          fit: BoxFit.contain, // Proportional scaling without cropping
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPlaceholderIcon(),
                        )
                      : _buildPlaceholderIcon(),
                ),
              ),
            ),
            
            const SizedBox(width: AppTheme.spacingMD),
            
            // Scrollable summary area - flexible width with constraints
            Expanded(
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 350, // Max width for summary to prevent it from being too wide
                ),
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
  final String? genres;
  final String? youtubeId;
  final String? spotifyId;
  final String mediaType;
  final bool hasLiked;
  final bool hasDisliked;
  final bool hasFavorited;
  final bool isInWatchlist;
  final bool hasSkipped;
  final Function(String) onAction;
  final bool limitToSpotifyActions;

  const MediaDetailDrawer({
    Key? key,
    required this.title,
    this.artist,
    this.description,
    this.coverArtUrl,
    this.themes,
    this.genres,
    this.youtubeId,
    this.spotifyId,
    required this.mediaType,
    required this.hasLiked,
    required this.hasDisliked,
    required this.hasFavorited,
    required this.isInWatchlist,
    required this.hasSkipped,
    required this.onAction,
    this.limitToSpotifyActions = false,
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

  String _getReactionStatus() {
    if (_currentFavorited) return 'FAVORITED';
    if (_currentLiked) return 'LIKED';
    if (_currentWatchlisted) return _getQueueName().toUpperCase();
    if (_currentDisliked) return 'DISLIKED';
    if (widget.hasSkipped) return 'SKIPPED';
    return '';
  }

  String _getQueueName() {
    switch (widget.mediaType) {
      case 'movie':
      case 'tv_show':
        return 'Watchlist';
      case 'book':
        return 'Reading List';
      case 'music':
        return 'Playlist';
      case 'video_game':
        return 'Game Library';
      default:
        return 'Watchlist';
    }
  }

  String _getQueuedStatusText() {
    switch (widget.mediaType) {
      case 'movie':
      case 'tv_show':
        return 'WATCHLISTED';
      case 'book':
        return 'READLISTED';
      case 'music':
        return 'PLAYLISTED';
      case 'video_game':
        return 'PLAYLISTED';
      default:
        return 'WATCHLISTED';
    }
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
          if (mounted) {
            widget.onAction('clear_all');
          }
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate dynamic height based on content
              final screenHeight = MediaQuery.of(context).size.height;
              final hasDescription = widget.description != null && widget.description!.trim().isNotEmpty;
              final hasThemes = widget.themes != null && widget.themes!.trim().isNotEmpty;
              final hasGenres = widget.genres != null && widget.genres!.trim().isNotEmpty;
              final hasPlayButtons = widget.youtubeId != null || widget.spotifyId != null;
              
              // Base height for header + action buttons + margins/padding
              double baseHeight = 200; // Header (80) + Actions (60) + Margins/Padding (60)
              
              // Add height for media display area based on whether we have description
              baseHeight += hasDescription ? 160 : 120; // More space if description exists
              
              // Add height for themes/genres/buttons section
              double themeGenreHeight = 80; // Base for artist info
              if (hasThemes) themeGenreHeight += 40;
              if (hasGenres) themeGenreHeight += 40;
              if (hasPlayButtons) themeGenreHeight += 50;
              baseHeight += themeGenreHeight;
              
              // Cap at reasonable limits: min 60% (for simple content), max 100% (allow full screen if needed)
              final minHeight = screenHeight * 0.6;
              final maxHeight = screenHeight * 1.0;
              final dynamicHeight = baseHeight.clamp(minHeight, maxHeight);
              
              return Container(
                width: MediaQuery.of(context).size.width * 1.0, // Full width minus margins
                height: dynamicHeight,
                margin: const EdgeInsets.all(AppTheme.spacingSM), // Smaller margins for more space
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
                      
                      // Simplified approach: Just aggressively constrain the title and let it ellipsis
                      final statusText = _getReactionStatus();
                      final hasStatus = statusText.isNotEmpty;
                      
                      debugPrint('🚨 [TITLE-WIDGET] This code is being executed for title: "${displayInfo.displayTitle}"');
                      
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final statusText = _getReactionStatus();
                          final hasStatus = statusText.isNotEmpty;
                          
                          // Measure actual status width and position
                          double statusWidth = 0.0;
                          if (hasStatus) {
                            final statusPainter = TextPainter(
                              text: TextSpan(
                                text: statusText,
                                style: AppTheme.bodyStyle.copyWith(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              textDirection: TextDirection.ltr,
                            );
                            statusPainter.layout();
                            statusWidth = statusPainter.width * 1.08; // Status scale
                          }
                          
                          final spacingWidth = hasStatus ? AppTheme.spacingMD : 0.0;
                          final statusStartPosition = constraints.maxWidth - statusWidth;
                          
                          // Simple approach: constrain textbox width to prevent overlap
                          final safeTextWidth = math.max(100.0, (statusStartPosition - spacingWidth - 80.0) / 1.15); // Ensure minimum width
                          
                          debugPrint('🔧 [SIMPLE] statusStart=$statusStartPosition safeTextWidth=$safeTextWidth willTransformTo=${safeTextWidth * 1.15}');
                          
                          // Now add transform back with correct width calculation
                          final availableSpace = statusStartPosition - spacingWidth - 50.0;
                          final textContainerWidth = availableSpace / 2; // Account for 1.15x transform
                          
                          debugPrint('🔧 [WITH-TRANSFORM] availableSpace=$availableSpace textContainerWidth=$textContainerWidth willExpandTo=${textContainerWidth * 1.15}');
                          
                          return Container(
                            width: availableSpace,
                            child: WideText(
                              text: displayInfo.displayTitle.toUpperCase(),
                              style: AppTheme.suggestionHeaderSmall.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w200,
                                color: Colors.white,
                              ),
                              letterSpacing: 2.8, // More compact letter spacing
                              scaleX: 1.15, // 15% horizontal expansion with proper constraint handling
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      );
                    }(),
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  // Status text in interestnaut style
                  _buildStatusText(),
                ],
              ),
            ),
            
            // Media display area component - reduced to allow more space for themes/genres/buttons
            Expanded(
              flex: 2, // Reduced from 3 to give more space to themes/genres/buttons
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
                      // Dynamic image sizing with max constraints
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate max dimensions for image area
                          final maxImageWidth = MediaQuery.of(context).size.width * 0.95 * 0.30; // 30% of available width
                          final maxImageHeight = constraints.maxHeight - (AppTheme.spacingSM * 2); // Available height minus padding
                          
                          return Container(
                            constraints: BoxConstraints(
                              maxWidth: maxImageWidth,
                              maxHeight: maxImageHeight,
                              minWidth: 80, // Minimum width to ensure visibility
                              minHeight: 80, // Minimum height to ensure visibility
                            ),
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
                                        fit: BoxFit.contain, // Use contain to prevent cropping while utilizing space
                                        errorBuilder: (context, error, stackTrace) =>
                                            _buildPlaceholderIcon(),
                                      )
                                    : _buildPlaceholderIcon(),
                              ),
                            ),
                          );
                        },
                      ),
              
                      const SizedBox(width: AppTheme.spacingMD),
              
                      // Scrollable summary area - flexible width based on image size
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(
                            maxWidth: 300, // Max width for summary to prevent it from being too wide
                          ),
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Developer/themes section - dynamic height based on content
            Container(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Row(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate expected height for artist + themes + genres + spacing
                          final hasArtist = widget.artist != null && widget.artist!.isNotEmpty;
                          final hasThemes = widget.themes != null && widget.themes!.isNotEmpty;
                          final hasGenres = widget.genres != null && widget.genres!.isNotEmpty;
                          
                          // Debug genres visibility
                          debugPrint('MediaDetailDrawer genres debug: hasGenres=$hasGenres genres="${widget.genres}" themes="${widget.themes}"');
                          
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
                                if (hasGenres) const SizedBox(height: 2),
                              ],
                              
                              // Genres with proper text wrapping
                              if (hasGenres) ...[
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'GENRES: ',
                                        style: AppTheme.bodyStyle.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      TextSpan(
                                        text: widget.genres!,
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
                          
                          // Return without scrolling - content should fit in allocated space
                          return contentWidget;
                        },
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
            
            // Action section - different for Spotify vs regular content
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                children: [
                  // Spotify limitation note for Spotify content
                  if (widget.limitToSpotifyActions) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.lightBlue.withOpacity(0.7),
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Spotify content can be saved to your library but cannot be reacted to with Interestnaut',
                              style: TextStyle(
                                color: Colors.lightBlue.withOpacity(0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Action buttons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Smart play selector button on far left if available
                      if (widget.youtubeId != null || widget.spotifyId != null) ...[
                        PlaySelectorButton(
                          youtubeId: widget.youtubeId,
                          spotifyId: widget.spotifyId,
                          onYouTubePressed: widget.youtubeId != null ? () => _openYouTube(widget.youtubeId!) : null,
                          onSpotifyPressed: widget.spotifyId != null ? () => _playSpotify(widget.spotifyId!) : null,
                        ),
                      ],
                      
                      // Spotify content: Show only Spotify actions, no Interestnaut reactions
                      if (widget.limitToSpotifyActions) ...[
                        // Save to Spotify button
                        if (widget.spotifyId != null) ...[
                          _buildExternalMediaButton(
                            icon: Icons.add_circle_outline,
                            color: AppTheme.spotifyGreen,
                            onPressed: () => _saveToSpotify(widget.spotifyId!),
                          ),
                        ],
                        // Special button to find Interestnaut match
                        _buildExternalMediaButton(
                          icon: Icons.search,
                          color: AppTheme.primaryColor,
                          onPressed: () => _findInterestnatMatch(),
                        ),
                      ] else ...[
                        // Regular content: Full Interestnaut reactions (play selector already shown above)
                        // Main action buttons for regular content
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
                    ],
                  ),
                ],
            ),
          ),
        ],
        ),
              );
            },
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
      return _buildStyledStatusText('FAVORITED', AppTheme.favoriteColor);
    } else if (_currentLiked) {
      return _buildStyledStatusText('LIKED', AppTheme.likeColor);
    } else if (_currentWatchlisted) {
      return _buildStyledStatusText(_getQueuedStatusText(), AppTheme.watchlistColor);
    } else if (_currentDisliked) {
      return _buildStyledStatusText('DISLIKED', AppTheme.dislikeColor);
    }
    return const SizedBox.shrink();
  }
  
  Widget _buildStyledStatusText(String text, Color color) {
    // Apply thin, wide, sleek styling to status text with slight transform
    const statusScale = 1.08; // Slightly less scaling than title for contrast
    
    return Transform(
      transform: Matrix4.identity()..scale(statusScale, 1.0),
      alignment: Alignment.centerRight,
      child: Text(
        text,
        style: AppTheme.bodyStyle.copyWith(
          fontFamily: 'Inter', // Match the primary font family
          fontSize: 11, // Skinnier/smaller
          fontWeight: FontWeight.w500, // Slightly bolder than w400 but not too heavy
          letterSpacing: 1.2, // More compact letter spacing for sleek look
          color: color,
        ),
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _buildExternalMediaButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            transform: isHovered
                ? (Matrix4.translationValues(0, -2, 0)..scale(1.1))
                : Matrix4.identity(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isHovered
                    ? color.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(24),
                  child: Center(
                    child: Icon(
                      icon,
                      color: isHovered
                          ? color
                          : color.withOpacity(0.7), // Slightly dimmed when not hovered
                      size: 28, // Match other action button icon size
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  void _openYouTube(String videoId) async {
    try {
      // Show internal YouTube player
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => YouTubePlayerDialog(videoId: videoId),
        );
      }
    } catch (e) {
      debugPrint('Error opening YouTube player: $e');
      // Fallback to external app
      _openYouTubeExternal(videoId);
    }
  }

  void _openYouTubeExternal(String videoId) async {
    final url = 'https://www.youtube.com/watch?v=$videoId';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch YouTube URL: $url');
    }
  }

  void _playSpotify(String trackId) async {
    try {
      final spotifyService = SpotifyService();
      
      // Check if user is authenticated
      final isAuthenticated = await spotifyService.checkAuthentication();
      
      if (!isAuthenticated) {
        // Show authentication dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Row(
                children: [
                  Icon(Icons.music_note, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  const Text('Spotify Login Required', style: TextStyle(color: AppTheme.textPrimary)),
                ],
              ),
              content: const Text(
                'Please log in to Spotify to play tracks internally.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openSpotifyExternal(trackId);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                    ),
                  ),
                  child: const Text('Open Spotify App'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(color: AppTheme.textSecondary),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Try to play the track using the internal Spotify service
      final trackUri = 'spotify:track:$trackId';
      final success = await spotifyService.playTrack(trackUri);
      
      if (success) {
        debugPrint('✅ Successfully started Spotify playback for track: $trackId');
        // The existing Spotify playbar should now show the playing track
      } else {
        debugPrint('❌ Failed to start Spotify playback, falling back to external app');
        _openSpotifyExternal(trackId);
      }
    } catch (e) {
      debugPrint('Error playing Spotify track: $e');
      _openSpotifyExternal(trackId);
    }
  }

  void _openSpotifyExternal(String trackId) async {
    final spotifyUrl = 'spotify:track:$trackId';
    final webUrl = 'https://open.spotify.com/track/$trackId';
    
    // Try Spotify app first, fallback to web
    if (await canLaunchUrl(Uri.parse(spotifyUrl))) {
      await launchUrl(Uri.parse(spotifyUrl), mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(Uri.parse(webUrl))) {
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch Spotify URL: $webUrl');
    }
  }

  void _saveToSpotify(String trackId) async {
    try {
      final spotifyService = SpotifyService();
      
      // Check if user is authenticated
      final isAuthenticated = await spotifyService.checkAuthentication();
      
      if (!isAuthenticated) {
        // Show authentication dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Row(
                children: [
                  Icon(Icons.add_circle_outline, color: AppTheme.spotifyGreen),
                  const SizedBox(width: 8),
                  const Text('Spotify Login Required', style: TextStyle(color: AppTheme.textPrimary)),
                ],
              ),
              content: const Text(
                'Please log in to Spotify to save tracks to your library.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: BorderSide(color: AppTheme.textSecondary),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    // Attempt authentication
                    try {
                      await spotifyService.authenticate(context);
                      // Retry saving after authentication
                      _saveToSpotify(trackId);
                    } catch (e) {
                      debugPrint('Authentication failed: $e');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.spotifyGreen,
                    side: BorderSide(color: AppTheme.spotifyGreen),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter',
                    ),
                  ),
                  child: const Text('Login to Spotify'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Try to save the track to the user's library
      final success = await spotifyService.saveTrack(trackId);
      
      if (success) {
        debugPrint('✅ Successfully saved track to Spotify library: $trackId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Track saved to your Spotify library'),
              backgroundColor: AppTheme.spotifyGreen,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        debugPrint('❌ Failed to save track to Spotify library');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save track to library'),
              backgroundColor: AppTheme.dislikeColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving track to Spotify: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving track: $e'),
            backgroundColor: AppTheme.dislikeColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _findInterestnatMatch() async {
    if (!widget.limitToSpotifyActions) return;
    
    try {
      // Show loading state
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Searching for Interestnaut match...'),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      // Prepare search queries with fallback strategy
      final List<String> searchQueries = [];
      
      // Primary: "artist album title"
      if (widget.artist != null && widget.artist!.isNotEmpty) {
        final albumFromDescription = _extractAlbumFromDescription();
        if (albumFromDescription != null && albumFromDescription.isNotEmpty) {
          searchQueries.add('${widget.artist!} $albumFromDescription ${widget.title}');
        }
        // Secondary: "artist title" 
        searchQueries.add('${widget.artist!} ${widget.title}');
        // Tertiary: "artist" only
        searchQueries.add(widget.artist!);
      }
      // Fallback: just title
      searchQueries.add(widget.title);

      debugPrint('🔍 Searching for Interestnaut matches with queries: $searchQueries');

      // Try each search query until we find results
      final grpcClient = GrpcRecommendationClient();
      WikidataSearchResult? firstMatch;
      String? usedQuery;

      // Initialize gRPC client if needed
      if (!grpcClient.isInitialized) {
        await grpcClient.init();
      }

      for (final query in searchQueries) {
        if (query.trim().isEmpty) continue;
        
        debugPrint('🔍 Trying query: "$query"');
        try {
          // Use searchMedia endpoint with query as constraint like in main.dart
          final results = await grpcClient.searchMedia(
            mediaType: 'music',
            constraints: [query],
            limit: 5, // Only need a few results to get the first match
          );
          
          if (results.isNotEmpty) {
            // Convert MediaSuggestion to WikidataSearchResult for compatibility
            final result = results.first;
            firstMatch = WikidataSearchResult(
              id: result.mediaId ?? 'media_${result.id}',
              title: result.title ?? 'Unknown Track',
              artist: result.artist,
              description: result.description,
              imageUrl: result.coverArtUrl,
              releaseDate: null,
              genre: null,
              additionalData: {
                'youtubeId': result.youtubeId,
                'spotifyId': result.spotifyId,
                'wikiUrl': result.wikiUrl,
                'wikidataId': result.wikidataId,
                'themes': result.themes,
              },
            );
            usedQuery = query;
            debugPrint('✅ Found match: ${firstMatch.title} by ${firstMatch.artist}');
            break;
          }
        } catch (e) {
          debugPrint('❌ Query "$query" failed: $e');
          continue;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        
        if (firstMatch != null) {
          // Show the first match as a new media detail drawer
          await _showInterestnatMatchDrawer(firstMatch, usedQuery!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No Interestnaut matches found for this track'),
              backgroundColor: AppTheme.dislikeColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error finding Interestnaut match: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching for match: $e'),
            backgroundColor: AppTheme.dislikeColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Show the found Interestnaut match as a new drawer
  Future<void> _showInterestnatMatchDrawer(WikidataSearchResult match, String usedQuery) async {
    try {
      // Get comprehensive status from database for the match
      final db = SQLiteDatabase();
      final statusResult = await db.getMediaItemStatus(
        title: match.title,
        mediaType: 'music',
        primaryCreator: match.artist ?? 'Unknown Artist',
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
                onTap: () {}, // Prevent tap-through
                child: MediaDetailDrawer(
                  title: match.title,
                  artist: match.artist ?? 'Unknown Artist',
                  description: match.description,
                  themes: match.additionalData?['themes'] as String?,
                  genres: statusResult['genres'] as String?,
                  youtubeId: statusResult['youtubeId'] as String?,
                  spotifyId: statusResult['spotifyId'] as String?,
                  coverArtUrl: match.imageUrl,
                  mediaType: 'music',
                  hasLiked: statusResult['hasLiked'] as bool? ?? false,
                  hasDisliked: statusResult['hasDisliked'] as bool? ?? false,
                  hasFavorited: statusResult['hasFavorited'] as bool? ?? false,
                  isInWatchlist: statusResult['isInWatchlist'] as bool? ?? false,
                  hasSkipped: statusResult['hasSkipped'] as bool? ?? false,
                  onAction: (action) => _handleMatchDrawerAction(
                    context,
                    action,
                    match,
                    statusResult['mediaItemId'] as int?,
                  ),
                  limitToSpotifyActions: false, // Full Interestnaut reactions
                ),
              ),
            ),
          ),
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found Interestnaut match: "${match.title}" (query: "$usedQuery")'),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error showing Interestnaut match drawer: $e');
    }
  }

  /// Handle actions from the Interestnaut match drawer
  Future<void> _handleMatchDrawerAction(
    BuildContext context,
    String action,
    WikidataSearchResult match,
    int? existingMediaItemId,
  ) async {
    try {
      final db = SQLiteDatabase();
      
      // Create or get the media item if it doesn't exist
      int mediaItemId;
      if (existingMediaItemId != null) {
        mediaItemId = existingMediaItemId;
      } else {
        mediaItemId = await db.createOrGetMediaItem(
          mediaType: 'music',
          vectorMediaId: match.id ?? 'wikidata_${DateTime.now().millisecondsSinceEpoch}',
          title: match.title,
          primaryCreator: match.artist ?? 'Unknown Artist',
          coverArtUrl: match.imageUrl,
          description: match.description,
          wikiUrl: match.additionalData?['wikiUrl'] as String?,
          wikidataId: match.additionalData?['wikidataId'] as String?,
          themes: match.additionalData?['themes'] as String?,
          genres: null,
          youtubeId: null,
          spotifyId: null,
        );
        debugPrint('🔍 [INTERESTNAUT-MATCH] Created new media item with ID: $mediaItemId');
      }

      switch (action) {
        case 'like':
          await db.addToFavorites(mediaItemId);
          break;
        case 'dislike':
          // Handle dislike action
          break;
        case 'favorite':
          await db.addToFavorites(mediaItemId);
          break;
        case 'watchlist':
          await db.addToWatchlist(mediaItemId);
          break;
        case 'skip':
          // Handle skip action
          break;
        case 'clear_all':
          // Handle clearing all reactions
          break;
      }
      
      debugPrint('✅ [INTERESTNAUT-MATCH] Handled action: $action for ${match.title}');
    } catch (e) {
      debugPrint('❌ [INTERESTNAUT-MATCH] Error handling match drawer action: $e');
    }
  }

  String? _extractAlbumFromDescription() {
    // Try to extract album name from description if it contains album info
    if (widget.description == null || widget.description!.isEmpty) return null;
    
    final description = widget.description!.toLowerCase();
    
    // Look for common album indicators
    final albumPatterns = [
      RegExp(r'from the album[:\s]+"([^"]+)"'),
      RegExp(r'album[:\s]+"([^"]+)"'),
      RegExp(r'from[:\s]+"([^"]+)"'),
    ];
    
    for (final pattern in albumPatterns) {
      final match = pattern.firstMatch(description);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }
    
    return null;
  }
}

/// Custom widget for transformed title text that can calculate proper spacing
/// to prevent overlap with status indicators
class _TransformedTitleText extends StatefulWidget {
  final String text;
  final String statusText;
  final TextStyle style;
  final double transformScale;
  final double statusScale;

  const _TransformedTitleText({
    required this.text,
    required this.statusText,
    required this.style,
    required this.transformScale,
    required this.statusScale,
  });

  @override
  State<_TransformedTitleText> createState() => _TransformedTitleTextState();
}

class _TransformedTitleTextState extends State<_TransformedTitleText> {
  double? _calculatedWidth;
  double? _overflowAmount;
  bool _hasCalculated = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_hasCalculated) {
          _calculateOptimalWidth(constraints.maxWidth);
        }

        final hasStatus = widget.statusText.isNotEmpty;
        
        // Calculate status width using TextPainter
        double statusWidth = 0.0;
        if (hasStatus) {
          final statusPainter = TextPainter(
            text: TextSpan(
              text: widget.statusText,
              style: AppTheme.bodyStyle.copyWith(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          statusPainter.layout();
          statusWidth = (statusPainter.width * widget.statusScale) + 40.0; // More conservative margin
        }

        final spacingWidth = hasStatus ? AppTheme.spacingMD : 0.0;
        final availableWidth = constraints.maxWidth - statusWidth - spacingWidth;
        
        // Calculate the maximum width the text container can be before transformation
        final maxContainerWidth = availableWidth / widget.transformScale;
        
        // Use more aggressive constraint to prevent any possibility of overflow
        // We need to ensure: (finalWidth × transformScale) + statusWidth + spacingWidth <= constraints.maxWidth
        final maxAllowedTransformedWidth = constraints.maxWidth - statusWidth - spacingWidth - 20.0; // Extra 20px safety
        final maxAllowedContainerWidth = maxAllowedTransformedWidth / widget.transformScale;
        
        final finalWidth = _calculatedWidth != null 
            ? math.min(_calculatedWidth!, maxAllowedContainerWidth)
            : maxAllowedContainerWidth;
            
        // Debug output for troubleshooting
        debugPrint('TransformedTitleText FINAL: maxAllowedTransformedWidth=$maxAllowedTransformedWidth maxAllowedContainerWidth=$maxAllowedContainerWidth finalWidth=$finalWidth willTransformTo=${finalWidth * widget.transformScale}');

        return SizedBox(
          width: finalWidth,
          child: Transform(
            transform: Matrix4.identity()..scale(widget.transformScale, 1.0),
            alignment: Alignment.centerLeft,
            child: Text(
              widget.text,
              style: widget.style,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  void _calculateOptimalWidth(double maxWidth) {
    // Calculate the natural width of the text without transformation
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    );
    textPainter.layout();
    
    // Store the calculated width and overflow info
    _calculatedWidth = textPainter.width;
    _overflowAmount = (_calculatedWidth! * widget.transformScale) - maxWidth;
    _hasCalculated = true;
    
    // Debug output
    debugPrint('TransformedTitleText: text="${widget.text}" naturalWidth=${_calculatedWidth} transformedWidth=${_calculatedWidth! * widget.transformScale} maxWidth=$maxWidth overflow=$_overflowAmount');
  }

  /// Public getter for overflow amount (can be used by parent widgets)
  double? get overflowAmount => _overflowAmount;
  
  /// Public getter for calculated width
  double? get calculatedWidth => _calculatedWidth;
}


// YouTubePlayerDialog is now imported from youtube_player_new.dart