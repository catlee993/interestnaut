import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'continuous_playback_switch.dart';
import '../../services/mistral_isolate.dart';

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
  bool _hasModel = false;
  bool _isDownloading = false;
  String? _downloadError;

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
  }

  Future<void> _checkModelStatus() async {
    final hasModel = await MinstralIsolateService.hasModel();
    if (mounted) {
      setState(() {
        _hasModel = hasModel;
      });
    }
  }

  Future<String> _getModelPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/mistral/mistral-7b-instruct-v0.2.Q4_K_M.gguf';
    return path;
  }

  Future<void> _downloadModel() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadError = null;
    });

    try {
      final modelPath = await _getModelPath();

      // Ensure directory exists
      final dir = Directory(modelPath.substring(0, modelPath.lastIndexOf('/')));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Show a toast that download has started
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloading Mistral AI model (4.6GB). This may take a while...'),
          duration: Duration(seconds: 5),
        ),
      );

      // Start the download in an isolate
      final response = await MinstralIsolateService.downloadModelInIsolate(modelPath);

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _hasModel = response.success;
          _downloadError = response.error;
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
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadError = e.toString();
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

  @override
  Widget build(BuildContext context) {
    // Custom drawer implementation that avoids the rendering issues
    return Stack(
      children: [
        // Semi-transparent overlay
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
        ),
        
        // Drawer panel
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: 400,
          child: Material(
            color: const Color.fromRGBO(18, 18, 18, 0.95),
            elevation: 16,
            child: SafeArea(
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
                              onPressed: (_hasModel || _isDownloading) ? null : _downloadModel,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7B68EE),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade700,
                                disabledForegroundColor: Colors.grey.shade400,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: _isDownloading
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
                          if (_downloadError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Error: $_downloadError',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
