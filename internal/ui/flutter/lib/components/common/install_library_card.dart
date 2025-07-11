import 'package:flutter/material.dart';
import '../../db/vector_db.dart';
import '../../theme.dart';

/// InstallLibraryCard
/// Shows when a media type's vector database is not installed
/// Provides download functionality with progress indication
class InstallLibraryCard extends StatefulWidget {
  final String mediaType;
  final VoidCallback? onInstalled;

  const InstallLibraryCard({
    Key? key,
    required this.mediaType,
    this.onInstalled,
  }) : super(key: key);

  @override
  State<InstallLibraryCard> createState() => _InstallLibraryCardState();
}

class _InstallLibraryCardState extends State<InstallLibraryCard> {
  final VectorDatabase _vectorDb = VectorDatabase();
  bool _isDownloading = false;
  String? _error;

  String _getMediaTypeDisplayName(String mediaType) {
    switch (mediaType) {
      case 'video_game':
        return 'Video Games';
      case 'tv_show':
        return 'TV Shows';
      default:
        return mediaType[0].toUpperCase() + mediaType.substring(1);
    }
  }

  IconData _getMediaTypeIcon(String mediaType) {
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

  String _getEstimatedSize(String mediaType) {
    switch (mediaType) {
      case 'music':
        return '928 MB';
      case 'movie':
        return '440 MB';
      case 'tv_show':
        return '238 MB';
      case 'book':
        return '191 MB';
      case 'video_game':
        return '84 MB';
      default:
        return '~200 MB';
    }
  }

  Future<void> _installLibrary() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _error = null;
    });

    try {
      final success = await _vectorDb.enableMediaType(widget.mediaType);
      
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_getMediaTypeDisplayName(widget.mediaType)} library installed successfully!'),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
          widget.onInstalled?.call();
        }
      } else {
        setState(() {
          _error = 'Failed to install library';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF333333),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact title and description
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
              children: [
                TextSpan(text: 'Install ${_getMediaTypeDisplayName(widget.mediaType)} Library'),
                TextSpan(
                  text: '\n${_getEstimatedSize(widget.mediaType)} download',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFC23B85),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Spotify-style install button
          SizedBox(
            width: 100,
            height: 32,
            child: OutlinedButton(
              onPressed: _isDownloading ? null : _installLibrary,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7B68EE),
                side: const BorderSide(color: Color(0xFF7B68EE)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: EdgeInsets.zero,
              ),
              child: _isDownloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7B68EE)),
                    ),
                  )
                : const Text(
                    'Install',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
} 