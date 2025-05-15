import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../models.dart';
import '../spotify_service.dart';

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
      duration: const Duration(milliseconds: 200), // More immediate animation (reduced from 1000ms)
    );
    
    _updateProgressAnimation();
  }
  
  void _updateProgressAnimation() {
    _progressAnimation = Tween<double>(
      begin: _dragValue,
      end: widget.position.toDouble(),
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOut, // More immediate feel with easeOut instead of linear
    ));
    
    _progressController.forward(from: 0.0);
    
    _progressController.addListener(() {
      if (!_dragging && mounted) {
        setState(() {
          // Use the animated value for smoother updates
          _dragValue = _progressAnimation.value;
        });
      }
    });
  }
  
  @override
  void didUpdateWidget(_SeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // When position changes from outside (e.g. timer updates)
    if (oldWidget.position != widget.position && !_dragging) {
      _updateProgressAnimation();
    }
  }
  
  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: const SliderThemeData(
        trackHeight: 4.0,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14.0),
        activeTrackColor: Color(0xFFA855F7),
        inactiveTrackColor: Color(0x33FFFFFF),
        thumbColor: Color(0xFFA855F7),
        overlayColor: Color(0x1FA855F7),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8.0, right: 4.0),
            child: Text(
              widget.formatTime(widget.position),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              min: 0.0,
              max: widget.duration.toDouble(),
              value: math.min(_dragValue, widget.duration.toDouble()),
              onChanged: (value) {
                setState(() {
                  _dragging = true;
                  _dragValue = value;
                });
              },
              onChangeEnd: (value) {
                setState(() {
                  _dragging = false;
                });
                widget.onSeeked(value.round());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4.0, right: 8.0),
            child: Text(
              widget.formatTime(widget.duration),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  final int position;
  final int duration;
  final Function(int) onSeeked;
  final Function(int) formatTime;
  
  const _SeekBar({
    required this.position,
    required this.duration,
    required this.onSeeked,
    required this.formatTime,
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
  int _duration = 0;
  final SpotifyService _spotifyService = SpotifyService();
  late StreamSubscription<Track> _trackSubscription;
  late StreamSubscription<SpotifyPlaybackState> _playbackStateSubscription;

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
    // Start polling for playback state to get track duration
    _startPlaybackPolling();
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
          
          // Initiate polling for full track data when track changes
          _getFullTrackDuration();
          
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
  
  // Poll Spotify API for playback state to get full track data
  void _startPlaybackPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _getFullTrackDuration();
    });
  }
  
  // Get full track duration from Spotify API
  void _getFullTrackDuration() async {
    if (_currentTrack == null) return;
    
    final playbackState = await _spotifyService.getPlaybackState();
    if (playbackState != null && mounted) {
      // Get duration from current track
      if (playbackState.containsKey('item') && 
          playbackState['item'] != null && 
          playbackState['item'].containsKey('duration_ms')) {
        
        setState(() {
          _duration = playbackState['item']['duration_ms'] as int;
          
          // Also update position for accuracy
          if (playbackState.containsKey('progress_ms')) {
            _position = playbackState['progress_ms'] as int;
          }
        });
      }
    }
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
  
  // Format time for duration display
  String formatTime(int ms) {
    final seconds = (ms / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // If no track is playing, don't show the player
    if (_currentTrack == null) {
      return const SizedBox.shrink();
    }
    
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(28, 28, 28, 0.85),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                SizedBox(
                  width: 180,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentTrack!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: theme.textTheme.titleSmall?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_currentTrack!.artist} - ${_currentTrack!.album.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Scrubber bar (now in the same row as other elements)
                Expanded(
                  child: _SeekBar(
                    position: _position,
                    duration: _duration > 0 ? _duration : 30000, // Use actual duration if available
                    onSeeked: _seekTo,
                    formatTime: formatTime,
                  ),
                ),
                
                // Play/pause button
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                  child: IconButton(
                    onPressed: _togglePlayPause,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 24,
                      color: colorScheme.primary,
                    ),
                    hoverColor: Colors.white.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Create a custom event bus for Spotify events
class SpotifyEvents {
  static final StreamController<String> _deviceReadyController = StreamController<String>.broadcast();
  static final StreamController<Track> _trackChangeController = StreamController<Track>.broadcast();
  static final StreamController<SpotifyPlaybackState> _playbackStateChangeController = StreamController<SpotifyPlaybackState>.broadcast();
  static final StreamController<String> _errorController = StreamController<String>.broadcast();

  // Stream getters
  static Stream<String> get onDeviceReady => _deviceReadyController.stream;
  static Stream<Track> get onTrackChange => _trackChangeController.stream;
  static Stream<SpotifyPlaybackState> get onPlaybackStateChange => _playbackStateChangeController.stream;
  static Stream<String> get onError => _errorController.stream;

  // Event emitters
  static void emitDeviceReady(String deviceId) => _deviceReadyController.add(deviceId);
  static void emitTrackChange(Track track) => _trackChangeController.add(track);
  static void emitPlaybackStateChange(SpotifyPlaybackState state) => _playbackStateChangeController.add(state);
  static void emitError(String errorMessage) => _errorController.add(errorMessage);
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
