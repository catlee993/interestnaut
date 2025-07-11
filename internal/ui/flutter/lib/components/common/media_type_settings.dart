import 'package:flutter/material.dart';
import '../../db/vector_db.dart';
import '../../theme.dart';
import '../../enums/media_type.dart';

/// MediaTypeSettings
/// Allows users to enable/disable different media types
/// Downloads vector databases as needed
class MediaTypeSettings extends StatefulWidget {
  const MediaTypeSettings({Key? key}) : super(key: key);

  @override
  State<MediaTypeSettings> createState() => _MediaTypeSettingsState();
}

class _MediaTypeSettingsState extends State<MediaTypeSettings> {
  final VectorDatabase _vectorDb = VectorDatabase();
  Map<String, bool> _enabledTypes = {};
  Map<String, int> _databaseSizes = {};
  Map<String, bool> _downloading = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final availableTypes = _vectorDb.availableMediaTypes;
      final enabledTypes = _vectorDb.enabledMediaTypes;
      final sizes = await _vectorDb.getDatabaseSizes();

      setState(() {
        _enabledTypes = {
          for (String type in availableTypes)
            type: enabledTypes.contains(type)
        };
        _databaseSizes = sizes;
        _downloading = {
          for (String type in availableTypes)
            type: false
        };
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading media type settings: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _toggleMediaType(String mediaType, bool enabled) async {
    if (_downloading[mediaType] == true) return;

    setState(() {
      _downloading[mediaType] = true;
    });

    try {
      if (enabled) {
        final success = await _vectorDb.enableMediaType(mediaType);
        if (success) {
          setState(() {
            _enabledTypes[mediaType] = true;
          });
          // Refresh database sizes
          final sizes = await _vectorDb.getDatabaseSizes();
          setState(() {
            _databaseSizes = sizes;
          });
        } else {
          _showError('Failed to enable $mediaType');
        }
      } else {
        await _vectorDb.disableMediaType(mediaType);
        setState(() {
          _enabledTypes[mediaType] = false;
        });
      }
    } catch (e) {
      debugPrint('Error toggling media type $mediaType: $e');
      _showError('Error: $e');
    } finally {
      setState(() {
        _downloading[mediaType] = false;
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  String _getMediaTypeDisplayName(String mediaType) {
    try {
      final mediaTypeEnum = MediaType.fromDatabaseName(mediaType);
      return mediaTypeEnum.pluralDisplayName;
    } catch (e) {
      // Fallback to original logic for unknown types
      switch (mediaType) {
        case 'video_game':
          return 'Video Games';
        case 'tv_show':
          return 'TV Shows';
        default:
          return mediaType[0].toUpperCase() + mediaType.substring(1);
      }
    }
  }

  IconData _getMediaTypeIcon(String mediaType) {
    try {
      final mediaTypeEnum = MediaType.fromDatabaseName(mediaType);
      return mediaTypeEnum.icon;
    } catch (e) {
      // Fallback to original logic for unknown types
      switch (mediaType) {
        case 'music':
          return Icons.music_note;
        case 'movie':
          return Icons.movie;
        case 'tv_show':
          return Icons.tv;
        case 'book':
          return Icons.book;
        case 'video_game':
          return Icons.videogame_asset;
        default:
          return Icons.category;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Media Types',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Enable media types to download their recommendation databases. Each database contains vector embeddings for similarity search.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: _enabledTypes.keys.map((mediaType) {
              final isEnabled = _enabledTypes[mediaType] ?? false;
              final isDownloading = _downloading[mediaType] ?? false;
              final size = _databaseSizes[mediaType];
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                color: const Color.fromRGBO(30, 30, 30, 1),
                child: ListTile(
                  leading: Icon(
                    _getMediaTypeIcon(mediaType),
                    color: isEnabled ? Colors.blue : Colors.grey,
                    size: 28,
                  ),
                  title: Text(
                    _getMediaTypeDisplayName(mediaType),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (size != null)
                        Text(
                          'Database size: ${_formatSize(size)}',
                          style: const TextStyle(color: Colors.white60),
                        ),
                      if (isDownloading)
                        const Text(
                          'Downloading...',
                          style: TextStyle(color: AppTheme.warningColor),
                        ),
                    ],
                  ),
                  trailing: isDownloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Switch(
                          value: isEnabled,
                          onChanged: (value) => _toggleMediaType(mediaType, value),
                          activeColor: Colors.blue,
                        ),
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Total size: ${_formatSize(_databaseSizes.values.fold(0, (sum, size) => sum + size))}',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
} 