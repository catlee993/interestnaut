import 'package:flutter/material.dart';
import 'media_detail_drawer.dart';
import '../../db/vector_db.dart';
import '../../services/sqlite_db.dart'; // Fixed import path
import '../../services/recommendation_service.dart'; // For MediaSuggestion and SuggestionStatus
import '../../utils/media_title_handler.dart';
import 'suggestion_action_buttons.dart';
import 'loading_suggestion.dart';
import 'base_media_section_controller.dart';
import 'media_library_grid.dart'; // For CardFormat enum
import 'scroll_content_wrapper.dart'; // For MediaSectionLayout
import 'suggestion_reasoning_display.dart'; // New reasoning component
import '../../theme.dart';
import '../../utils/text_utils.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models.dart';

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
                  
                  // Action buttons using generic component (INSIDE the suggestion pane)
                  SuggestionActionButtons(
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
      return _buildDescriptionOnlyLayout(description!, availableHeight);
    }
    
    if (hasReasoning && !hasDescription) {
      return _buildReasoningOnlyLayout(reasoning!, availableHeight, context);
    }
    
    // Both description and reasoning exist - smart allocation
    return _buildDualContentLayout(
      description: description!,
      reasoning: reasoning!,
      availableHeight: availableHeight,
      context: context,
    );
  }

  /// Build layout with description only (full height)
  Widget _buildDescriptionOnlyLayout(String description, double availableHeight) {
    return Container(
      height: availableHeight,
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
    );
  }

  /// Build layout with reasoning only (full height)
  Widget _buildReasoningOnlyLayout(String reasoning, double availableHeight, BuildContext context) {
    return Container(
      height: availableHeight,
      child: SuggestionReasoningDisplay(
        reasoning: reasoning,
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
  }) {
    // Calculate content sizes for smart allocation
    final descriptionLength = description.length;
    final reasoningComplexity = _calculateReasoningComplexity(reasoning);
    
    // Smart height allocation based on content
    double descriptionRatio;
    
    if (descriptionLength < 200 && reasoningComplexity > 0.7) {
      // Short description, complex reasoning -> favor reasoning
      descriptionRatio = 0.25;
    } else if (descriptionLength > 800 && reasoningComplexity < 0.5) {
      // Long description, simple reasoning -> favor description
      descriptionRatio = 0.65;
    } else {
      // Balanced allocation
      descriptionRatio = 0.4;
    }
    
    final descriptionHeight = (availableHeight * descriptionRatio).clamp(80.0, availableHeight * 0.7);
    final reasoningHeight = availableHeight - descriptionHeight - 16; // 16px spacing
    
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
      // Get comprehensive status from all tables (recommendations, favorites, watchlist)
      final db = SQLiteDatabase();
      final bestTitle = _getBestDisplayName(item);
      final statusResult = await db.getMediaItemStatusByProperties(
        title: bestTitle, 
        mediaType: mediaType,
        primaryCreator: item.artist ?? '', // Handle nullable artist
      );
      
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
      final vectorDb = VectorDatabase();
      await vectorDb.init();
      
      final item = await vectorDb.getMediaById(mediaId: mediaId, mediaType: mediaType);
      
      if (item != null) {
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
        similarity: 1.0, // Default similarity for library items
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
      // Look up the actual item from the database
      final vectorDb = VectorDatabase();
      await vectorDb.init();
      
      final results = await vectorDb.searchByText(
        query: itemName,
        mediaType: mediaType,
        limit: 1,
      );
      
      if (results.isNotEmpty) {
        final item = results.first;
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
        rec.mediaItemId == mediaItemId ||
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
          mediaItemId: mediaItemId,
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
    await controller.removeFromWatchlist(suggestion.mediaItemId!);
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
    await controller.removeFromFavorites(suggestion.mediaItemId!);
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

  /// Show item drawer by media_item_id (direct SQLite lookup - fastest)
  Future<void> _showItemDrawerByMediaItemId(BuildContext context, int mediaItemId) async {
    try {
      debugPrint('🔍 [DRAWER-SQLITE] Looking up item by media_item_id: $mediaItemId');
      
      final db = SQLiteDatabase();
      await db.init();
      
      // Get the media item directly from SQLite
      final mediaItemData = await db.getMediaItemById(mediaItemId);
      
      if (mediaItemData == null) {
        debugPrint('❌ [DRAWER-SQLITE] No media item found with ID: $mediaItemId');
        _showErrorDialog(context, 'Media item not found');
        return;
      }
      
      // Convert SQLite data to MediaSearchResult format
      final item = MediaSearchResult(
        title: mediaItemData['title'] as String,
        artist: mediaItemData['primaryCreator'] as String?,
        album: null, // Not stored in media_items table
        description: mediaItemData['description'] as String?,
        themes: mediaItemData['themes'] as String?,
        coverArtUrl: mediaItemData['coverArtUrl'] as String?,
        wikiUrl: mediaItemData['wikiUrl'] as String?,
        wikidataId: mediaItemData['wikidataId'] as String?,
        mediaId: mediaItemData['vectorMediaId'] as String,
        similarity: 1.0, // Direct lookup, perfect match
        mediaType: mediaType,
      );
      
      debugPrint('✅ [DRAWER-SQLITE] Found item: "${item.title}" by "${item.artist}"');
      await _showItemDrawerDirect(context, item);
      
    } catch (e) {
      debugPrint('❌ [DRAWER-SQLITE] Error showing item drawer by media_item_id: $e');
      _showErrorDialog(context, 'Failed to load item details: $e');
    }
  }
} 