import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'continuous_playback_switch.dart';
import '../../services/llm_downloader_service.dart';
import '../../services/model_constants.dart';
import '../../db/vector_db.dart';
import '../../theme.dart';

/// A widget that displays the settings drawer overlay.
/// This should be placed at a top level in the widget tree, not inside a constrained container.
class SettingsDrawer extends StatefulWidget {
  final VoidCallback onClose;

  const SettingsDrawer({
    Key? key,
    required this.onClose,
  }) : super(key: key);

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  bool _continuousPlayback = false;
  bool _isDownloadingModel = false;
  bool _hasModel = false;
  bool _isDownloadingDatabases = false;
  String _downloadStatus = '';
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    // Wrap in try-catch to handle FFI errors gracefully
    try {
      _checkModelStatus();
    } catch (e) {
      print('Error in SettingsDrawer initState: $e');
      // Set default value if we can't check
      setState(() {
        _hasModel = false;
      });
    }
  }

  Future<void> _checkModelStatus() async {
    try {
      // Check if any models exist in the models directory
      final hasModels = await LLMDownloaderService.hasModels();
      if (mounted) {
        setState(() {
          _hasModel = hasModels;
        });
      }
    } catch (e) {
      print('Error in _checkModelStatus: $e');
      if (mounted) {
        setState(() {
          _hasModel = false;
        });
      }
    }
  }

  Future<String> _getModelPath() async {
    // Use the proper method from LLMDownloaderService
    final modelDir = await LLMDownloaderService.getModelDirectory();
    return path.join(modelDir, kLlamaModelFileName);
  }

  Future<void> _downloadModel() async {
    if (_isDownloadingModel) return;

    setState(() {
      _isDownloadingModel = true;
    });

    try {
      // Get the model directory
      final modelDir = await LLMDownloaderService.getModelDirectory();

      // Show a toast that download has started
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloading TinyLlama model (608MB). This may take a while...'),
          duration: Duration(seconds: 5),
        ),
      );

      try {
        // Start the download using TinyLlama
        final response = await LLMDownloaderService.downloadModel(
          modelDir,
          kTinyLlamaModelFileName, // Use TinyLlama instead
          downloadUrl: 'https://interestnaut.com/models/tinyllama-1.1b-chat-q4_0.gguf',
        );

        if (mounted) {
          setState(() {
            _isDownloadingModel = false;
            _hasModel = response.success;
          });

          // Show success or error toast
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.success
                  ? 'TinyLlama model downloaded successfully!'
                  : 'Failed to download model: ${response.error}'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } catch (e) {
        // Handle FFI errors specifically
        if (mounted) {
          setState(() {
            _isDownloadingModel = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download error: $e'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloadingModel = false;
        });

        // Show error toast
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading model: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Download all vector databases
  Future<void> _downloadAllDatabases() async {
    if (_isDownloadingDatabases) return;

    setState(() {
      _isDownloadingDatabases = true;
      _downloadStatus = 'Starting download...';
      _downloadProgress = 0.0;
    });

    try {
      final vectorDb = VectorDatabase();
      
      // Show initial toast
      _showToast('Downloading all vector databases. This may take a while...');

      final success = await vectorDb.downloadAllDatabases(
        onProgress: (mediaType, progress) {
          if (mounted) {
            setState(() {
              _downloadStatus = 'Downloading $mediaType...';
              _downloadProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloadingDatabases = false;
          _downloadStatus = '';
          _downloadProgress = 0.0;
        });

        if (success) {
          // Enable all downloaded databases
          await vectorDb.enableAllDownloadedMediaTypes();
          _showToast('All vector databases downloaded successfully!');
        } else {
          _showToast('Some databases failed to download. Check logs for details.', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloadingDatabases = false;
          _downloadStatus = '';
          _downloadProgress = 0.0;
        });
        _showToast('Error downloading databases: $e', isError: true);
      }
    }
  }

  /// Show a toast message to the user
  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // The settings drawer panel
    return Material(
      color: const Color(0xFF121212),
      child: SizedBox(
        width: 350,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 16.0),
                    child: Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Content area
              Expanded(
                child: ListView(
                  children: [
                    ContinuousPlaybackSwitch(
                      value: _continuousPlayback,
                      onChanged: (v) => setState(() => _continuousPlayback = v),
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 24),
                    const Text(
                      'TinyLlama AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _hasModel
                          ? 'TinyLlama model is installed'
                          : 'Download TinyLlama (608MB) to enable offline AI explanations',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isDownloadingModel ? null : _downloadModel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B68EE),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade700,
                          disabledForegroundColor: Colors.grey.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isDownloadingModel
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Downloading...'),
                                ],
                              )
                            : Text(_hasModel ? 'Installed' : 'Install Model'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 24),
                    
                    // Vector Databases Section
                    const Text(
                      'Vector Databases',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Download all media databases (Books, Music, Movies, TV Shows, Games) for offline recommendations',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Download progress
                    if (_isDownloadingDatabases) ...[
                      Text(
                        _downloadStatus,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7B68EE)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isDownloadingDatabases ? null : _downloadAllDatabases,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B68EE),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade700,
                          disabledForegroundColor: Colors.grey.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isDownloadingDatabases
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Downloading...'),
                                ],
                              )
                            : const Text('Download All Databases'),
                      ),
                    ),

                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a settings drawer as an overlay above the entire application.
/// This function handles creating and showing the drawer properly.
void showSettingsDrawer(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      pageBuilder: (context, _, __) {
        return Align(
          alignment: Alignment.centerRight,
          child: SettingsDrawer(
            onClose: () {
              Navigator.of(context).pop();
            },
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
    ),
  );
}
