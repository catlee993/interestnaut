import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme.dart';
import '../../models.dart';
import '../../db/vector_db.dart';

class MediaDetailDrawer extends StatefulWidget {
  final String? mediaId;
  final String? title;
  final String? artist;
  final String? description;
  final String? themes;
  final String? coverArtUrl;
  final String mediaType;
  final VoidCallback? onClose;
  final Function(String action)? onAction;
  // Reaction states
  final bool? hasLiked;
  final bool? hasFavorited;
  final bool? hasDisliked;
  final bool? isInWatchlist;
  final bool? hasSkipped;

  const MediaDetailDrawer({
    Key? key,
    this.mediaId,
    this.title,
    this.artist,
    this.description,
    this.themes,
    this.coverArtUrl,
    required this.mediaType,
    this.onClose,
    this.onAction,
    this.hasLiked,
    this.hasFavorited,
    this.hasDisliked,
    this.isInWatchlist,
    this.hasSkipped,
  }) : super(key: key);

  @override
  State<MediaDetailDrawer> createState() => _MediaDetailDrawerState();
}

class _MediaDetailDrawerState extends State<MediaDetailDrawer> {
  bool? _currentLiked;
  bool? _currentFavorited;
  bool? _currentDisliked;
  bool? _currentWatchlisted;
  bool? _currentSkipped;

  @override
  void initState() {
    super.initState();
    _currentLiked = widget.hasLiked;
    _currentFavorited = widget.hasFavorited;
    _currentDisliked = widget.hasDisliked;
    _currentWatchlisted = widget.isInWatchlist;
    _currentSkipped = widget.hasSkipped;
  }

  String _getStatusText() {
    if (_currentFavorited == true) return 'Favorited';
    if (_currentLiked == true) return 'Liked';
    if (_currentWatchlisted == true) return 'In Playlist';
    if (_currentDisliked == true) return 'Disliked';
    if (_currentSkipped == true) return 'Skipped';
    return '';
  }

  Color _getStatusColor() {
    if (_currentFavorited == true) return AppTheme.accentColor;
    if (_currentLiked == true) return AppTheme.successColor;
    if (_currentWatchlisted == true) return AppTheme.primaryColor;
    if (_currentDisliked == true) return AppTheme.errorColor;
    if (_currentSkipped == true) return AppTheme.textSecondary;
    return Colors.transparent;
  }

  void _handleAction(String action) {
    setState(() {
      // Reset all states first
      _currentLiked = false;
      _currentFavorited = false;
      _currentDisliked = false;
      _currentWatchlisted = false;
      _currentSkipped = false;

      // Set the new state
      switch (action) {
        case 'like':
          _currentLiked = true;
          break;
        case 'favorite':
          _currentFavorited = true;
          break;
        case 'dislike':
          _currentDisliked = true;
          break;
        case 'watchlist':
          _currentWatchlisted = true;
          break;
        case 'skip':
          _currentSkipped = true;
          break;
      }
    });

    // Call the external action handler
    widget.onAction?.call(action);
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

  @override
  Widget build(BuildContext context) {
    final statusText = _getStatusText();
    final statusColor = _getStatusColor();

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95, // Wider drawer
        height: MediaQuery.of(context).size.height * 0.70,
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.cardBorderRadius),
            topRight: Radius.circular(AppTheme.cardBorderRadius),
          ),
          border: Border.all(
            color: AppTheme.textSecondary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Header with title, status, and close button
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.textSecondary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Title and status
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.title ?? 'Unknown Title',
                            style: AppTheme.headingStyle.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (statusText.isNotEmpty) ...[
                          const SizedBox(width: AppTheme.spacingMD),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingXS,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                            ),
                            child: Text(
                              statusText,
                              style: AppTheme.bodyStyle.copyWith(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Close button
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const FaIcon(
                      FontAwesomeIcons.xmark,
                      size: 18,
                    ),
                    color: AppTheme.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // Main content area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Column(
                  children: [
                    // Content row with image and details
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left side - Cover art
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
                              color: AppTheme.surfaceColor,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
                              child: widget.coverArtUrl != null
                                  ? Image.network(
                                      widget.coverArtUrl!,
                                      fit: BoxFit.cover,
                                      width: 140,
                                      height: 140,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 140,
                                          height: 140,
                                          color: AppTheme.surfaceColor,
                                          child: const Icon(
                                            Icons.image_not_supported,
                                            color: AppTheme.textSecondary,
                                            size: 40,
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      width: 140,
                                      height: 140,
                                      color: AppTheme.surfaceColor,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: AppTheme.textSecondary,
                                        size: 40,
                                      ),
                                    ),
                            ),
                          ),
                          
                          const SizedBox(width: AppTheme.spacingMD),
                          
                          // Right side - Content only (no actions)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.description != null && widget.description!.isNotEmpty) ...[
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.description!,
                                            style: AppTheme.bodyStyle.copyWith(
                                              fontSize: 13,
                                              height: 1.4,
                                            ),
                                          ),
                                          
                                          const SizedBox(height: AppTheme.spacingMD),
                                          
                                          // Developer/Creator info - in scrollable area
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
                                            const SizedBox(height: AppTheme.spacingSM),
                                          ],
                                          
                                          // Themes - in scrollable area
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
                                  ),
                                ] else ...[
                                  Text(
                                    'No description available.',
                                    style: AppTheme.bodyStyle.copyWith(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: AppTheme.spacingSM), // Much smaller gap
                    
                    // Action buttons - positioned right below content
                    Row(
                      children: [
                        _buildSuggestionStyleButton(
                          icon: Icons.thumb_up_outlined, // Sleek outlined icon
                          label: 'Like',
                          isActive: _currentLiked == true,
                          activeColor: const Color(0xFF4CAF50),
                          onPressed: () => _handleAction('like'),
                        ),
                        const SizedBox(width: AppTheme.spacingXS),
                        _buildSuggestionStyleButton(
                          icon: Icons.thumb_down_outlined, // Sleek outlined icon
                          label: 'Dislike',
                          isActive: _currentDisliked == true,
                          activeColor: const Color(0xFFF44336),
                          onPressed: () => _handleAction('dislike'),
                        ),
                        const SizedBox(width: AppTheme.spacingXS),
                        _buildSuggestionStyleButton(
                          icon: Icons.favorite_outline, // Sleek outlined heart
                          label: 'Favorite',
                          isActive: _currentFavorited == true,
                          activeColor: const Color(0xFFE91E63),
                          onPressed: () => _handleAction('favorite'),
                        ),
                        const SizedBox(width: AppTheme.spacingXS),
                        _buildSuggestionStyleButton(
                          icon: Icons.bookmark_outline, // Sleek outlined bookmark
                          label: 'Playlist',
                          isActive: _currentWatchlisted == true,
                          activeColor: const Color(0xFF2196F3),
                          onPressed: () => _handleAction('watchlist'),
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

  /// Build suggestion-style button that matches the main UI
  Widget _buildSuggestionStyleButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          child: Container(
            height: 50,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive 
                  ? activeColor  // Full color when active
                  : AppTheme.surfaceColor,  // Muted background when inactive
              borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 18,
                color: isActive 
                    ? Colors.white  // White icon when active
                    : AppTheme.textSecondary,  // Muted when inactive
              ),
            ),
          ),
        ),
      ),
    );
  }
} 