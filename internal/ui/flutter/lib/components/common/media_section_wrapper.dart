import 'package:flutter/material.dart';
import 'media_detail_drawer.dart';
import '../../db/vector_db.dart';
import '../../services/sqlite_db.dart'; // Fixed import path
import '../../services/recommendation_service.dart'; // For MediaSuggestion and SuggestionStatus
import 'suggestion_action_buttons.dart';
import 'loading_suggestion.dart';
import 'base_media_section_controller.dart';
import 'media_library_grid.dart'; // For CardFormat enum
import 'scroll_content_wrapper.dart'; // For MediaSectionLayout
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
                      child: _buildWatchlistSection(),
                    ),
                  
                  // Library section with proper spacing - only show if not empty or loading
                  if (controller.dbLikedSuggestions.isNotEmpty || controller.isLoadingDbLibrary)
                    SectionSpacing(
                      child: _buildLibrarySection(),
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
                    suggestion.title ?? 'Unknown ${AppTheme.getMediaDisplayName(mediaType)}',
                    style: AppTheme.mediaTitleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  
                  // Artist/creator info
                  if (suggestion.artist?.isNotEmpty == true)
                    Text(
                      _getArtistText(suggestion.artist!),
                      style: AppTheme.mediaArtistStyle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildDynamicContentLayout({
    required BoxConstraints constraints,
    required BuildContext context,
    String? description,
    String? reasoning,
  }) {
    // Calculate optimal heights based on content
    final hasDescription = description?.isNotEmpty == true;
    final hasReasoning = reasoning?.isNotEmpty == true;
    
    if (!hasDescription && !hasReasoning) {
      return const SizedBox.shrink();
    }
    
    if (!hasDescription && hasReasoning) {
      // Only reasoning - use most of the space
      return Column(
        children: [
          Expanded(child: _buildRichTextReasoning(reasoning!, context)),
        ],
      );
    }
    
    if (hasDescription && !hasReasoning) {
      // Only description - use all space
      return Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SingleChildScrollView(
                child: Text(
                  description!,
                  style: AppTheme.mediaDescriptionStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    // Both present - measure description and allocate remaining space to reasoning
    return LayoutBuilder(
      builder: (context, innerConstraints) {
        // Measure how much space the description actually needs
        final textPainter = TextPainter(
          text: TextSpan(
            text: description!,
            style: AppTheme.mediaDescriptionStyle,
          ),
          textDirection: TextDirection.ltr,
          maxLines: null,
        );
        textPainter.layout(maxWidth: innerConstraints.maxWidth);
        
                         final descriptionNaturalHeight = textPainter.size.height;
        final availableHeight = innerConstraints.maxHeight;
        final spacing = 16.0;
        final minimumReasoningHeight = 100.0;
        
        // Account for ALL spacing overhead in the layout
        // Description padding (8px) + middle spacing (16px) + reasoning header+divider+spacing (~31px) + reasoning bottom margin (12px)
        final totalLayoutOverhead = 8.0 + 16.0 + 31.0 + 12.0; // ~67px
        final usableHeight = availableHeight - totalLayoutOverhead;
        
        // Calculate how much space to give each section
        double descriptionHeight;
        double reasoningHeight;
        
        // Default split: 60% description, 40% reasoning (based on usable height)
        final descriptionPreferredSpace = usableHeight * 0.6;
        final reasoningPreferredSpace = usableHeight * 0.4;
        
        if (descriptionNaturalHeight <= descriptionPreferredSpace) {
          // Description fits in preferred space or less - give it what it needs
          descriptionHeight = descriptionNaturalHeight + 8.0; // Include its padding
          reasoningHeight = availableHeight - descriptionHeight - spacing;
        } else {
          // Description needs more than 60% - give description 60%, reasoning 40%
          descriptionHeight = descriptionPreferredSpace + 8.0; // Include its padding
          reasoningHeight = reasoningPreferredSpace + spacing; // Include remaining overhead
        }
        
        return Column(
          children: [
            // Description with calculated height - account for its own padding
            Container(
              height: descriptionHeight,
              padding: const EdgeInsets.only(bottom: 8),
              child: SingleChildScrollView(
                child: Text(
                  description!,
                  style: AppTheme.mediaDescriptionStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            
            SizedBox(height: spacing),
            
            // Reasoning with remaining height
            SizedBox(
              height: reasoningHeight,
              child: _buildRichTextReasoning(reasoning!, context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRichTextReasoning(String reasoning, BuildContext context) {
    return Container(
      width: double.infinity,
      child: SingleChildScrollView(
        child: _buildIndependentReasoningSections(reasoning, mediaType, context),
      ),
    );
  }

  void _showMediaDrawer(BuildContext context, MediaDetailDrawer drawer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => drawer,
    );
  }

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
        
        // Get comprehensive status from all tables (recommendations, favorites, watchlist)
        final db = SQLiteDatabase();
        final statusResult = await db.getMediaItemStatusByProperties(
          title: item.title ?? 'Unknown Title', // Handle nullable title
          mediaType: mediaType,
          primaryCreator: item.artist ?? '', // Handle nullable artist
        );
        
        debugPrint('🔍 [DRAWER] Status for "${item.title}": $statusResult');
        
        _showMediaDrawer(
          context,
          MediaDetailDrawer(
            title: item.title ?? 'Unknown Title',
            artist: item.artist,
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
          title: item.title ?? 'Unknown Title', // Handle nullable title
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
          _showSnackBar(context, 'Added "${item.title}" to liked items');
          break;
          
        case 'dislike':
          // Create or update recommendation to disliked status
          await _createOrUpdateRecommendation(db, mediaItemId, item, 'disliked');
          _showSnackBar(context, 'Marked "${item.title}" as disliked');
          break;
          
        case 'favorite':
          // Add to favorites table (separate from recommendations)
          await db.addToFavorites(mediaItemId);
          _showSnackBar(context, 'Added "${item.title}" to favorites');
          break;
          
        case 'watchlist':
          // Add to watchlist table (separate from recommendations)
          await db.addToWatchlist(mediaItemId);
          final queueName = _getQueueName();
          _showSnackBar(context, 'Added "${item.title}" to $queueName');
          break;
          
        case 'skip':
          // Create or update recommendation to skipped status
          await _createOrUpdateRecommendation(db, mediaItemId, item, 'skipped');
          _showSnackBar(context, 'Skipped "${item.title}"');
          break;
      }

      // Close the drawer after action
      Navigator.of(context).pop();
      
      // Note: Controller refresh methods are not available in BaseMediaSectionController
      // The UI will update naturally when the user navigates back to the main views
      
    } catch (e) {
      debugPrint('❌ [DRAWER-ACTION] Error handling action $action: $e');
      _showSnackBar(context, 'Error: $e', isError: true);
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
        final mediaSuggestion = MediaSuggestion(
          mediaItemId: mediaItemId,
          query: 'User action from detail view: ${item.title ?? 'Unknown'}',
          mediaType: mediaType,
          title: item.title ?? 'Unknown Title', // Handle nullable title
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

  Widget _buildIndependentReasoningSections(String reasoning, String mediaType, BuildContext context) {
    // Parse the structured reasoning text into two clean sections
    final lines = reasoning.split('\n');
    final detectedThemes = <String>[];
    final matchSources = <String>[];
    
    List<String> currentSection = detectedThemes;
    bool isFirstSection = true;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      if (line.startsWith('**') && line.endsWith('**')) {
        // Switch to second section on second header
        if (!isFirstSection) {
          currentSection = matchSources;
        }
        isFirstSection = false;
        continue;
      } else if (line.startsWith('━')) {
        // Skip ASCII underlines
        continue;
      } else if (line.startsWith('• ')) {
        // Remove bullet and add to section
        currentSection.add(line.substring(2));
      } else if (line.isNotEmpty) {
        // Regular text line
        currentSection.add(line);
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Detected Themes Section
        if (detectedThemes.isNotEmpty) ...[
          _buildCleanSection(
            title: 'Detected Themes',
            items: detectedThemes,
            rightAlign: false,
            onChipTap: (item) => _showItemDrawer(context, item),
          ),
          const SizedBox(height: 16),
        ],
        
        // Match Sources Section  
        if (matchSources.isNotEmpty) ...[
          _buildCleanSection(
            title: 'Match Sources',
            items: matchSources,
            rightAlign: false, // Keep consistent alignment
            onChipTap: (item) => _showItemDrawer(context, item),
          ),
        ],
      ],
    );
  }

  Widget _buildCleanSection({
    required String title,
    required List<String> items,
    required bool rightAlign,
    Function(String)? onChipTap,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: rightAlign ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Section title
          Text(
            title,
            style: AppTheme.headerSelectorStyle.copyWith(
              fontSize: 13,
              color: AppTheme.primaryColor,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          
          // Smart layout: dots for short items, wrapping for long ones
          _buildSmartItemLayout(items, rightAlign, onChipTap),
        ],
      ),
    );
  }

  Widget _buildSmartItemLayout(List<String> items, bool rightAlign, Function(String)? onChipTap) {
    // Always use clickable chips when onChipTap is provided (for drawer functionality)
    if (onChipTap != null) {
      return Wrap(
        alignment: rightAlign ? WrapAlignment.end : WrapAlignment.start,
        spacing: 12.0, // Horizontal spacing between items
        runSpacing: 4.0, // Vertical spacing between lines
        children: items.map((item) => GestureDetector(
          onTap: () => onChipTap(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF8C86E2).withOpacity(0.4),
                width: 0.5,
              ),
            ),
            child: Text(
              item,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w300,
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 0.2,
              ),
            ),
          ),
        )).toList(),
      );
    } else {
      // Check if all items are reasonably short for dot layout (fallback for non-clickable items)
      final allShort = items.every((item) => item.length <= 25);
      
      if (allShort && items.length <= 4) {
        // Use dot-separated layout for short items - not clickable
        return Text(
          items.join(' • '),
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w300,
            fontSize: 13,
            color: Colors.white.withOpacity(0.85),
            letterSpacing: 0.3,
            height: 1.4,
          ),
          textAlign: rightAlign ? TextAlign.right : TextAlign.left,
        );
      } else {
        // Use wrapping layout for longer items - not clickable
        return Wrap(
          alignment: rightAlign ? WrapAlignment.end : WrapAlignment.start,
          spacing: 12.0,
          runSpacing: 4.0,
          children: items.map((item) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Text(
              item,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w300,
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 0.2,
              ),
            ),
          )).toList(),
        );
      }
    }
  }

  Widget _buildColumnarReasoningContent(String reasoning, String mediaType) {
    // Parse the structured reasoning text into two sections
    final lines = reasoning.split('\n');
    final firstSectionWidgets = <Widget>[];
    final secondSectionWidgets = <Widget>[];
    
    List<Widget> currentSection = firstSectionWidgets;
    bool isFirstSection = true;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      if (line.startsWith('**') && line.endsWith('**')) {
        // Header line - switch to second section if this is the second header
        String headerText;
        
        if (isFirstSection) {
          headerText = 'Detected Themes';
          currentSection = firstSectionWidgets;
        } else {
          headerText = 'Match Sources';
          currentSection = secondSectionWidgets;
        }
        isFirstSection = false;
        
        currentSection.add(
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(
              bottom: 8, 
              top: currentSection == secondSectionWidgets ? 16 : 0
            ),
            child: Text(
              headerText,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w300,
                fontSize: 15.0,
                color: Color(0xFF8C86E2),
                letterSpacing: 0.5,
              ).copyWith(
                color: const Color(0xFF8C86E2).withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      } else if (line.startsWith('━')) {
        // Skip ASCII underlines - we use proper underlines now
        continue;
      } else if (line.startsWith('• ')) {
        // Remove bullet and center the text
        final bulletText = line.substring(2);
        currentSection.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 3),
            child: Text(
              bulletText,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w300,
                fontSize: 13,
                color: Colors.white.withOpacity(0.85),
                letterSpacing: 0.3,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      } else {
        // Regular text line
        currentSection.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 3),
            child: Text(
              line,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w300,
                fontSize: 13,
                color: Colors.white.withOpacity(0.85),
                letterSpacing: 0.3,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // First section - Detected Themes
        ...firstSectionWidgets,
        // Second section - Match Sources  
        ...secondSectionWidgets,
      ],
    );
  }

  // Helper method to build watchlist section (matches TV section exactly)
  Widget _buildWatchlistSection() {
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
              : _buildWatchlistGrid(),
        ),
      ],
    );
  }

  // Helper method to build library section (matches TV section exactly)
  Widget _buildLibrarySection() {
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
              : _buildLibraryGrid(),
        ),
      ],
    );
  }

  Widget _buildWatchlistGrid() {
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
      cardFormat: gridCardFormat,
    );
  }

  Widget _buildLibraryGrid() {
    // Always use the media type default format for grids (square for music, poster for others)
    final gridCardFormat = MediaLibraryGrid.getCardFormatForMediaType(mediaType);
    return MediaLibraryGrid(
      suggestions: controller.dbLikedSuggestions,
      mediaType: mediaType,
      isWatchlist: false,
      onAddToWatchlist: _addLibraryItemToWatchlist,
      onUnfavorite: _removeFromLibrary,
      watchlistItems: controller.dbWatchlistSuggestions,
      cardFormat: gridCardFormat,
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
} 