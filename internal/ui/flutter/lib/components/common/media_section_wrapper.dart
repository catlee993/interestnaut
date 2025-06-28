import 'package:flutter/material.dart';
import 'suggestion_action_buttons.dart';
import 'loading_suggestion.dart';
import 'base_media_section_controller.dart';
import 'media_library_grid.dart'; // For CardFormat enum
import 'scroll_content_wrapper.dart'; // For MediaSectionLayout
import '../../theme.dart';
import '../../services/recommendation_service.dart';
import '../../utils/text_utils.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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
          Expanded(child: _buildRichTextReasoning(reasoning!)),
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
              child: _buildRichTextReasoning(reasoning!),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRichTextReasoning(String reasoning) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FontAwesomeIcons.robot,
                size: 16,
                color: const Color(0xFF8C86E2).withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Reasoning',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: const Color(0xFF8C86E2).withOpacity(0.7),
                  fontWeight: FontWeight.w300,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 1,
            color: const Color(0xFF7B68EE).withOpacity(0.2),
          ),
          const SizedBox(height: 6),
          
          // Rich text content in columnar layout
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(left: 24, right: 24), // Balanced padding for columns
                child: _buildColumnarReasoningContent(reasoning, mediaType),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnarReasoningContent(String reasoning, String mediaType) {
    // Parse the structured reasoning text into two sections
    final lines = reasoning.split('\n');
    final leftColumnWidgets = <Widget>[];
    final rightColumnWidgets = <Widget>[];
    
    List<Widget> currentColumn = leftColumnWidgets;
    bool isFirstSection = true;
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      if (line.startsWith('**') && line.endsWith('**')) {
        // Header line - switch to right column if this is the second header
        String headerText;
        
        if (isFirstSection) {
          // First header - use dynamic media type
          headerText = '${AppTheme.getMediaDisplayName(mediaType)} Themes';
          currentColumn = leftColumnWidgets;
        } else {
          // Second header - use dynamic media type for related items
          headerText = 'Related ${AppTheme.getMediaPluralDisplayName(mediaType)}';
          currentColumn = rightColumnWidgets;
        }
        isFirstSection = false;
        
        currentColumn.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6, top: 6),
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
        currentColumn.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 2),
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
        currentColumn.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 2),
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
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column - Matched Themes
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // Center everything
            children: leftColumnWidgets,
          ),
        ),
        const SizedBox(width: 20), // Space between columns
        // Right column - User Preferences
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center, // Center everything
            children: rightColumnWidgets,
          ),
        ),
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