import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path/path.dart' as path_lib;
import 'package:path_provider/path_provider.dart';
import '../../theme.dart';
import '../../db/vector_db.dart';

/// Panel for managing media-specific vector databases
class DatabaseManagementPanel extends StatefulWidget {
  final String mediaType;

  const DatabaseManagementPanel({
    Key? key,
    required this.mediaType,
  }) : super(key: key);

  @override
  State<DatabaseManagementPanel> createState() => _DatabaseManagementPanelState();
}

class _DatabaseManagementPanelState extends State<DatabaseManagementPanel> {
  final VectorDatabase _vectorDb = VectorDatabase();
  bool _isDownloading = false;
  bool _isDeleting = false;
  bool _hasDatabase = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';

  @override
  void initState() {
    super.initState();
    _checkDatabaseStatus();
  }

  Future<void> _checkDatabaseStatus() async {
    try {
      // First sync the VectorDatabase with actual files on disk
      await _vectorDb.enableAllDownloadedMediaTypes();
      
      // Check if the actual database file exists on disk
      final appDir = await getApplicationSupportDirectory();
      final vectorDir = Directory(path_lib.join(appDir.path, 'vectors'));
      
      final shardFiles = {
        'music': 'vectors_music.db',
        'movies': 'vectors_movies.db', 
        'tv': 'vectors_tv.db',
        'books': 'vectors_books.db',
        'games': 'vectors_games.db',
      };
      
      final filename = shardFiles[widget.mediaType];
      bool fileExists = false;
      
      if (filename != null && await vectorDir.exists()) {
        final file = File(path_lib.join(vectorDir.path, filename));
        fileExists = await file.exists();
      }
      
      setState(() {
        _hasDatabase = fileExists;
      });
    } catch (e) {
      debugPrint('Error checking database status: $e');
      setState(() {
        _hasDatabase = false;
      });
    }
  }

  Future<void> _downloadDatabase() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Preparing download...';
    });

    try {
      // Simulate download progress
      for (int i = 0; i <= 100; i += 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) {
          setState(() {
            _downloadProgress = i / 100.0;
            _downloadStatus = 'Downloading ${widget.mediaType} database... ${i}%';
          });
        }
      }

      // Enable media type (downloads database if needed)
      final success = await _vectorDb.enableMediaType(widget.mediaType);
      if (!success) {
        throw Exception('Failed to enable media type');
      }
      
      setState(() {
        _isDownloading = false;
        _hasDatabase = true;
        _downloadStatus = 'Download completed successfully!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.mediaType} database downloaded successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _downloadStatus = 'Download failed: ${e.toString()}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download ${widget.mediaType} database: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _deleteDatabase() async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => _buildDeleteConfirmationDialog(),
    );

    if (shouldDelete != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      // Disable media type first
      await _vectorDb.disableMediaType(widget.mediaType);
      
      // Delete the actual database file
      final appDir = await getApplicationSupportDirectory();
      final vectorDir = Directory(path_lib.join(appDir.path, 'vectors'));
      final shardFiles = {
        'music': 'vectors_music.db',
        'movies': 'vectors_movies.db',
        'tv': 'vectors_tv.db',
        'books': 'vectors_books.db',
        'games': 'vectors_games.db',
      };
      
      final filename = shardFiles[widget.mediaType];
      if (filename != null) {
        final file = File(path_lib.join(vectorDir.path, filename));
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      setState(() {
        _isDeleting = false;
        _hasDatabase = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.mediaType} database deleted successfully'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDeleting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete ${widget.mediaType} database: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildDeleteConfirmationDialog() {
    return Dialog(
      backgroundColor: const Color(0xFF0A0A0A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
                              color: AppTheme.errorColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning,
                                  color: AppTheme.errorColor.withOpacity(0.8),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Delete Vector Database?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This will permanently delete the ${widget.mediaType} vector database from your device. You\'ll need to re-download it to get ${widget.mediaType} recommendations.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseStatus() {
    if (!_hasDatabase) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
                              color: AppTheme.warningColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
                                color: AppTheme.warningColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_download_outlined,
                                      color: AppTheme.warningColor.withOpacity(0.8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'DATABASE NOT INSTALLED',
                  style: TextStyle(
                    color: AppTheme.warningColor.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'The ${widget.mediaType} vector database is not installed. Download it to enable ${widget.mediaType} recommendations.',
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
                              color: AppTheme.successColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                                    color: AppTheme.successColor.withOpacity(0.8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'DATABASE INSTALLED',
                style: TextStyle(
                                      color: AppTheme.successColor.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'The ${widget.mediaType} vector database is installed and ready for recommendations.',
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

  Widget _buildDownloadButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isDownloading ? null : _downloadDatabase,
        icon: _isDownloading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.download, size: 20),
        label: Text(_isDownloading ? 'Downloading...' : 'Download Database'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor.withOpacity(0.8),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.withOpacity(0.3),
          disabledForegroundColor: Colors.white.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isDeleting ? null : _deleteDatabase,
        icon: _isDeleting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.errorColor,
                ),
              )
            : const Icon(Icons.delete_outline, size: 20),
        label: Text(_isDeleting ? 'Deleting...' : 'Delete Database'),
        style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.errorColor.withOpacity(0.6)),
                  foregroundColor: AppTheme.errorColor.withOpacity(0.8),
                  disabledForegroundColor: AppTheme.errorColor.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadProgress() {
    if (!_isDownloading) return const SizedBox.shrink();

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _downloadStatus,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _downloadProgress,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'DATABASE MANAGEMENT',
            style: TextStyle(
              color: AppTheme.primaryColor.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'manage local vector database for ${widget.mediaType} recommendations',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 24),

          // Database status
          _buildDatabaseStatus(),
          const SizedBox(height: 24),

          // Download progress (only shown when downloading)
          _buildDownloadProgress(),
          if (_isDownloading) const SizedBox(height: 24),

          // Action buttons
          if (!_hasDatabase) ...[
            _buildDownloadButton(),
          ] else ...[
            _buildDeleteButton(),
          ],
        ],
      ),
    );
  }
} 