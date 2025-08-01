import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../../theme.dart';
import '../../services/sqlite_db.dart';
import 'media_action_icons.dart';
import '../../models.dart'; // For MediaDisplayHelper
import '../music/spotify_service.dart'; // For Spotify playback

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
        height: MediaQuery.of(context).size.height * 0.85, // Increased to 85% to ensure play buttons are visible without scrolling
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
                      final reactionStatus = _getReactionStatus();
                      final titleText = reactionStatus.isNotEmpty 
                          ? '${displayInfo.displayTitle} • $reactionStatus'
                          : displayInfo.displayTitle;
                      
                      return Transform(
                        transform: Matrix4.identity()..scale(1.15, 1.0),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          titleText.toUpperCase(),
                          style: AppTheme.suggestionHeaderSmall.copyWith(
                            fontSize: 18,
                            letterSpacing: 2.5,
                            fontWeight: FontWeight.w200,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                      // Static image - reduced width for better space allocation
                      Container(
                        width: MediaQuery.of(context).size.width * 0.95 * 0.25, // Reduced from 0.33 * 0.8 to 0.25
                        height: 140, // Fixed height to prevent image from being too tall
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
            
            // Developer/themes section - increased space for themes/genres/buttons
            Expanded(
              flex: 2, // Increased from 1 to accommodate themes/genres/YouTube/Spotify buttons
              child: Container(
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
                                if (hasGenres) const SizedBox(height: AppTheme.spacingXS),
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
                                const SizedBox(height: AppTheme.spacingXS),
                              ],
                              
                              // Play buttons for YouTube/Spotify
                              if (widget.youtubeId != null || widget.spotifyId != null) ...[
                                const SizedBox(height: AppTheme.spacingXS),
                                Row(
                                  children: [
                                    if (widget.youtubeId != null) ...[
                                      _buildPlayButton(
                                        icon: Icons.play_circle_outline,
                                        label: 'YouTube',
                                        color: AppTheme.positiveColor, // Turquoise for YouTube
                                        onPressed: () => _openYouTube(widget.youtubeId!),
                                      ),
                                      if (widget.spotifyId != null) const SizedBox(width: 8),
                                    ],
                                    if (widget.spotifyId != null) ...[
                                      _buildPlayButton(
                                        icon: Icons.music_note,
                                        label: 'Spotify',
                                        color: AppTheme.primaryColor, // Purple for Spotify to match brand
                                        onPressed: () => _openSpotify(widget.spotifyId!),
                                      ),
                                    ],
                                  ],
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

  Widget _buildPlayButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openYouTube(String videoId) async {
    try {
      // Show internal YouTube player
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => _YouTubePlayerDialog(videoId: videoId),
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

  void _openSpotify(String trackId) async {
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
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openSpotifyExternal(trackId);
                  },
                  child: Text('Open Spotify App', style: TextStyle(color: AppTheme.primaryColor)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
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
}

/// Internal YouTube Player Dialog
class _YouTubePlayerDialog extends StatefulWidget {
  final String videoId;

  const _YouTubePlayerDialog({required this.videoId});

  @override
  State<_YouTubePlayerDialog> createState() => _YouTubePlayerDialogState();
}

class _YouTubePlayerDialogState extends State<_YouTubePlayerDialog> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
        captionLanguage: 'en',
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    color: AppTheme.positiveColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'YouTube Player',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // YouTube Player
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: AppTheme.positiveColor,
                progressColors: ProgressBarColors(
                  playedColor: AppTheme.positiveColor,
                  handleColor: AppTheme.positiveColor,
                  bufferedColor: AppTheme.positiveColor.withOpacity(0.3),
                  backgroundColor: AppTheme.textSecondary.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}