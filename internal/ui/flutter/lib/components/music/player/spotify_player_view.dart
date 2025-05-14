import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models.dart';
import '../spotify_service.dart';
import '../../../services/event_bus.dart';

/// A widget that displays the currently playing track and provides playback controls
/// Based on the previous React implementation in NowPlayingBar.tsx
class SpotifyPlayer extends StatefulWidget {
  const SpotifyPlayer({Key? key}) : super(key: key);

  @override
  State<SpotifyPlayer> createState() => _SpotifyPlayerState();
}

/// The state class for the SeekBar component
class _SeekBarState extends State<_SeekBar> with TickerProviderStateMixin {
  double _dragValue = 0.0;
  bool _dragging = false;
  
  // Add a controller for smoother animations
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  
  @override
  void initState() {
    super.initState();
    // Initialize with current progress when created
    _dragValue = widget.position.toDouble();
    
    // Set up animation controller for smooth progress updates
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200), // Short animation for smoother updates
    );
    
    _progressAnimation = Tween<double>(
      begin: _dragValue,
      end: _dragValue,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
    
    _progressController.addListener(() {
      if (!_dragging) {
        setState(() {
          // Animation is handled by the controller
        });
      }
    });
  }
  
  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(_SeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update drag value with current position if not dragging
    if (!_dragging && oldWidget.position != widget.position) {
      // Update animation for smooth transitions
      _progressAnimation = Tween<double>(
        begin: _progressAnimation.value,
        end: widget.position.toDouble(),
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeInOut,
      ));
      
      _progressController.forward(from: 0.0);
      _dragValue = widget.position.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Use the animated value for display if not dragging
    final displayValue = _dragging ? _dragValue : _progressAnimation.value;
    
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.primary.withAlpha(40),
            thumbColor: colorScheme.primary,
            overlayColor: colorScheme.primary.withAlpha(30),
          ),
          child: Slider(
            min: 0.0,
            max: widget.duration.toDouble(),
            value: math.min(displayValue, widget.duration.toDouble()),
            onChanged: (value) {
              setState(() {
                _dragging = true;
                _dragValue = value;
              });
            },
            onChangeEnd: (value) {
              widget.onSeeked(value.toInt());
              setState(() {
                _dragging = false;
                // Update animation after seeking
                _progressAnimation = Tween<double>(
                  begin: value,
                  end: value,
                ).animate(CurvedAnimation(
                  parent: _progressController, 
                  curve: Curves.easeInOut
                ));
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_dragging ? _dragValue.toInt() : displayValue.toInt()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                _formatDuration(widget.duration),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Format a duration in milliseconds to MM:SS format
  String _formatDuration(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

/// A custom seek bar widget for the Spotify player
class _SeekBar extends StatefulWidget {
  final int position;
  final int duration;
  final Function(int) onSeeked;
  
  const _SeekBar({
    required this.position,
    required this.duration,
    required this.onSeeked,
  });
  
  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SpotifyPlayerState extends State<SpotifyPlayer> {
  Track? _currentTrack;
  bool _isPlaying = false;
  Timer? _positionTimer;
  Timer? _pollingTimer;
  int _position = 0;
  int _duration = 0; // Use the actual track duration instead of a fixed limit
  final SpotifyService _spotifyService = SpotifyService();
  late StreamSubscription<Track> _trackSubscription;
  late StreamSubscription<SpotifyPlaybackState> _playbackStateSubscription;

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
    // No need to poll anymore as we're using event-based updates
  }
  
  @override
  void dispose() {
    _positionTimer?.cancel();
    _trackSubscription.cancel();
    _playbackStateSubscription.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _setupEventListeners() {
    // Listen for track change events
    _trackSubscription = SpotifyEvents.onTrackChange.listen((track) {
      if (mounted) {
        setState(() {
          _currentTrack = track;
          _isPlaying = true;
          _position = 0;
          // Calculate duration based on preview URL if available
          _duration = 30000; // Default to 30s if no duration info
          _startProgressTimer();
        });
      }
    });

    // Listen for playback state change events
    _playbackStateSubscription = SpotifyEvents.onPlaybackStateChange.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.isPlaying;
          if (state.progressMs != null) {
            _position = state.progressMs!;
          }
          
          if (state.item != null) {
            _currentTrack = state.item;
          }
          
          if (_isPlaying) {
            _startProgressTimer();
          } else {
            _positionTimer?.cancel();
          }
        });
      }
    });
  }
  
  void _playTrack(Track track) {
    if (track.uri.isNotEmpty) {
      _spotifyService.playTrack(track.uri);
    }
  }
  
  void _togglePlayPause() {
    if (_isPlaying) {
      _spotifyService.pausePlayback();
      _positionTimer?.cancel();
    } else {
      if (_currentTrack != null && _currentTrack!.uri.isNotEmpty) {
        _playTrack(_currentTrack!);
      }
    }
  }
  
  void _startProgressTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (mounted && _isPlaying) {
        setState(() {
          if (_position < _duration) {
            _position += 1000;
          } else {
            // Track finished, reset position
            _position = 0;
            timer.cancel();
          }
        });
      }
    });
  }
  
  void _seekTo(int position) {
    setState(() {
      _position = position;
    });
    
    // Call Spotify API to seek if authenticated
    if (_currentTrack != null) {
      // Use device ID if available
      _spotifyService.seekTo(position);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // If no track is playing, don't show the player
    if (_currentTrack == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Progress bar
          _SeekBar(
            position: _position,
            duration: _duration,
            onSeeked: _seekTo,
          ),
          
          // Player controls and track info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Album art
                  if (_currentTrack!.albumArtUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        _currentTrack!.albumArtUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 48,
                            height: 48,
                            color: colorScheme.primary.withAlpha(50),
                            child: const Icon(Icons.music_note),
                          );
                        },
                      ),
                    )
                  else
                    Container(
                      width: 48,
                      height: 48,
                      color: colorScheme.primary.withAlpha(50),
                      child: const Icon(Icons.music_note),
                    ),
                  
                  // Track info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      // Use a fixed-height container to prevent overflow
                      child: SizedBox(
                        height: 33, // Reduce by 1px to prevent overflow
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentTrack!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall,
                              ),
                              // Very small SizedBox instead of dynamic spacing
                              const SizedBox(height: 1),
                              // Make the overview text even smaller
                              Text(
                                _currentTrack!.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10, // Smaller font for artist text
                                  height: 1.0, // Tighter line height
                                  color: theme.textTheme.bodySmall?.color?.withAlpha(180),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Play/pause button
                  IconButton(
                    onPressed: _togglePlayPause,
                    icon: Icon(
                      _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      size: 36,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Create a custom event bus for Spotify events
class SpotifyEvents {
  static final StreamController<String> _deviceReadyController = StreamController<String>.broadcast();
  static final StreamController<Track> _trackChangeController = StreamController<Track>.broadcast();
  static final StreamController<SpotifyPlaybackState> _playbackStateChangeController = StreamController<SpotifyPlaybackState>.broadcast();

  // Stream getters
  static Stream<String> get onDeviceReady => _deviceReadyController.stream;
  static Stream<Track> get onTrackChange => _trackChangeController.stream;
  static Stream<SpotifyPlaybackState> get onPlaybackStateChange => _playbackStateChangeController.stream;

  // Event emitters
  static void emitDeviceReady(String deviceId) => _deviceReadyController.add(deviceId);
  static void emitTrackChange(Track track) => _trackChangeController.add(track);
  static void emitPlaybackStateChange(SpotifyPlaybackState state) => _playbackStateChangeController.add(state);
}

// Simple playback state model
class SpotifyPlaybackState {
  final bool isPlaying;
  final int? progressMs;
  final Track? item;

  SpotifyPlaybackState({
    required this.isPlaying,
    this.progressMs,
    this.item,
  });
}
