import 'package:flutter/material.dart';
import '../../theme.dart';

/// Panel for selecting other media types to blend into suggestions
class MediaBlendPanel extends StatefulWidget {
  final String currentMediaType;

  const MediaBlendPanel({
    Key? key,
    required this.currentMediaType,
  }) : super(key: key);

  @override
  State<MediaBlendPanel> createState() => _MediaBlendPanelState();
}

class _MediaBlendPanelState extends State<MediaBlendPanel> {
  final Map<String, bool> _blendSettings = {
    'music': false,
    'movies': false,
    'tv': false,
    'books': false,
    'games': false,
  };

  final Map<String, String> _mediaDisplayNames = {
    'music': 'Music',
    'movies': 'Movies',
    'tv': 'TV Shows',
    'books': 'Books',
    'games': 'Games',
  };

  final Map<String, IconData> _mediaIcons = {
    'music': Icons.music_note,
    'movies': Icons.movie,
    'tv': Icons.tv,
    'books': Icons.book,
    'games': Icons.sports_esports,
  };

  final Map<String, String> _mediaDescriptions = {
    'music': 'Include music themes, moods, and genres',
    'movies': 'Include movie themes, genres, and storytelling elements',
    'tv': 'Include TV show themes, genres, and narrative styles',
    'books': 'Include book themes, genres, and literary elements',
    'games': 'Include game themes, genres, and interactive elements',
  };

  @override
  void initState() {
    super.initState();
    // Remove current media type from blend options
    _blendSettings.remove(widget.currentMediaType);
  }

  void _toggleBlend(String mediaType, bool value) {
    setState(() {
      _blendSettings[mediaType] = value;
    });
  }

  Widget _buildBlendOption(String mediaType) {
    final isEnabled = _blendSettings[mediaType] ?? false;
    final displayName = _mediaDisplayNames[mediaType] ?? mediaType;
    final icon = _mediaIcons[mediaType] ?? Icons.help;
    final description = _mediaDescriptions[mediaType] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isEnabled 
            ? AppTheme.primaryColor.withOpacity(0.1) 
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isEnabled 
              ? AppTheme.primaryColor.withOpacity(0.4) 
              : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _toggleBlend(mediaType, !isEnabled),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isEnabled 
                        ? AppTheme.primaryColor.withOpacity(0.2) 
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isEnabled 
                          ? AppTheme.primaryColor.withOpacity(0.4) 
                          : Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isEnabled 
                        ? AppTheme.primaryColor 
                        : Colors.white.withOpacity(0.7),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Checkbox
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isEnabled 
                        ? AppTheme.primaryColor 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isEnabled 
                          ? AppTheme.primaryColor 
                          : Colors.white.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: isEnabled
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlendSummary() {
    final enabledMedia = _blendSettings.entries
        .where((entry) => entry.value)
        .map((entry) => _mediaDisplayNames[entry.key] ?? entry.key)
        .toList();

    if (enabledMedia.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.white.withOpacity(0.5),
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              'Pure ${_mediaDisplayNames[widget.currentMediaType]} Mode',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Recommendations will focus only on ${widget.currentMediaType} without cross-media influences',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'BLEND ACTIVE',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your ${widget.currentMediaType} suggestions will be enhanced with themes and elements from: ${enabledMedia.join(", ")}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'MEDIA BLEND',
              style: TextStyle(
                color: AppTheme.primaryColor.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enhance your ${_mediaDisplayNames[widget.currentMediaType]} suggestions by blending themes and elements from other media types',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 24),
            
            // Blend options
            ...(_blendSettings.keys.map((mediaType) => _buildBlendOption(mediaType)).toList()),
            
            const SizedBox(height: 24),
            
            // Summary
            _buildBlendSummary(),
          ],
        ),
      ),
    );
  }
} 