import 'dart:async';
import 'dart:io';
import 'dart:ffi' as ffi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_size/window_size.dart' as window_package;

import 'theme.dart';
import 'services/go_bindings.dart';
import 'services/ffi_init.dart';
import 'components/common/media_header.dart';
import 'components/music/music_section.dart';
import 'components/music/search/search_section.dart';
import 'components/music/spotify_service.dart';
import 'models.dart'; // Import models to get the Track class
import 'components/common/media_grid.dart';
import 'components/music/tracks/track_card.dart'; // Add this import

/// Entry point for the Flutter app
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize platform channels
  const eventBusChannel = MethodChannel('com.interestnaut.eventbus');
  
  // Set up server event streams
  // try {
  //   final serverPort = await eventBusChannel.invokeMethod<int>('initializeEventBus');
  //   if (serverPort != null) {
  //     debugPrint('Connected to event bus on port $serverPort');
  //     debugPrint('Event bus initialized and all event subscriptions active');
  //   } else {
  //     debugPrint('Failed to initialize event bus: No port returned');
  //   }
  // } catch (e) {
  //   debugPrint('Error initializing event bus: $e');
  //   // Continue without event bus
  // }
  
  bool ffiAvailable = false;
  
  try {
    // Try to initialize FFI, but don't stop the app if it fails
    await FFIInitializer.initialize();
    debugPrint('FFI initialized successfully');
    
    // Try to initialize Go bindings
    try {
      final goInitFFIBridge =
      FFIInitializer.dylib.lookupFunction<ffi.Void Function(),
          void Function()>('InitializeFFIBridge');
      debugPrint('Dart: Calling Go InitializeFFIBridge()...');
      goInitFFIBridge();
      debugPrint('Dart: Go InitializeFFIBridge() called successfully.');
      
      // Initialize GoBindings (Dart wrapper for FFI calls)
      await GoBindings.initialize();
      debugPrint('Dart: GoBindings.initialize() complete. Status: ${GoBindings.ffiAvailable}');
      
      ffiAvailable = GoBindings.ffiAvailable;
      
      if (ffiAvailable) {
        // Register shutdown hooks only if FFI is available
        registerShutdownHooks();
        
        // Register the app lifecycle observer
        final binding = WidgetsBinding.instance;
        binding.addObserver(_AppLifecycleObserver());
      }
    } catch (e) {
      debugPrint('Error initializing Go FFI Bridge: $e');
      // Continue without FFI
    }
  } catch (e) {
    debugPrint('Error initializing FFI: $e');
    // Continue anyway, the app will handle missing FFI gracefully
  }
  
  // Set window size for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    try {
      window_package.setWindowTitle('Interestnaut');
      Size maxSize = const Size(1920, 1080);
      Size initialSize = const Size(1024, 800);
      window_package.setWindowMaxSize(maxSize);
      window_package.setWindowMinSize(const Size(400, 300));
      window_package.setWindowFrame(
          Rect.fromLTWH(0, 0, initialSize.width, initialSize.height));
    } catch (e) {
      debugPrint('Error setting window size: $e');
    }
  }
  
  // The app will now run even if FFI initialization fails
  // This allows the Dart-only SpotifyService to work independently
  runApp(const MyApp());
}

/// Register hooks to signal Go app to shut down
void registerShutdownHooks() {
  debugPrint('Registering shutdown hooks for Go interop');

  // Catch SIGTERM on macOS/Linux
  if (Platform.isLinux || Platform.isMacOS) {
    ProcessSignal.sigterm.watch().listen((_) {
      debugPrint('Received SIGTERM, shutting down Go runtime...');
      GoBindings.signalShutdown();
    });
  }

  // Catch ctrl+c in terminal for debugging
  ProcessSignal.sigint.watch().listen((_) {
    debugPrint('Received SIGINT, shutting down Go runtime...');
    GoBindings.signalShutdown();
  });
}

/// Observer for app lifecycle events
class _AppLifecycleObserver with WidgetsBindingObserver {
  /// Handle app lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      debugPrint('App is detached, shutting down Go runtime...');
      GoBindings.signalShutdown();
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Interestnaut',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      home: const InterestnautApp(),
    );
  }
}

class InterestnautApp extends StatefulWidget {
  const InterestnautApp({Key? key}) : super(key: key);

  @override
  State<InterestnautApp> createState() => _InterestnautAppState();
}

class _InterestnautAppState extends State<InterestnautApp> {
  String _currentMediaType = 'music'; // Default media type
  String _searchQuery = '';
  bool _isSearchActive = false;
  
  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
      _isSearchActive = query.isNotEmpty;
    });
    
    debugPrint('Searching for "$query" in $_currentMediaType');
  }
  
  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _isSearchActive = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // Main app UI
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // Main content area
          Positioned.fill(
            child: _buildCurrentContent(),
          ),
          
          // Header - Always show the header at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MediaHeader(
              currentMedia: _currentMediaType,
              onMediaChange: (media) {
                setState(() {
                  _currentMediaType = media;
                });
              },
              onSearch: _handleSearch,
              onClearSearch: _clearSearch,
            ),
          ),
          
          // Search overlay - only shown when search is active
          if (_isSearchActive && _currentMediaType == 'music')
            Positioned.fill(
              child: Stack(
                children: [
                  // Semi-transparent background overlay
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _clearSearch, // Clear search when tapping outside
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ),
                  
                  // Actual search results
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.only(
                        top: 60.0,
                        left: 8.0,
                        right: 8.0,
                        bottom: 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(18, 18, 18, 0.95),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: BoxConstraints(
                        minHeight: 300,
                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                      ),
                      child: _MusicSearchHandler(
                        searchQuery: _searchQuery,
                        onClearSearch: _clearSearch,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentContent() {
    switch (_currentMediaType) {
      case 'music':
        return const MusicSection();
      case 'movies':
        return const Center(child: Text('Movies Section', style: TextStyle(color: Colors.white)));
      case 'tv':
        return const Center(child: Text('TV Shows Section', style: TextStyle(color: Colors.white)));
      case 'games':
        return const Center(child: Text('Games Section', style: TextStyle(color: Colors.white)));
      case 'books':
        return const Center(child: Text('Books Section', style: TextStyle(color: Colors.white)));
      default:
        return const Center(child: Text('Home Section', style: TextStyle(color: Colors.white)));
    }
  }
}

// A separate widget to handle Spotify search state and display
class _MusicSearchHandler extends StatefulWidget {
  final String searchQuery;
  final VoidCallback onClearSearch;

  const _MusicSearchHandler({
    Key? key,
    required this.searchQuery,
    required this.onClearSearch,
  }) : super(key: key);

  @override
  State<_MusicSearchHandler> createState() => _MusicSearchHandlerState();
}

class _MusicSearchHandlerState extends State<_MusicSearchHandler> {
  final SpotifyService _spotifyService = SpotifyService();
  List<SimpleTrack> _searchResults = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _performSearch(widget.searchQuery);
  }

  @override
  void didUpdateWidget(_MusicSearchHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery) {
      _performSearch(widget.searchQuery);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _spotifyService.searchTracks(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching tracks: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to search tracks: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePlay(SimpleTrack track) async {
    try {
      await _spotifyService.playTrack(track.uri);
    } catch (e) {
      debugPrint('Error playing track: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play track: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleSave(SimpleTrack track) async {
    try {
      await _spotifyService.saveTrack(track.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${track.name}" to your library'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving track: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save track: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleRemove(SimpleTrack track) async {
    try {
      await _spotifyService.removeTrack(track.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${track.name}" from your library'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error removing track: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove track: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SearchSection(
      searchResults: _searchResults,
      isLoading: _isLoading,
      error: _error,
      onSearch: _performSearch,
      onPlay: _handlePlay,
      onSave: _handleSave,
      onRemove: _handleRemove,
      onRetry: () => _performSearch(widget.searchQuery),
      onClose: widget.onClearSearch,
    );
  }
}
