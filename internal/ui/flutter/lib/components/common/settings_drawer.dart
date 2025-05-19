import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'continuous_playback_switch.dart';
import '../../services/mistral_service.dart';
import '../../services/llama_service.dart';
import '../../services/model_constants.dart';
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
  bool _isRunningLLM = false;

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
      // Try to check if model exists via FFI
      final hasModel = await MistralService.hasModel();
      if (mounted) {
        setState(() {
          _hasModel = hasModel;
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
    final directory = await getApplicationDocumentsDirectory();
    // Use the same filename as defined in the MistralService
    final path = '${directory.path}/${kModelsDirectoryName}/${kMistralModelFileName}';
    return path;
  }

  Future<void> _downloadModel() async {
    if (_isDownloadingModel) return;

    setState(() {
      _isDownloadingModel = true;
    });

    try {
      final modelPath = await _getModelPath();

      // Show a toast that download has started
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloading Mistral AI model (4.6GB). This may take a while...'),
          duration: Duration(seconds: 5),
        ),
      );

      try {
        // Start the download using the pure Dart implementation
        final response = await MistralService.downloadModel(modelPath);

        if (mounted) {
          setState(() {
            _isDownloadingModel = false;
            _hasModel = response.success;
          });

          // Show success or error toast
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.success
                  ? 'Mistral AI model downloaded successfully!'
                  : 'Failed to download Mistral AI model: ${response.error}'),
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
              content: Text('FFI binding error: $e'),
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
            content: Text('Error downloading Mistral AI model: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Test the LLM functionality
  Future<void> _testLLM() async {
    if (_isRunningLLM) return;

    setState(() {
      _isRunningLLM = true;
    });

    try {
      final modelPath = await LlamaService.getModelPath();

      // Initialize LLM with toast callback
      final llamaService = LlamaService();
      final success = await llamaService.initialize(modelPath,
          toastCallback: (message, {bool isError = false}) {
        _showToast(message, isError: isError);
      });

      if (success) {
        // Send a simple prompt to test with minimal tokens needed
        final response = await llamaService.processPrompt(
          "Generate one song: title, artist, album in json; single json object only. \n {\"title\": \"Song Title\", \"artist\": \"Artist Name\", \"album\": \"Album Name\"}",
        );
        print("Generated response: $response");
        // Note: The service will handle showing toast messages for the results
        // through the callback we provided
      } else {
        _showToast("Failed to initialize LLM", isError: true);
      }
    } catch (e) {
      _showToast("Error running LLM: $e", isError: true);
    } finally {
      setState(() {
        _isRunningLLM = false;
      });
    }
  }

  /// Show a toast message to the user
  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
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
                      'Mistral AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _hasModel
                          ? 'Mistral AI model is installed'
                          : 'Download the Mistral AI model (4.6GB) to enable offline AI suggestions',
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
                            : Text(_hasModel ? 'Installed' : 'Install Mistral AI'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: !_hasModel || _isRunningLLM ? null : _testLLM,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B68EE),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade700,
                          disabledForegroundColor: Colors.grey.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isRunningLLM
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
                                  Text('Running...'),
                                ],
                              )
                            : Text('Test LLM Integration'),
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
