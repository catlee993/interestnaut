import 'package:flutter/material.dart';
import 'media_detail_drawer.dart';
import '../../shared/services/sqlite_db.dart'; // Fixed import path
import '../../features/recommendations/data/recommendation_service.dart'; // For MediaSuggestion and SuggestionStatus
import '../../core/network/grpc_client.dart';
import '../../main.dart'; // For MediaSearchResult
import '../../core/media_title_handler.dart';
import 'suggestion_action_buttons.dart';
import 'loading_suggestion.dart';
import 'base_media_section_controller.dart';
import 'media_library_grid.dart'; // For CardFormat enum
import 'scroll_content_wrapper.dart'; // For MediaSectionLayout
import 'suggestion_reasoning_display.dart'; // New reasoning component
import 'media_preview_buttons.dart'; // Preview buttons
import '../theme/theme.dart';
import '../../core/text_utils.dart';
import '../models/models.dart';

class MediaSectionWrapper extends StatelessWidget {
  final BaseMediaSectionController controller;
  final String mediaType;
  final List<Widget> additionalSections;
  final Widget? playerOverlay;
  final CardFormat? cardFormat;

  const MediaSectionWrapper({
    super.key,
    required this.controller,
    required this.mediaType,
    this.additionalSections = const [],
    this.playerOverlay,
    this.cardFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content with MediaSectionLayout to match original structure
        MediaSectionLayout(
          builder: (scrollOffset) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 100), // Add padding for playbar
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with consistent spacing (matches TV section)
                  ComponentSpacing(
                    child: Center(
                      child: Opacity(
                        opacity: (scrollOffset <= 70) ? 1.0 : 0.0,
                        child: Center(
                          child: AppTheme.themedSuggestionHeader('SUGGESTED'),
                        ),
                      ),
                    ),
                  ),
                  
                  // Suggestion content with consistent spacing
                  ComponentSpacing(
                    child: _buildSuggestionContent(),
                  ),
                  
                  // Watchlist section with proper spacing - only show if not empty or loading
                  if (controller.dbWatchlistSuggestions.isNotEmpty || controller.isLoadingDbWatchlist)
                    SectionSpacing(
                      child: _buildWatchlistSection(context),
                    ),
                  
                  // Library section with proper spacing - only show if not empty or loading
                  if (controller.dbLikedSuggestions.isNotEmpty || controller.isLoadingDbLibrary)
                    SectionSpacing(
                      child: _buildLibrarySection(context),
                    ),
                  
                  // Additional sections (like Spotify) at the bottom
                  ...additionalSections.map((section) => SectionSpacing(
                    child: section,
                  )),
                ],
              ),
            );
          },
        ),
        
        // Optional player overlay
        if (playerOverlay != null) playerOverlay!,
      ],
    );
  }

  Widget _buildSuggestionContent() {
    if (controller.isLoadingDbSuggestion) {
      return LoadingSuggestion(mediaType: mediaType);
    } else if (controller.dbSuggestionError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Failed to get a suggestion',
                style: AppTheme.mediaDescriptionStyle.copyWith(
                  color: Colors.white54,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: controller.loadDbSuggestion,
                style: AppTheme.suggestionButtonStyle,
                child: Transform.scale(
                  scaleX: 0.9, // Slightly compressed horizontally
                  scaleY: 1.05, // Slightly taller than normal
                  child: Text(
                    'Try Again',
                    style: AppTheme.suggestionButtonTextStyle,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (controller.currentDbSuggestion == null) {
      // If we're loading, show loading indicator instead of "Get a Suggestion" button
      if (controller.isLoadingDbSuggestion) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(
              color: Color.fromRGBO(123, 104, 238, 0.7),
            ),
          ),
        );
      }
      
      // Only show "Get a Suggestion" button if we're not loading and have no suggestion
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: OutlinedButton(
            onPressed: controller.loadDbSuggestion,
            style: AppTheme.suggestionButtonStyle,
            child: Transform.scale(
              scaleX: 0.9, // Slightly compressed horizontally
              scaleY: 1.05, // Slightly taller than normal
          child: Text(
                'Get a Suggestion',
                style: AppTheme.suggestionButtonTextStyle,
            ),
            ),
          ),
        ),
      );
    } else {
      return _buildSuggestionCard();
    }
  }

  Widget _buildSuggestionCard() {
    final suggestion = controller.currentDbSuggestion!;
    final effectiveCardFormat = cardFormat ?? MediaLibraryGrid.getCardFormatForMediaType(mediaType);
    final isSquare = effectiveCardFormat == CardFormat.square;
    
    // Use different dimensions based on card format
    final imageWidth = isSquare ? 200.0 : 300.0;
    final imageHeight = isSquare ? 200.0 : 450.0;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3), // Same as suggestion control buttons
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media poster/album art with border for reasoning
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF8C86E2).withOpacity(0.7), // Reasoning color
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10), // Slightly smaller to account for border
              child: Container(
                width: imageWidth,
                height: imageHeight,
                color: Colors.grey[900],
                child: suggestion.coverArtUrl?.isNotEmpty == true
                  ? Image.network(
                      suggestion.coverArtUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
                    )
                  : _buildPlaceholderImage(),
              ),
            ),
          ),
          const SizedBox(width: 24),
          
          // Media details
          Expanded(
            child: SizedBox(
              height: imageHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Media title
                  Text(
                    () {
                      final displayInfo = MediaDisplayHelper.resolveDisplayInfo(
                        title: suggestion.title,
                        artist: suggestion.artist,
                        fallbackTitle: 'Unknown ${AppTheme.getMediaDisplayName(mediaType)}',
                      );
                      return displayInfo.displayTitle;
                    }(),
                    style: AppTheme.mediaTitleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  // Artist/creator info - only show if we have a subtitle
                  () {
                    final displayInfo = MediaDisplayHelper.resolveDisplayInfo(
                      title: suggestion.title,
                      artist: suggestion.artist,
                      fallbackTitle: 'Unknown ${AppTheme.getMediaDisplayName(mediaType)}',
                    );
                    if (displayInfo.hasSubtitle) {
                      return Text(
                        _getArtistText(displayInfo.displaySubtitle!),
                        style: AppTheme.mediaArtistStyle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    } else {
                      return const SizedBox(height: 0);
                    }
                  }(),
                  
                  // Genres display - only show if genres are available
                  if (suggestion.genres != null && suggestion.genres!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6.0,
                        runSpacing: 4.0,
                        children: suggestion.genres!.map((genre) => 
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8C86E2).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF8C86E2).withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              genre.trim(),
                              style: const TextStyle(
                                color: Color(0xFF8C86E2),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ).toList(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  // Flexible content area for description and reasoning with dynamic height allocation
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return _buildDynamicContentLayout(
                          constraints: constraints,
                          context: context,
                          description: suggestion.description,
                          reasoning: suggestion.botReasoning,
                        );
                      },
                    ),
                  ),
                  
                  // Centered button layout with external media buttons on left, action buttons on right
                  // Button layout that expands to fill available width with equal padding
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // External media buttons (YouTube/Spotify) on the left
                      if (suggestion.youtubeId != null || suggestion.spotifyId != null) ...[
                        MediaPreviewButtons(
                          title: suggestion.title ?? '',
                          artist: suggestion.artist,
                          mediaType: mediaType,
                          spotifyId: suggestion.spotifyId,
                          youtubeId: suggestion.youtubeId,
                          youtubeUrl: null,
                          alignLeft: true,
                        ),
                        // Divider between preview and action buttons
                        Container(
                          height: 30,
                          width: 1,
                          color: Colors.white.withOpacity(0.3),
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ],
                      // Action buttons that can expand to fill remaining space
                      Expanded(
                        child: Center(
                          child: SuggestionActionButtons(
                            mediaType: mediaType,
                            hasLikedCurrentSuggestion: controller.hasLikedCurrentSuggestion,
                            hasFavoritedCurrentSuggestion: controller.hasFavoritedCurrentSuggestion,
                            isInWatchlist: controller.isInWatchlistCurrentSuggestion,
                            isProcessing: controller.isLoadingDbSuggestion,
                            onLike: controller.likeDbSuggestion,
                            onDislike: controller.dislikeDbSuggestion,
                            onFavorite: controller.addToFavorites,
                            onUnfavorite: controller.unfavoriteCurrentSuggestion,
                            onAddToWatchlist: () {
                              if (controller.isInWatchlistCurrentSuggestion) {
                                controller.removeCurrentSuggestionFromWatchlist();
                              } else {
                                controller.addDbSuggestionToWatchlist();
                              }
                            },
                            onSkip: controller.skipDbSuggestion,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Extract Spotify ID from mediaId if it's a Spotify URL or ID
  String? _extractSpotifyId(String? mediaId) {
    if (mediaId == null || mediaType != 'music') return null;
    
    // Handle Spotify URI format: spotify:track:4iV5W9uYEdYUVa79Axb7Rh
    if (mediaId.startsWith('spotify:track:')) {
      return mediaId.substring('spotify:track:'.length);
    }
    
    // Handle Spotify URL format: https://open.spotify.com/track/4iV5W9uYEdYUVa79Axb7Rh
    if (mediaId.contains('spotify.com/track/')) {
      final match = RegExp(r'track/([a-zA-Z0-9]+)').firstMatch(mediaId);
      return match?.group(1);
    }
    
    // Handle direct Spotify ID (22 character alphanumeric string)
    if (RegExp(r'^[a-zA-Z0-9]{22}$').hasMatch(mediaId)) {
      return mediaId;
    }
    
    // For music media_ids from vector database, check if it contains a Spotify ID
    // Format might be: music_spotify_4iV5W9uYEdYUVa79Axb7Rh or similar
    if (mediaId.contains('spotify') && mediaId.length > 22) {
      final spotifyMatch = RegExp(r'[a-zA-Z0-9]{22}').firstMatch(mediaId);
      return spotifyMatch?.group(0);
    }
    
    return null;
  }

  Widget _buildPlaceholderImage() {
    final effectiveCardFormat = cardFormat ?? MediaLibraryGrid.getCardFormatForMediaType(mediaType);
    final isSquare = effectiveCardFormat == CardFormat.square;
    final imageWidth = isSquare ? 200.0 : 300.0;
    final imageHeight = isSquare ? 200.0 : 450.0;
    final icon = AppTheme.getMediaIcon(mediaType);
    
    return Container(
      width: imageWidth,
      height: imageHeight,
      color: Colors.grey[900],
      child: Center(
        child: Icon(
          icon,
          size: 48,
          color: Colors.white54,
        ),
      ),
    );
  }

  String _getArtistText(String artist) {
    switch (mediaType) {
      case 'music':
        return 'by ${TextUtils.formatArtistNames(artist)}';
      case 'movie':
        return 'Directed by ${TextUtils.formatArtistNames(artist)}';
      case 'book':
        return 'by ${TextUtils.formatArtistNames(artist)}';
      case 'tv_show':
        return 'on ${TextUtils.formatArtistNames(artist)}';
      case 'video_game':
        return 'Developed by ${TextUtils.formatArtistNames(artist)}';
      default:
        return artist;
    }
  }

  /// Build dynamic content layout with improved scrolling and height management
  Widget _buildDynamicContentLayout({
    required BoxConstraints constraints,
    required BuildContext context,
    required String? description,
    required String? reasoning,
  }) {
    // Calculate available height (account for padding and spacing)
    final availableHeight = constraints.maxHeight - 32; // Account for top/bottom spacing
    
    // Determine content types
    final hasDescription = description != null && description.isNotEmpty;
    final hasReasoning = reasoning != null && reasoning.isNotEmpty;
    
    // If no content, show placeholder
    if (!hasDescription && !hasReasoning) {
      return Center(
        child: Text(
          'No additional details available',
          style: AppTheme.mediaDescriptionStyle.copyWith(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
      );
    }
    
    // If only one type of content, give it full height
    if (hasDescription && !hasReasoning) {
      return _buildDescriptionOnlyLayout(description, availableHeight);
    }
    
    if (hasReasoning && !hasDescription) {
      return _buildReasoningOnlyLayout(reasoning, availableHeight, context);
    }
    
    // Both description and reasoning exist - smart allocation
    return _buildDualContentLayout(
      description: description!,
      reasoning: reasoning!,
      availableHeight: availableHeight,
      context: context,
      constraints: constraints,
    );
  }

  /// Build layout with description only (full height)
  Widget _buildDescriptionOnlyLayout(String? description, double availableHeight) {
    return Container(
      height: availableHeight,
      child: SingleChildScrollView(
        child: Text(
          description ?? '',
          style: AppTheme.mediaDescriptionStyle.copyWith(
            fontSize: 14,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Build layout with reasoning only (full height)
  Widget _buildReasoningOnlyLayout(String? reasoning, double availableHeight, BuildContext context) {
    return Container(
      height: availableHeight,
      child: SuggestionReasoningDisplay(
        reasoning: reasoning ?? '',
        mediaType: mediaType,
        onMatchSourceTap: _showItemDrawerByMediaItemId,
        onMatchSourceFallback: _showItemDrawer,
      ),
    );
  }

  /// Build dual content layout with smart allocation
  Widget _buildDualContentLayout({
    required String description,
    required String reasoning,
    required double availableHeight,
    required BuildContext context,
    required BoxConstraints constraints,
  }) {
    // Calculate natural content heights based on text
    final descriptionTextHeight = _estimateTextHeight(description, AppTheme.mediaDescriptionStyle, constraints.maxWidth - 32);
    final reasoningTextHeight = _estimateReasoningHeight(reasoning, constraints.maxWidth - 32);
    
    // Define max proportions
    const double maxDescriptionRatio = 0.6; // 3/5
    const double maxReasoningRatio = 0.4; // 2/5
    const double spacing = 16.0;
    
    // Calculate max allowed heights
    final maxDescriptionHeight = availableHeight * maxDescriptionRatio;
    final maxReasoningHeight = availableHeight * maxReasoningRatio;
    
    double descriptionHeight;
    double reasoningHeight;
    
    // Smart allocation logic
    if (descriptionTextHeight <= maxDescriptionHeight && reasoningTextHeight <= maxReasoningHeight) {
      // Both fit within their max - use natural heights
      descriptionHeight = descriptionTextHeight;
      reasoningHeight = reasoningTextHeight;
    } else if (descriptionTextHeight <= maxDescriptionHeight && reasoningTextHeight > maxReasoningHeight) {
      // Description fits, reasoning doesn't - give reasoning all remaining space
      descriptionHeight = descriptionTextHeight;
      reasoningHeight = availableHeight - descriptionHeight - spacing;
    } else if (descriptionTextHeight > maxDescriptionHeight && reasoningTextHeight <= maxReasoningHeight) {
      // Reasoning fits, description doesn't - give description all remaining space
      reasoningHeight = reasoningTextHeight;
      descriptionHeight = availableHeight - reasoningHeight - spacing;
    } else {
      // Both exceed their max - split equally
      final halfSpace = (availableHeight - spacing) / 2;
      descriptionHeight = halfSpace;
      reasoningHeight = halfSpace;
    }
    
    // Ensure minimum heights
    descriptionHeight = descriptionHeight.clamp(60.0, availableHeight - spacing - 60.0);
    reasoningHeight = reasoningHeight.clamp(60.0, availableHeight - spacing - 60.0);
    
    return Column(
      children: [
        // Description section with calculated height
        Container(
          height: descriptionHeight,
          child: SingleChildScrollView(
            child: Text(
              description,
              style: AppTheme.mediaDescriptionStyle.copyWith(
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Reasoning section with remaining height
        Container(
          height: reasoningHeight,
          child: SuggestionReasoningDisplay(
            reasoning: reasoning,
            mediaType: mediaType,
            onMatchSourceTap: _showItemDrawerByMediaItemId,
            onMatchSourceFallback: _showItemDrawer,
          ),
        ),
      ],
    );
  }

  /// Calculate reasoning complexity (0.0 to 1.0)
  double _calculateReasoningComplexity(String reasoning) {
    if (reasoning.isEmpty) return 0.0;
    
    double complexity = 0.0;
    
    // Factor 1: Length (more content = more complex)
    final lengthFactor = (reasoning.length / 500).clamp(0.0, 0.3);
    complexity += lengthFactor;
    
    // Factor 2: Number of sections (more sections = more complex)
    final sectionCount = reasoning.split('**').length / 2;
    final sectionFactor = (sectionCount / 3).clamp(0.0, 0.3);
    complexity += sectionFactor;
    
    // Factor 3: Match sources (clickable items = more interactive)
    final matchSourceLines = reasoning.split('\n').where((line) => 
      line.trim().isNotEmpty && !line.startsWith('**') && !line.startsWith('━')
    ).length;
    final interactivityFactor = (matchSourceLines / 10).clamp(0.0, 0.4);
    complexity += interactivityFactor;
    
    return complexity.clamp(0.0, 1.0);
  }



  void _showMediaDrawer(BuildContext context, MediaDetailDrawer drawer) {
    // Close any existing modals before opening new one (ensures single instance)
    if (Navigator.canPop(context)) {
      Navigator.popUntil(context, (route) => route.isFirst || !route.isActive);
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      barrierColor: Colors.black54, // Make the barrier more visible for better UX
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(), // Ensure click outside closes drawer
        child: Container(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {}, // Prevent event bubbling when tapping the drawer itself
            child: drawer,
          ),
        ),
      ),
    );
  }

  /// Show item drawer with direct MediaSearchResult (most reliable)
  Future<void> _showItemDrawerDirect(BuildContext context, MediaSearchResult item) async {
    try {
      // Get comprehensive status using single source of truth lookup
      final db = SQLiteDatabase();
      final bestTitle = _getBestDisplayName(item);
      final statusResult = await db.getMediaItemStatus(vectorMediaId: item.mediaId);
      
      debugPrint('🔍 [DRAWER-DIRECT] Status for "$bestTitle": $statusResult');
      
      // Smart artist handling: if we used the artist as the title, don't pass it as artist
      String? effectiveArtist = item.artist;
      if (item.artist != null && bestTitle == item.artist) {
        // The artist became the title, so clear the artist field to avoid duplication
        effectiveArtist = null;
      }
      
      _showMediaDrawer(
        context,
        MediaDetailDrawer(
          title: bestTitle,
          artist: effectiveArtist,
          description: item.description,
          themes: item.themes,
          genres: statusResult['genres'] as String?,
          youtubeId: statusResult['youtubeId'] as String?,
          spotifyId: statusResult['spotifyId'] as String?,
          coverArtUrl: item.coverArtUrl,
          mediaType: mediaType,
          hasLiked: statusResult['hasLiked'] as bool? ?? false,
          hasDisliked: statusResult['hasDisliked'] as bool? ?? false,
          hasFavorited: statusResult['hasFavorited'] as bool? ?? false,
          isInWatchlist: statusResult['isInWatchlist'] as bool? ?? false,
          hasSkipped: statusResult['hasSkipped'] as bool? ?? false,
          onAction: (action) => _handleDrawerAction(
            context, 
            action, 
            item, 
            statusResult['mediaItemId'] as int?,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ [DRAWER-DIRECT] Error showing item drawer: $e');
      _showErrorDialog(context, 'Failed to load item details: $e');
    }
  }

  /// Show item drawer by media ID (more reliable than text search)
  Future<void> _showItemDrawerById(BuildContext context, String mediaId) async {
    try {
      final grpcClient = GrpcRecommendationClient();
      await grpcClient.init();
      
      final suggestion = await grpcClient.getMediaDetails(mediaId: mediaId, mediaType: mediaType);
      
      if (suggestion != null) {
        // Convert MediaSuggestion to MediaSearchResult for compatibility
        final item = MediaSearchResult(
          mediaId: suggestion.mediaId ?? '',
          title: suggestion.title,
          artist: suggestion.artist,
          album: suggestion.album,
          description: suggestion.description,
          themes: suggestion.themes,
          genres: suggestion.genres?.join(', '),
          wikiUrl: suggestion.wikiUrl,
          wikidataId: suggestion.wikidataId,
          coverArtUrl: suggestion.coverArtUrl,
          youtubeId: suggestion.youtubeId,
          spotifyId: suggestion.spotifyId,
          mediaType: mediaType,
        );
        await _showItemDrawerDirect(context, item);
      } else {
        debugPrint('❌ [DRAWER-ID] No item found with media_id: $mediaId');
        _showErrorDialog(context, 'Media item not found');
      }
    } catch (e) {
      debugPrint('❌ [DRAWER-ID] Error showing item drawer by ID: $e');
      _showErrorDialog(context, 'Failed to load item details: $e');
    }
  }

  /// Show error dialog helper
  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show media library item drawer (for tapped cards)
  Future<void> _showMediaLibraryItemDrawer(BuildContext context, MediaSuggestion suggestion) async {
    try {
      // Convert MediaSuggestion to MediaSearchResult format for consistency
      final item = MediaSearchResult(
        title: suggestion.title ?? 'Unknown',
        artist: suggestion.artist,
        album: suggestion.album,
        description: suggestion.description,
        themes: suggestion.themes,
        coverArtUrl: suggestion.coverArtUrl,
        wikiUrl: suggestion.wikiUrl,
        wikidataId: suggestion.wikidataId,
        mediaId: suggestion.mediaId ?? '',
        mediaType: mediaType,
      );
      
      await _showItemDrawerDirect(context, item);
    } catch (e) {
      debugPrint('❌ [LIBRARY-DRAWER] Error showing library item drawer: $e');
      _showErrorDialog(context, 'Failed to load item details: $e');
    }
  }

  /// Legacy method: Show item drawer by name (fallback for old code)
  Future<void> _showItemDrawer(BuildContext context, String itemName) async {
    try {
      // Look up the actual item via gRPC backend
      final grpcClient = GrpcRecommendationClient();
      await grpcClient.init();
      
      final results = await grpcClient.searchMedia(
        mediaType: mediaType,
        constraints: [itemName],
        limit: 1,
      );
      
      if (results.isNotEmpty) {
        final suggestion = results.first;
        // Convert MediaSuggestion to MediaSearchResult for compatibility
        final item = MediaSearchResult(
          mediaId: suggestion.mediaId ?? '',
          title: suggestion.title,
          artist: suggestion.artist,
          album: suggestion.album,
          description: suggestion.description,
          themes: suggestion.themes,
          genres: suggestion.genres?.join(', '),
          wikiUrl: suggestion.wikiUrl,
          wikidataId: suggestion.wikidataId,
          coverArtUrl: suggestion.coverArtUrl,
          youtubeId: suggestion.youtubeId,
          spotifyId: suggestion.spotifyId,
          mediaType: mediaType,
        );
        // Use the dedicated method - no duplicate drawer creation
        await _showItemDrawerDirect(context, item);
      } else {
        // Fallback - show simple dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Item Details'),
            content: Text('No details found for "$itemName"'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [DRAWER] Error showing item drawer: $e');
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text('Failed to load item details: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  /// Handle actions from the media detail drawer
  Future<void> _handleDrawerAction(
    BuildContext context,
    String action,
    MediaSearchResult item,
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
          mediaType: mediaType,
          vectorMediaId: item.mediaId,
          title: _getBestDisplayName(item),
          primaryCreator: item.artist ?? '', // Handle nullable artist
          coverArtUrl: item.coverArtUrl,
          description: item.description,
          wikiUrl: item.wikiUrl,
          wikidataId: item.wikidataId,
          themes: item.themes,
          genres: null, // TODO: Extract from item if available
          youtubeId: null, // TODO: Extract from item if available
          spotifyId: null, // TODO: Extract from item if available
        );
        debugPrint('🔍 [DRAWER-ACTION] Created new media item with ID: $mediaItemId');
      }

      switch (action) {
        case 'like':
          // Create or update recommendation to liked status
          await _createOrUpdateRecommendation(db, mediaItemId, item, 'liked');
          break;
          
        case 'dislike':
          // Create or update recommendation to disliked status
          await _createOrUpdateRecommendation(db, mediaItemId, item, 'disliked');
          break;
          
        case 'favorite':
          // Add to favorites table (separate from recommendations)
          await db.addToFavorites(mediaItemId);
          break;
          
        case 'watchlist':
          // Add to watchlist table (separate from recommendations)
          await db.addToWatchlist(mediaItemId);
          break;
          
        case 'skip':
          // Create or update recommendation to skipped status
          await _createOrUpdateRecommendation(db, mediaItemId, item, 'skipped');
          break;

        case 'clear_all':
          // Handle the case when no positive reactions remain - set to skipped
          await _createOrUpdateRecommendation(db, mediaItemId, item, 'skipped');
          // Remove from all positive tables
          await db.removeFromFavorites(mediaItemId);
          await db.removeFromWatchlist(mediaItemId);
          break;
      }

      // Keep drawer open - no auto-closing behavior
      
      // Refresh appropriate lists when states change
      await _refreshListsAfterAction(action);
      
    } catch (e) {
      debugPrint('❌ [DRAWER-ACTION] Error handling action $action: $e');
      // No toast notification - just log the error
    }
  }

  /// Create or update recommendation status for an item
  Future<void> _createOrUpdateRecommendation(
    SQLiteDatabase db,
    int mediaItemId,
    MediaSearchResult item,
    String status,
  ) async {
    try {
      // Check if a recommendation already exists for this media item
      final existingRecommendations = await db.getAllMediaSuggestions(mediaType);
      final existingRec = existingRecommendations.where((rec) => 
        rec.mediaItemId?.toString() == mediaItemId.toString() ||
        (rec.title == item.title && rec.artist == item.artist)
      ).firstOrNull;

      if (existingRec != null) {
        // Update existing recommendation status
        final suggestionStatus = SuggestionStatus.values.firstWhere(
          (s) => s.toString().split('.').last == status,
          orElse: () => SuggestionStatus.pending,
        );
        
        await db.updateMediaSuggestionStatus(existingRec.id, suggestionStatus);
        debugPrint('🔄 [DRAWER-ACTION] Updated existing recommendation ${existingRec.id} to $status');
      } else {
        // Create new recommendation with the specified status
        final bestTitle = _getBestDisplayName(item);
        final mediaSuggestion = MediaSuggestion(
          id: -1, // Temporary ID, will be set when saved to database
          query: 'User action from detail view: $bestTitle',
          mediaType: mediaType,
          title: bestTitle,
          artist: item.artist,
          coverArtUrl: item.coverArtUrl,
          description: item.description,
          wikiUrl: item.wikiUrl,
          wikidataId: item.wikidataId,
          themes: item.themes,
          mediaId: item.mediaId,
          botReasoning: 'User selected this item from the detail view.',
          status: SuggestionStatus.values.firstWhere(
            (s) => s.toString().split('.').last == status,
            orElse: () => SuggestionStatus.pending,
          ),
        );
        
        await db.saveMediaSuggestion(mediaSuggestion);
        debugPrint('✅ [DRAWER-ACTION] Created new recommendation with status $status');
      }
    } catch (e) {
      debugPrint('❌ [DRAWER-ACTION] Error creating/updating recommendation: $e');
      rethrow;
    }
  }

  /// Get the best display name for a media item, with fallbacks for missing titles
  String _getBestDisplayName(MediaSearchResult item) {
    return MediaTitleHandler.getBestTitle(
      item.title,
      item.artist,
      item.album,
      mediaType,
    );
  }

  /// Get the appropriate queue name for this media type
  String _getQueueName() {
    switch (mediaType) {
      case 'movie':
        return 'Watchlist';
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

  /// Show a snackbar message
  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }













  // Helper method to build watchlist section (matches TV section exactly)
  Widget _buildWatchlistSection(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32.0), // Add spacing before the title
        Center(
          child: AppTheme.themedLibraryHeader(AppTheme.getMediaListName(mediaType).toUpperCase()),
        ),
        const SizedBox(height: 24.0), // Add spacing between title and content
        ComponentSpacing(
          child: controller.isLoadingDbWatchlist
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFA855F7),
                ),
              )
            : controller.dbWatchlistSuggestions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No ${AppTheme.getMediaPluralDisplayName(mediaType).toLowerCase()} in your ${AppTheme.getMediaListName(mediaType).toLowerCase()} yet. Add suggestions to your ${AppTheme.getMediaListName(mediaType).toLowerCase()} to see them here.',
                      style: const TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _buildWatchlistGrid(context),
        ),
      ],
    );
  }

  // Helper method to build library section (matches TV section exactly)
  Widget _buildLibrarySection(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32.0), // Add spacing before the title
        Center(
          child: AppTheme.themedLibraryHeader('FAVORITES'),
        ),
        const SizedBox(height: 24.0), // Add spacing between title and content
        ComponentSpacing(
          child: controller.isLoadingDbLibrary
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFA855F7),
                ),
              )
            : controller.dbLikedSuggestions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No ${AppTheme.getMediaPluralDisplayName(mediaType).toLowerCase()} in your library yet. Favorite suggestions to see them here.',
                      style: const TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _buildLibraryGrid(context),
        ),
      ],
    );
  }

  Widget _buildWatchlistGrid(BuildContext context) {
    // Always use the media type default format for grids (square for music, poster for others)
    final gridCardFormat = MediaLibraryGrid.getCardFormatForMediaType(mediaType);
    return MediaLibraryGrid(
      suggestions: controller.dbWatchlistSuggestions,
      mediaType: mediaType,
      isWatchlist: true,
      onRemove: _removeFromWatchlist,
      onLike: _likeWatchlistItem,
      onDislike: _dislikeWatchlistItem,
      onFavorite: _favoriteWatchlistItem,
      favoriteItems: controller.dbLikedSuggestions, // Pass favorites so hearts show correctly
      cardFormat: gridCardFormat,
      onTap: (suggestion) => _showMediaLibraryItemDrawer(context, suggestion), // Add tap callback for drawer
    );
  }

  Widget _buildLibraryGrid(BuildContext context) {
    // Always use the media type default format for grids (square for music, poster for others)
    final gridCardFormat = MediaLibraryGrid.getCardFormatForMediaType(mediaType);
    return MediaLibraryGrid(
      suggestions: controller.dbLikedSuggestions,
      mediaType: mediaType,
      isWatchlist: false,
      onAddToWatchlist: _addLibraryItemToWatchlist,
      onUnfavorite: _removeFromLibrary,
      watchlistItems: controller.dbWatchlistSuggestions,
      favoriteItems: controller.dbLikedSuggestions, // All library items are favorites
      cardFormat: gridCardFormat,
      onTap: (suggestion) => _showMediaLibraryItemDrawer(context, suggestion), // Add tap callback for drawer
    );
  }
  
  // Wrapper methods to match MediaLibraryGrid callback signatures
  Future<void> _removeFromWatchlist(MediaSuggestion suggestion) async {
    final db = SQLiteDatabase();
    final intMediaItemId = await db.getMediaItemIdByVectorId(suggestion.mediaItemId!);
    if (intMediaItemId != null) {
      await controller.removeFromWatchlist(intMediaItemId);
    }
  }
  
  Future<void> _likeWatchlistItem(MediaSuggestion suggestion) async {
    await controller.likeWatchlistItem(suggestion);
  }
  
  Future<void> _dislikeWatchlistItem(MediaSuggestion suggestion) async {
    await controller.dislikeWatchlistItem(suggestion);
  }
  
  Future<void> _favoriteWatchlistItem(MediaSuggestion suggestion) async {
    await controller.favoriteWatchlistItem(suggestion);
  }
  
  Future<void> _addLibraryItemToWatchlist(MediaSuggestion suggestion) async {
    await controller.addLibraryItemToWatchlist(suggestion);
  }
  
  Future<void> _removeFromLibrary(MediaSuggestion suggestion) async {
    final db = SQLiteDatabase();
    final intMediaItemId = await db.getMediaItemIdByVectorId(suggestion.mediaItemId!);
    if (intMediaItemId != null) {
      await controller.removeFromFavorites(intMediaItemId);
    }
  }

  /// Refresh appropriate lists after drawer actions
  Future<void> _refreshListsAfterAction(String action) async {
    switch (action) {
      case 'favorite':
        // Refresh library (favorites) when item is favorited
        controller.loadDbLibrary();
        break;
      case 'watchlist':
        // Refresh watchlist when item is added/removed from watchlist
        controller.loadDbWatchlist();
        break;
      case 'like':
      case 'dislike':
        // These actions might affect both lists depending on previous state
        controller.loadDbLibrary();
        controller.loadDbWatchlist();
        break;
    }
  }

  /// Show item drawer by media_item_id (optimized single-query lookup)
  Future<void> _showItemDrawerByMediaItemId(BuildContext context, int mediaItemId) async {
    try {
      debugPrint('🚀 [DRAWER-FAST] Fast lookup for media_item_id: $mediaItemId');
      
      final db = SQLiteDatabase();
      await db.init();
      
      // Single optimized query gets both media item data AND all status information
      final statusResult = await db.getMediaItemWithStatusById(mediaItemId);
      
      if (statusResult == null) {
        debugPrint('❌ [DRAWER-FAST] No media item found with ID: $mediaItemId');
        _showErrorDialog(context, 'Media item not found');
        return;
      }
      
      debugPrint('✅ [DRAWER-FAST] Fast lookup complete for: "${statusResult['title']}" by "${statusResult['primaryCreator']}"');
      
      // Show drawer directly with all status information already loaded
      _showMediaDrawer(
        context,
        MediaDetailDrawer(
          title: statusResult['title'] as String? ?? 'Unknown',
          artist: statusResult['primaryCreator'] as String?,
          description: statusResult['description'] as String?,
          themes: statusResult['themes'] as String?,
          genres: statusResult['genres'] as String?,
          youtubeId: statusResult['youtubeId'] as String?,
          spotifyId: statusResult['spotifyId'] as String?,
          coverArtUrl: statusResult['coverArtUrl'] as String?,
          mediaType: mediaType,
          hasLiked: statusResult['hasLiked'] as bool? ?? false,
          hasDisliked: statusResult['hasDisliked'] as bool? ?? false,
          hasFavorited: statusResult['hasFavorited'] as bool? ?? false,
          isInWatchlist: statusResult['isInWatchlist'] as bool? ?? false,
          hasSkipped: statusResult['hasSkipped'] as bool? ?? false,
          onAction: (action) => _handleDrawerActionById(
            context,
            action,
            mediaItemId,
            statusResult,
          ),
        ),
      );
      
    } catch (e) {
      debugPrint('❌ [DRAWER-FAST] Error in fast lookup: $e');
      _showErrorDialog(context, 'Failed to load item details: $e');
    }
  }

  /// Handle actions from the media detail drawer when using optimized lookup by ID
  Future<void> _handleDrawerActionById(
    BuildContext context,
    String action,
    int mediaItemId,
    Map<String, dynamic> statusResult,
  ) async {
    try {
      final db = SQLiteDatabase();
      
      // We already have the media_item_id, so we can act directly
      switch (action) {
        case 'like':
          // Create or update recommendation to liked status
          await _createOrUpdateRecommendationById(db, mediaItemId, statusResult, 'liked');
          break;
          
        case 'dislike':
          // Create or update recommendation to disliked status
          await _createOrUpdateRecommendationById(db, mediaItemId, statusResult, 'disliked');
          break;
          
        case 'favorite':
          // Add to favorites table (separate from recommendations)
          await db.addToFavorites(mediaItemId);
          break;
          
        case 'watchlist':
          // Add to watchlist table (separate from recommendations)
          await db.addToWatchlist(mediaItemId);
          break;
          
        case 'skip':
          // Create or update recommendation to skipped status
          await _createOrUpdateRecommendationById(db, mediaItemId, statusResult, 'skipped');
          break;

        case 'clear_all':
          // Handle the case when no positive reactions remain - set to skipped
          await _createOrUpdateRecommendationById(db, mediaItemId, statusResult, 'skipped');
          // Remove from all positive tables
          await db.removeFromFavorites(mediaItemId);
          await db.removeFromWatchlist(mediaItemId);
          break;
      }

      // Refresh appropriate lists when states change
      await _refreshListsAfterAction(action);
      
    } catch (e) {
      debugPrint('❌ [DRAWER-ACTION-ID] Error handling action $action for ID $mediaItemId: $e');
      // No toast notification - just log the error
    }
  }

  /// Create or update recommendation status for an item using media_item_id
  Future<void> _createOrUpdateRecommendationById(
    SQLiteDatabase db,
    int mediaItemId,
    Map<String, dynamic> statusResult,
    String status,
  ) async {
    try {
      final title = statusResult['title'] as String? ?? 'Unknown';
      final artist = statusResult['primaryCreator'] as String?;
      
      // Check if a recommendation already exists for this media item
      final existingRecommendations = await db.getAllMediaSuggestions(mediaType);
      final existingRec = existingRecommendations.where((rec) => 
        rec.mediaItemId?.toString() == mediaItemId.toString() ||
        (rec.title == title && rec.artist == artist)
      ).firstOrNull;

      if (existingRec != null) {
        // Update existing recommendation status
        final suggestionStatus = SuggestionStatus.values.firstWhere(
          (s) => s.toString().split('.').last == status,
          orElse: () => SuggestionStatus.pending,
        );
        
        await db.updateMediaSuggestionStatus(existingRec.id, suggestionStatus);
        debugPrint('🔄 [DRAWER-ACTION-ID] Updated existing recommendation ${existingRec.id} to $status');
      } else {
        // Create new recommendation with the specified status
        final vectorMediaId = statusResult['vectorMediaId'] as String? ?? '';
        final mediaSuggestion = MediaSuggestion(
          id: -1, // Temporary ID, will be set when saved to database
          query: 'User action from detail view: $title',
          mediaType: mediaType,
          title: title,
          artist: artist,
          coverArtUrl: statusResult['coverArtUrl'] as String?,
          description: statusResult['description'] as String?,
          wikiUrl: statusResult['wikiUrl'] as String?,
          wikidataId: statusResult['wikidataId'] as String?,
          themes: statusResult['themes'] as String?,
          mediaId: vectorMediaId,
          botReasoning: 'User selected this item from the detail view.',
          status: SuggestionStatus.values.firstWhere(
            (s) => s.toString().split('.').last == status,
            orElse: () => SuggestionStatus.pending,
          ),
        );
        
        await db.saveMediaSuggestion(mediaSuggestion);
        debugPrint('✅ [DRAWER-ACTION-ID] Created new recommendation with status $status');
      }
    } catch (e) {
      debugPrint('❌ [DRAWER-ACTION-ID] Error creating/updating recommendation: $e');
      rethrow;
    }
  }

  /// Estimate text height for description content
  double _estimateTextHeight(String text, TextStyle style, double maxWidth) {
    if (text.isEmpty) return 0.0;
    
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: null,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout(maxWidth: maxWidth);
    return textPainter.size.height;
  }

  /// Estimate text height for reasoning content (includes markdown formatting considerations)
  double _estimateReasoningHeight(String reasoning, double maxWidth) {
    if (reasoning.isEmpty) return 0.0;
    
    // Use AppTheme.reasoningStyle if available, otherwise fallback to default
    final reasoningStyle = AppTheme.mediaDescriptionStyle.copyWith(fontSize: 14);
    
    final textPainter = TextPainter(
      text: TextSpan(text: reasoning, style: reasoningStyle),
      maxLines: null,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout(maxWidth: maxWidth);
    
    // Add slight buffer for markdown formatting and line spacing
    return textPainter.size.height + 8.0;
  }
} 