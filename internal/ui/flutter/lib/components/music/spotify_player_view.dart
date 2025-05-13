import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models.dart';
import '../../services/spotify_service.dart';
import '../../services/event_bus.dart';

/// A widget that displays the currently playing track and provides playback controls
/// Based on the previous React implementation in NowPlayingBar.tsx
class SpotifyPlayer extends StatefulWidget {
  const SpotifyPlayer({Key? key}) : super(key: key);

  @override
  State<SpotifyPlayer> createState() => _SpotifyPlayerState();
}

/// The state class for the SeekBar component
class _SeekBarState extends State<_SeekBar> {
  double _dragValue = 0.0;
  bool _dragging = false;
  
  @override
  void initState() {
    super.initState();
    // Initialize with current progress when created
    _dragValue = widget.position.toDouble();
  }
  
  @override
  void didUpdateWidget(_SeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update drag value with current position if not dragging
    if (!_dragging && oldWidget.position != widget.position) {
      _dragValue = widget.position.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
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
            value: math.min(_dragValue, widget.duration.toDouble()),
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
                _formatDuration(_dragging ? _dragValue.toInt() : widget.position),
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
  MediaItem? _currentTrack;
  bool _isPlaying = false;
  Timer? _positionTimer;
  Timer? _pollingTimer;
  int _position = 0;
  final int _duration = 30000; // Default duration in milliseconds
  final SpotifyService _spotifyService = SpotifyService.instance;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _setupEventListeners();
    _startPolling();
  }
  
  @override
  void dispose() {
    _positionTimer?.cancel();
    _eventSubscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _setupEventListeners() {
    // Listen for track change events from SpotifyService
    _spotifyService.onTrackChange.listen((event) {
      if (mounted) {
        setState(() {
          _currentTrack = event;
          _isPlaying = true;
          _position = 0;
          _startProgressTimer();
        });
      }
    });

    // Listen for playback state change events from SpotifyService
    _spotifyService.onPlaybackStateChange.listen((isPlaying) {
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
          if (isPlaying) {
            _startProgressTimer();
          } else {
            _positionTimer?.cancel();
          }
        });
      }
    });
    
    // Listen for unified event bus events
    final eventBus = EventBus();
    _eventSubscription = eventBus.on<Map<String, dynamic>>().listen((event) {
      if (mounted) {
        // Handle Spotify playback state events from Go backend
        if (event['type'] == 'spotify_playback_state') {
          final bool isPlaying = event['is_playing'] ?? false;
          setState(() {
            _isPlaying = isPlaying;
            if (isPlaying) {
              _startProgressTimer();
            } else {
              _positionTimer?.cancel();
            }
          });
          
          // If we have track info, update the current track
          if (event['track'] != null) {
            final trackData = event['track'] as Map<String, dynamic>;
            setState(() {
              _currentTrack = MediaItem(
                id: trackData['id'] ?? '',
                title: trackData['name'] ?? 'Unknown Track',
                overview: trackData['artist'] ?? 'Unknown Artist',
                posterPath: trackData['albumArtUrl'] ?? '',
                uri: trackData['uri'] ?? '',
                previewUrl: trackData['previewUrl'] ?? '',
                mediaType: 'music',
              );
              _position = 0;
            });
          }
        }
      }
    });
  }
  
  // Periodically poll Spotify to keep playback state in sync
  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _syncPlaybackState();
    });
  }
  
  Future<void> _syncPlaybackState() async {
    if (!_spotifyService.isAuthenticated) return;
    
    try {
      // Use the Spotify API to get current playback state
      final playbackState = await _spotifyService.getPlaybackState();
      if (playbackState != null && mounted) {
        final bool isPlaying = playbackState['is_playing'] ?? false;
        
        setState(() {
          _isPlaying = isPlaying;
          if (isPlaying) {
            _position = playbackState['progress_ms'] ?? 0;
            _startProgressTimer();
          } else {
            _positionTimer?.cancel();
          }
          
          // Update track if present and different from current
          if (playbackState['item'] != null) {
            final track = playbackState['item'] as Map<String, dynamic>;
            final trackId = track['id'] as String?;
            
            if (trackId != null && (_currentTrack == null || trackId != _currentTrack!.id)) {
              _currentTrack = MediaItem(
                id: trackId,
                title: track['name'] ?? 'Unknown Track',
                overview: _getArtistNames(track['artists']),
                posterPath: _getAlbumArtUrl(track['album']) ?? '',
                uri: track['uri'] ?? '',
                previewUrl: track['preview_url'] ?? '',
                mediaType: 'music',
              );
            }
          }
        });
      }
    } catch (e) {
      // Silently handle errors - just means we'll try again next poll
      debugPrint('Error syncing playback state: $e');
    }
  }
  
  String _getArtistNames(List<dynamic>? artists) {
    if (artists == null || artists.isEmpty) return 'Unknown Artist';
    return artists.map((a) => a['name']).join(', ');
  }
  
  String? _getAlbumArtUrl(Map<String, dynamic>? album) {
    if (album == null || !album.containsKey('images') || album['images'] == null) {
      return null;
    }
    
    final images = album['images'] as List<dynamic>;
    if (images.isNotEmpty) {
      return images.first['url'] as String?;
    }
    return null;
  }

  void _playTrack(MediaItem track) {
    if (track.uri != null) {
      _spotifyService.playTrack(track.uri!);
    }
  }
  
  void _togglePlayPause() {
    if (_currentTrack == null) return;
    
    if (_isPlaying) {
      _spotifyService.pausePlayback();
      _positionTimer?.cancel();
    } else {
      if (_currentTrack!.uri != null) {
        _playTrack(_currentTrack!);
      }
    }
  }
  
  void _startProgressTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (mounted && _isPlaying) {
        setState(() {
          _position += 1000;
          // Loop back if we reach the end (for preview playback)
          if (_position >= _duration) {
            _position = 0;
          }
        });
      }
    });
  }
  
  void _seekTo(int position) {
    setState(() {
      _position = position;
    });
    // TODO: Implement seeking via Spotify API when available
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
                  if (_currentTrack!.posterPath.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        _currentTrack!.posterPath,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentTrack!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _currentTrack!.overview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withAlpha(180),
                            ),
                          ),
                        ],
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
