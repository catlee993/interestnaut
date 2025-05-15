import 'package:flutter/material.dart';
import '../../../theme.dart';
import '../../../models.dart';
import '../../common/icons.dart';
import '../../common/reason_card.dart';

class SuggestionDisplay extends StatefulWidget {
  final MediaItem? suggestedTrack;
  final String? suggestionContext; // Reason for the suggestion
  final bool isProcessingLibrary;
  final String? suggestionError;
  final bool isFetchingSuggestion;
  final VoidCallback onRequestSuggestion;
  final VoidCallback onSkipSuggestion;
  final Function(String) onSuggestionFeedback;
  final VoidCallback onAddToLibrary;
  final bool hasLikedCurrentSuggestion;
  final Function(MediaItem) onPlay;
  final VoidCallback? onPlayPause;
  final MediaItem? nowPlayingTrack;
  final bool isPlaybackPaused;

  const SuggestionDisplay({
    Key? key,
    this.suggestedTrack,
    this.suggestionContext,
    this.isProcessingLibrary = false,
    this.suggestionError,
    this.isFetchingSuggestion = false,
    required this.onRequestSuggestion,
    required this.onSkipSuggestion,
    required this.onSuggestionFeedback,
    required this.onAddToLibrary,
    this.hasLikedCurrentSuggestion = false,
    required this.onPlay,
    this.onPlayPause,
    this.nowPlayingTrack,
    this.isPlaybackPaused = true,
  }) : super(key: key);

  @override
  State<SuggestionDisplay> createState() => _SuggestionDisplayState();
}

class _SuggestionDisplayState extends State<SuggestionDisplay> {
  // Custom styled button
  Widget _buildStyledButton({
    required VoidCallback onPressed,
    required Widget child,
    required String className,
    bool disabled = false,
  }) {
    final bool isFeedbackButton = className.contains('feedback-button');
    
    return ElevatedButton(
      onPressed: disabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isFeedbackButton 
            ? Colors.black.withOpacity(0.7)
            : Colors.white.withOpacity(0.15),
        foregroundColor: Colors.white,
        disabledBackgroundColor: isFeedbackButton 
            ? Colors.black.withOpacity(0.3)
            : Colors.white.withOpacity(0.05),
        disabledForegroundColor: Colors.white.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isFeedbackButton 
              ? BorderSide(
                  color: disabled 
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.3),
                  width: 1,
                )
              : BorderSide.none,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        elevation: 0,
        shadowColor: Colors.transparent,
        textStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: disabled ? Colors.white.withOpacity(0.3) : Colors.white,
        ),
        minimumSize: const Size(0, 40),
      ),
      child: child,
    );
  }
  
  // Custom play button
  Widget _buildPlayButton({
    required VoidCallback onPressed,
    required bool isPlaying,
    bool disabled = false,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: disabled 
            ? AppTheme.primaryColor.withOpacity(0.5)
            : isPlaying
                ? const Color(0xFF9370DB) // var(--primary-hover)
                : AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: IconButton(
        icon: Icon(
          isPlaying ? AppIcons.pause : AppIcons.play,
          size: AppIcons.iconSizeSmall,
          color: disabled ? Colors.white.withOpacity(0.3) : Colors.white,
        ),
        onPressed: disabled ? null : onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (widget.isFetchingSuggestion) {
      return Container(
        constraints: const BoxConstraints(minHeight: 200),
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryColor.withOpacity(0.7),
          ),
        ),
      );
    }

    // Error state
    if (widget.suggestionError != null) {
      final truncatedError = widget.suggestionError!.length > 500
          ? "${widget.suggestionError!.substring(0, 500)}..."
          : widget.suggestionError!;

      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.purpleRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.purpleRed.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              truncatedError,
              style: const TextStyle(
                color: AppTheme.purpleRed,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildStyledButton(
            onPressed: widget.onRequestSuggestion,
            child: const Text('Try Again'),
            className: 'retry-button',
            disabled: widget.isProcessingLibrary,
          ),
        ],
      );
    }

    // Empty state
    if (widget.suggestedTrack == null) {
      return Container(
        constraints: const BoxConstraints(minHeight: 200),
        child: Center(
          child: _buildStyledButton(
            onPressed: widget.onRequestSuggestion,
            child: const Text('Get a Suggestion'),
            className: 'request-suggestion-button',
            disabled: widget.isProcessingLibrary,
          ),
        ),
      );
    }

    // Suggestion display
    final track = widget.suggestedTrack!;
    final isCurrentlyPlaying = widget.nowPlayingTrack?.id == track.id && !widget.isPlaybackPaused;
    
    return Column(
      children: [
        // Album art and info
        if (track.posterPath.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album art
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Opacity(
                  opacity: widget.isProcessingLibrary ? 0.5 : 1.0,
                  child: Image.network(
                    track.posterPath,
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 140,
                        height: 140,
                        color: AppTheme.cardBackgroundColor,
                        child: const Center(
                          child: Icon(Icons.music_note, size: 48, color: Colors.white54),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 24),
              
              // Track info and reason
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 24,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      track.overview,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Reason card
                    if (widget.suggestionContext != null && widget.suggestionContext!.isNotEmpty)
                      ReasonCard(reason: widget.suggestionContext!),
                  ],
                ),
              ),
            ],
          ),
        
        const SizedBox(height: 32),
        
        // Action buttons
        Opacity(
          opacity: widget.isProcessingLibrary ? 0.5 : 1.0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Play button
              _buildPlayButton(
                onPressed: () {
                  if (isCurrentlyPlaying && widget.onPlayPause != null) {
                    widget.onPlayPause!();
                  } else {
                    widget.onPlay(track);
                  }
                },
                isPlaying: isCurrentlyPlaying,
                disabled: widget.isProcessingLibrary,
              ),
              const SizedBox(width: 10),
              
              // Like button
              _buildStyledButton(
                onPressed: () => widget.onSuggestionFeedback('like'),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.thumbUp, size: AppIcons.iconSizeSmall),
                    SizedBox(width: 8),
                    Text('Like'),
                  ],
                ),
                className: 'feedback-button like-button',
                disabled: widget.isProcessingLibrary,
              ),
              const SizedBox(width: 10),
              
              // Dislike button
              _buildStyledButton(
                onPressed: () => widget.onSuggestionFeedback('dislike'),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.thumbDown, size: AppIcons.iconSizeSmall),
                    SizedBox(width: 8),
                    Text('Dislike'),
                  ],
                ),
                className: 'feedback-button dislike-button',
                disabled: widget.isProcessingLibrary,
              ),
              const SizedBox(width: 10),
              
              // Add to library button
              _buildStyledButton(
                onPressed: widget.onAddToLibrary,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AppIcons.plus, size: AppIcons.iconSizeSmall),
                    SizedBox(width: 8),
                    Text('Add to Library'),
                  ],
                ),
                className: 'action-button add-button',
                disabled: widget.isProcessingLibrary,
              ),
              const SizedBox(width: 10),
              
              // Skip/Next button
              _buildStyledButton(
                onPressed: widget.onSkipSuggestion,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.hasLikedCurrentSuggestion ? 'Next' : 'Skip'),
                    const SizedBox(width: 8),
                    const Icon(AppIcons.stepForward, size: AppIcons.iconSizeSmall),
                  ],
                ),
                className: 'action-button next-button',
                disabled: widget.isProcessingLibrary,
              ),
            ],
          ),
        ),
      ],
    );
  }
} 