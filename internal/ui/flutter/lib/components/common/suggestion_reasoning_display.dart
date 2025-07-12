import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/sqlite_db.dart';
import '../../enums/media_type.dart';

/// Handles the display of suggestion reasoning sections including themes, match sources, and custom matching
class SuggestionReasoningDisplay extends StatefulWidget {
  final String reasoning;
  final String mediaType;
  final Function(BuildContext, int) onMatchSourceTap;
  final Function(BuildContext, String) onMatchSourceFallback;

  const SuggestionReasoningDisplay({
    Key? key,
    required this.reasoning,
    required this.mediaType,
    required this.onMatchSourceTap,
    required this.onMatchSourceFallback,
  }) : super(key: key);

  @override
  State<SuggestionReasoningDisplay> createState() => _SuggestionReasoningDisplayState();
}

class _SuggestionReasoningDisplayState extends State<SuggestionReasoningDisplay> {
  Map<String, List<String>>? _customMatchingConstraints;
  bool _isLoadingConstraints = false;
  double _similarityThreshold = 0.5; // Default value
  bool _isLoadingSettings = false;

  @override
  void initState() {
    super.initState();
    _loadCustomMatchingConstraints();
    _loadMediaSettings();
  }

  /// Convert header media type to database media type using enum
  String _getDbMediaType() {
    try {
      final mediaType = MediaType.fromHeaderName(widget.mediaType);
      return mediaType.databaseName;
    } catch (e) {
      debugPrint('❌ [MEDIA-TYPE] Unknown media type: ${widget.mediaType}');
      return widget.mediaType; // Fallback to original string
    }
  }

  /// Get match style label based on similarity threshold
  String _getMatchStyleLabel(double threshold) {
    if (threshold <= 0.1) return 'Bohemian';
    if (threshold <= 0.3) return 'Eclectic';
    if (threshold <= 0.5) return 'Versatile';
    if (threshold <= 0.7) return 'Discerning';
          return 'Meticulous';
  }

  /// Load media settings to get similarity threshold
  Future<void> _loadMediaSettings() async {
    setState(() {
      _isLoadingSettings = true;
    });

    try {
      final dbMediaType = _getDbMediaType();
      debugPrint('🔍 [SETTINGS] Loading media settings for ${widget.mediaType} -> $dbMediaType');
      final db = SQLiteDatabase();
      await db.init();
      final mediaSettings = await db.getMediaSettings(dbMediaType);
      
      if (mounted) {
        setState(() {
          _similarityThreshold = mediaSettings?['similarity_matching'] ?? 0.5;
          _isLoadingSettings = false;
        });
        debugPrint('✅ [SETTINGS] Loaded similarity threshold: $_similarityThreshold');
      }
    } catch (e) {
      debugPrint('❌ [SETTINGS] Error loading media settings: $e');
      if (mounted) {
        setState(() {
          _similarityThreshold = 0.5; // Default fallback
          _isLoadingSettings = false;
        });
      }
    }
  }

  Future<void> _loadCustomMatchingConstraints() async {
    setState(() {
      _isLoadingConstraints = true;
    });

    try {
      final dbMediaType = _getDbMediaType();
      debugPrint('🔍 [CUSTOM-MATCHING] Fetching constraints for ${widget.mediaType} -> $dbMediaType');
      final db = SQLiteDatabase();
      await db.init();
      final result = await db.getMediaMatchingConstraints(dbMediaType);
      debugPrint('🔍 [CUSTOM-MATCHING] Got result: $result');
      
      if (mounted) {
        setState(() {
          _customMatchingConstraints = result;
          _isLoadingConstraints = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [CUSTOM-MATCHING] Error getting constraints: $e');
      if (mounted) {
        setState(() {
          _customMatchingConstraints = {'include': [], 'exclude': []};
          _isLoadingConstraints = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8C86E2).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        thickness: 3.0,
        radius: const Radius.circular(2.0),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          child: _buildReasoningSections(context),
        ),
      ),
    );
  }

  Widget _buildReasoningSections(BuildContext context) {
    // Parse the structured reasoning text into sections
    final lines = widget.reasoning.split('\n');
    final detectedThemes = <String>[];
    final matchSources = <Map<String, String>>[];
    
    List<dynamic> currentSection = detectedThemes;
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
        final content = line.substring(2);
        if (currentSection == matchSources) {
          // Parse match sources as "Title|mediaItemId" format
          final parts = content.split('|');
          final title = parts[0].trim();
          final mediaItemId = parts.length > 1 ? parts[1].trim() : '';
          matchSources.add({'title': title, 'mediaItemId': mediaItemId});
        } else {
          detectedThemes.add(content);
        }
      } else if (line.isNotEmpty) {
        // Regular text line
        if (currentSection == matchSources) {
          // Parse match sources as "Title|mediaItemId" format
          final parts = line.split('|');
          final title = parts[0].trim();
          final mediaItemId = parts.length > 1 ? parts[1].trim() : '';
          matchSources.add({'title': title, 'mediaItemId': mediaItemId});
        } else {
          detectedThemes.add(line);
        }
      }
    }
    
    final hasDetectedThemes = detectedThemes.isNotEmpty;
    final hasMatchSources = matchSources.isNotEmpty;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Detected Themes Section
        if (hasDetectedThemes) ...[
          _buildThemesSection(detectedThemes),
          const SizedBox(height: 12),
        ],
        
        // Match Sources Section  
        if (hasMatchSources) ...[
          _buildMatchSourcesSection(matchSources, context),
          const SizedBox(height: 12),
        ],
        
        // Match Details Section (always shown)
        _buildMatchDetailsSection(context),
      ],
    );
  }

  Widget _buildThemesSection(List<String> themes) {
    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform(
            transform: Matrix4.identity()..scale(1.15, 1.0),
            alignment: Alignment.centerLeft,
            child: Text(
              'DETECTED THEMES',
              style: AppTheme.reasoningHeaderStyle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            themes.join(' • '),
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w300,
              fontSize: 13,
              color: Colors.white.withOpacity(0.85),
              letterSpacing: 0.3,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchSourcesSection(List<Map<String, String>> sources, BuildContext context) {
    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform(
            transform: Matrix4.identity()..scale(1.15, 1.0),
            alignment: Alignment.centerLeft,
            child: Text(
              'MATCH SOURCES',
              style: AppTheme.reasoningHeaderStyle,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12.0,
            runSpacing: 4.0,
            children: sources.map((source) {
              final title = source['title'] ?? '';
              final mediaItemId = source['mediaItemId'] ?? '';
              
              return GestureDetector(
                onTap: () {
                  if (mediaItemId.isNotEmpty) {
                    widget.onMatchSourceTap(context, int.parse(mediaItemId));
                  } else {
                    widget.onMatchSourceFallback(context, title);
                  }
                },
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
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w300,
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.9),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchDetailsSection(BuildContext context) {
    final matchStyle = _getMatchStyleLabel(_similarityThreshold);
    
    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform(
            transform: Matrix4.identity()..scale(1.15, 1.0),
            alignment: Alignment.centerLeft,
            child: Text(
              '${matchStyle.toUpperCase()} MATCHING',
              style: AppTheme.reasoningHeaderStyle,
            ),
          ),
          const SizedBox(height: 6),
          
          // Custom Matching (only shown if constraints exist)
          if (_customMatchingConstraints != null && !_isLoadingConstraints) ...[
            _buildCustomMatchingContent(),
          ],
        ],
      ),
    );
  }

  Widget _buildMatchStyleChip() {
    final matchStyle = _getMatchStyleLabel(_similarityThreshold);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Text(
        matchStyle,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w400,
          fontSize: 12,
          color: AppTheme.primaryColor.withOpacity(0.9),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCustomMatchingContent() {
    final constraints = _customMatchingConstraints!;
    
    // Database returns 'positive' and 'negative' keys
    final includeItems = (constraints['positive'] as List<dynamic>?)?.cast<String>() ?? [];
    final excludeItems = (constraints['negative'] as List<dynamic>?)?.cast<String>() ?? [];
    
    if (includeItems.isEmpty && excludeItems.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return _buildTwoLineCustomMatchingText(includeItems, excludeItems);
  }

  /// Build two-line custom matching text with proper wrapping and indentation
  Widget _buildTwoLineCustomMatchingText(List<String> includeItems, List<String> excludeItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Include line
        if (includeItems.isNotEmpty)
          _buildConstraintLine('INCLUDE:', includeItems, AppTheme.includeColor),
        
        // Add spacing between lines if both exist
        if (includeItems.isNotEmpty && excludeItems.isNotEmpty)
          const SizedBox(height: 2),
        
        // Exclude line  
        if (excludeItems.isNotEmpty)
          _buildConstraintLine('EXCLUDE:', excludeItems, AppTheme.excludeColor),
      ],
    );
  }
  
  /// Build a single constraint line with proper wrapping and indentation
  Widget _buildConstraintLine(String label, List<String> items, Color labelColor) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: labelColor.withOpacity(0.9),
              letterSpacing: 0.2,
            ),
          ),
                  TextSpan(
          text: items.join(' • '),
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w300,
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
            letterSpacing: 0.2,
          ),
        ),
        ],
      ),
    );
  }
} 