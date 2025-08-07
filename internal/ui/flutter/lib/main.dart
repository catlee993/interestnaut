import 'dart:async';
import 'dart:io';
import 'dart:ffi' as ffi;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'fonts.dart';
import 'package:provider/provider.dart';
import 'package:window_size/window_size.dart' as window_package;
import 'package:path_provider/path_provider.dart';
import 'package:ffi/ffi.dart';
// Removed llama_cpp_dart - using TensorFlow Lite instead
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';

// Import our components and services
import 'components/music/music_section.dart';
import 'components/music/search/search_section.dart';
import 'components/games/game_section.dart';
import 'components/movies/movie_section.dart';
import 'components/books/book_section.dart';
import 'components/tv/tv_show_section.dart';
import 'components/common/media_header.dart';
import 'components/common/media_grid.dart';
import 'components/common/media_detail_drawer.dart';
import 'components/common/spotify_branding.dart';
import 'components/music/spotify_service.dart';
import 'components/music/player/spotify_player_view.dart';
import 'components/music/player/spotify_web_player.dart';
import 'components/music/spotify_preview_dialog.dart';
// TFLite LLM service removed - using gRPC backend
import 'services/wikidata_service.dart';
import 'services/recommendation_service.dart';
import 'services/grpc_client.dart';
import 'services/sqlite_db.dart';
import 'services/continuous_playback_service.dart';
import 'services/ffi_init.dart';
import 'services/go_bindings.dart';
import 'models.dart';
import 'models/track_models.dart';
import 'theme.dart';
// Removed VectorDatabase - now using gRPC backend only



/// Entry point for the Flutter app
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize WebView for all platforms
  try {
    debugPrint('Initializing WebView');
    // Any WebView specific initialization can go here
  } catch (e) {
    debugPrint('Error initializing WebView: $e');
  }

  bool goFfiAvailable = false;

  try {
    // Try to initialize FFI, but don't stop the app if it fails
    await FFIInitializer.initialize();
    debugPrint('FFI initialized successfully');

    // Get application support directory for storage
    final appDir = await getApplicationSupportDirectory();
    final storagePath = appDir.path;
    debugPrint('Using Flutter storage path: $storagePath');

    // Try to initialize Go bindings for music auth (but not for LlamaService)
    try {
      final goInitFFIBridge =
      FFIInitializer.dylib.lookupFunction<ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>),
          ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)>('InitializeFFIBridge');
      debugPrint('Dart: Calling Go InitializeFFIBridge()...');

      // Convert Dart string to C string
      final storagePathC = storagePath.toNativeUtf8().cast<ffi.Char>();

      // Call the function with the storage path
      final resultPtr = goInitFFIBridge(storagePathC);

      // Free the C string after use
      calloc.free(storagePathC);

      // Parse the result (optional)
      final result = resultPtr.cast<Utf8>().toDartString();
      debugPrint('Dart: Go InitializeFFIBridge() called successfully. Result: $result');

      // Initialize GoBindings (Dart wrapper for FFI calls)
      await GoBindings.initialize();
      debugPrint('Dart: GoBindings.initialize() complete. Status: ${GoBindings.ffiAvailable}');

      goFfiAvailable = GoBindings.ffiAvailable;

      if (goFfiAvailable) {
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

  // --- TensorFlow Lite LLM Service removed ---
  // Using gRPC backend instead of local LLM models

  // --- Initialize RecommendationService ---
  // Create the gRPC-based recommendation service
  final recommendationService = RecommendationService();
  
  // --- Initialize ContinuousPlaybackService ---
  final continuousPlaybackService = ContinuousPlaybackService();

  // Set window size for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    try {
      window_package.setWindowTitle('Interestnaut');
      Size maxSize = const Size(1920, 1080);
      Size initialSize = const Size(1060, 800);
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
  runApp(
    MultiProvider(
      providers: [
        // Provide GrpcRecommendationService
        // TensorFlow Lite LLM Service removed - using gRPC backend
        ChangeNotifierProvider.value(value: recommendationService),
        // If SpotifyService needs to be a provider:
        Provider.value(value: SpotifyService()),
        // Provide ContinuousPlaybackService
        Provider.value(value: continuousPlaybackService),
      ],
      child: const MyApp(),
    ),
  );

  // --- Post-runApp async initialization for GrpcRecommendationService ---
  // Initialize the gRPC recommendation service with backend connection
  try {
    await recommendationService.init();

    // Prefill recommendation queues for gRPC backend
    await recommendationService.prefillQueues();
    debugPrint('GrpcRecommendationService initialized with queues prefilled');
  } catch (e) {
    debugPrint('Error initializing GrpcRecommendationService: $e');
  }

  // --- Initialize ContinuousPlaybackService ---
  try {
    await continuousPlaybackService.initialize();
    debugPrint('ContinuousPlaybackService initialized');
  } catch (e) {
    debugPrint('Error initializing ContinuousPlaybackService: $e');
  }
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
  final GlobalKey _searchBarKey = GlobalKey();
  final GlobalKey<SpotifyWebPlayerState> _globalWebPlayerKey = GlobalKey();
  final SpotifyService _globalSpotifyService = SpotifyService(); // Shared service instance
  String _currentMediaType = 'music'; // Default media type
  String _searchQuery = '';
  bool _isSearchActive = false;
  bool _isSpotifySearchEnabled = false; // Toggle for Spotify vs Interestnaut search

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
      _isSearchActive = query.isNotEmpty;
    });

    String searchType = _currentMediaType == 'music' && _isSpotifySearchEnabled ? 'spotify' : _currentMediaType;
    debugPrint('Searching for "$query" in $searchType (media: $_currentMediaType, spotify: $_isSpotifySearchEnabled)');
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _isSearchActive = false;
    });
  }

  void _closeSearchResults() {
    setState(() {
      _isSearchActive = false;
      // Keep _searchQuery so text stays in search field
    });
  }

  void _toggleSearchType() {
    setState(() {
      _isSpotifySearchEnabled = !_isSpotifySearchEnabled;
    });
    // Re-perform search with the new type without clearing
    if (_searchQuery.isNotEmpty) {
      _handleSearch(_searchQuery);
    }
  }

  void _handleMediaChange(String media) {
    // Clear any active focus when switching media types to prevent keyboard conflicts
    FocusScope.of(context).unfocus();
    
    setState(() {
      _currentMediaType = media;
    });
  }

  Widget? _buildSearchToggle() {
    // Moved to settings drawer for music section
    return null;
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
          // Header - absolutely positioned for transparency/blur
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MediaHeader(
              key: _searchBarKey,
              onSearch: _handleSearch,
              onClearSearch: _clearSearch,
              currentMedia: _currentMediaType,
              onMediaChange: _handleMediaChange,
              searchQuery: _searchQuery,
              additionalControl: _buildSearchToggle(),
              spotifySearchEnabled: _isSpotifySearchEnabled,
              onSpotifySearchToggle: (value) => _toggleSearchType(),
            ),
          ),
          // Global Spotify Player Bar - positioned at bottom, shows when music is playing
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: StreamBuilder<Track>(
              stream: SpotifyEvents.onTrackChange,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return const SpotifyPlayer(
                    key: ValueKey('global_spotify_player'),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
                        ),
          ),
          // Global Spotify Web Player - tiny but visible for audio permissions
          Positioned(
            bottom: 100, // Position above the player bar
            right: 10,   // Small corner position
            child: SizedBox(
              width: 1,
              height: 1,
              child: Opacity(
                opacity: 0.01, // Nearly invisible but technically visible
                child: SpotifyWebPlayer(
                  key: _globalWebPlayerKey,
                  spotifyService: _globalSpotifyService,
                  visible: true, // Make it visible for audio permissions
                  onError: (error) {
                    debugPrint('Global Spotify Web Player error: $error');
                  },
                ),
              ),
            ),
          ),
          if (_isSearchActive)
            _buildSearchOverlay(context),
        ],
      ),
    );
  }

  Widget _buildCurrentContent() {
    switch (_currentMediaType) {
      case 'music':
        return const MusicSection();
      case 'movies':
        return const MovieSection();
      case 'tv':
        return const TVShowSection();
      case 'games':
        return const GameSection();
      case 'books':
        return const BookSection();
      default:
        return const Center(child: Text('Home Section', style: TextStyle(color: Colors.white)));
    }
  }

  Widget _buildSearchOverlay(BuildContext context) {
    // Get the position and size of the search bar
    final RenderBox? box = _searchBarKey.currentContext?.findRenderObject() as RenderBox?;
    final Offset offset = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final double barHeight = box?.size.height ?? 0;
    final double barWidth = box?.size.width ?? MediaQuery.of(context).size.width;
    return Stack(
      children: [
        // Dim background BELOW the search bar only
        Positioned(
          top: offset.dy + barHeight,
          left: 0,
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: _clearSearch,
            child: Container(
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        ),
        // Search results window directly below the search bar
        Positioned(
          left: offset.dx,
          top: offset.dy + barHeight,
          width: barWidth,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
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
            child: _UnifiedSearchHandler(
              searchQuery: _searchQuery,
              mediaType: _currentMediaType,
              searchType: _currentMediaType == 'music' && _isSpotifySearchEnabled ? 'spotify' : _currentMediaType,
              onClearSearch: _closeSearchResults,
              spotifySearchEnabled: _isSpotifySearchEnabled,
              onSpotifySearchToggle: (value) => _toggleSearchType(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Simple data class to replace vector_db MediaSearchResult for gRPC migration
class MediaSearchResult {
  final String mediaId;
  final String? title;
  final String? artist;
  final String? album;
  final String? description;
  final String? themes;
  final String? genres;
  final String? wikiUrl;
  final String? wikidataId;
  final String? coverArtUrl;
  final String? youtubeId;
  final String? spotifyId;
  final String mediaType;

  MediaSearchResult({
    required this.mediaId,
    this.title,
    this.artist,
    this.album,
    this.description,
    this.themes,
    this.genres,
    this.wikiUrl,
    this.wikidataId,
    this.coverArtUrl,
    this.youtubeId,
    this.spotifyId,
    required this.mediaType,
  });
}

// A unified search handler that uses Spotify for music and Wikidata for other media types
class _UnifiedSearchHandler extends StatefulWidget {
  final String searchQuery;
  final String mediaType;
  final String searchType;
  final VoidCallback onClearSearch;
  final bool? spotifySearchEnabled;
  final ValueChanged<bool>? onSpotifySearchToggle;

  const _UnifiedSearchHandler({
    Key? key,
    required this.searchQuery,
    required this.mediaType,
    required this.searchType,
    required this.onClearSearch,
    this.spotifySearchEnabled,
    this.onSpotifySearchToggle,
  }) : super(key: key);

  @override
  State<_UnifiedSearchHandler> createState() => _UnifiedSearchHandlerState();
}

class _UnifiedSearchHandlerState extends State<_UnifiedSearchHandler> {
  final SpotifyService _spotifyService = SpotifyService();
  final GrpcRecommendationClient _grpcClient = GrpcRecommendationClient();
  
  List<dynamic> _searchResults = []; // Can be SimpleTrack or WikidataSearchResult  
  bool _isLoading = false;
  String? _error;
  bool _isSpotifyActive = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _checkSpotifyStatus();
    _performSearch(widget.searchQuery);
  }

  @override
  void didUpdateWidget(_UnifiedSearchHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery || 
        widget.mediaType != oldWidget.mediaType ||
        widget.searchType != oldWidget.searchType ||
        widget.spotifySearchEnabled != oldWidget.spotifySearchEnabled) {
      _checkSpotifyStatus();
      _performSearch(widget.searchQuery);
    }
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkSpotifyStatus() async {
    if (widget.mediaType == 'music') {
      _isSpotifyActive = _spotifyService.isAuthenticated;
    } else {
      _isSpotifyActive = false;
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

    // Cancel any existing timer
    _debounceTimer?.cancel();
    
    // Add debouncing for gRPC calls to reduce server load
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      
      setState(() {
        _isLoading = true;
        _error = null;
        _searchResults = []; // Clear previous results when starting new search
      });

      try {
        if (widget.searchType == 'spotify' && _isSpotifyActive) {
          // Use Spotify search when toggle is enabled and authenticated
          final results = await _spotifyService.searchTracks(query);
          if (mounted) {
            setState(() {
              _searchResults = results;
              _isLoading = false;
            });
          }
        } else {
          // Use gRPC backend search for all media types
          debugPrint('🔍 Starting gRPC search for "$query" in ${widget.mediaType}');
          try {
            // Convert media type to backend format
            String backendMediaType;
            switch (widget.mediaType.toLowerCase()) {
              case 'music':
                backendMediaType = 'music';
                break;
              case 'movie':
              case 'movies':
                backendMediaType = 'movie';
                break;
              case 'tv':
              case 'show':
              case 'shows':
                backendMediaType = 'tv_show';
                break;
              case 'book':
              case 'books':
                backendMediaType = 'book';
                break;
              case 'game':
              case 'games':
                backendMediaType = 'video_game';
                break;
              default:
                backendMediaType = widget.mediaType;
            }
            
            // Initialize gRPC client if not already done
            if (!_grpcClient.isInitialized) {
              await _grpcClient.init();
            }
            
            // Use searchMedia endpoint with query as constraint
            final results = await _grpcClient.searchMedia(
              mediaType: backendMediaType,
              constraints: [query], // Pass query as constraint for text search
              limit: 20,
            );
            
            // Convert MediaSuggestion to WikidataSearchResult for UI compatibility
            final convertedResults = results.map((result) {
              // Debug logging for YouTube/Spotify IDs
              if (result.youtubeId != null && result.youtubeId!.isNotEmpty) {
                debugPrint('🎬 [FLUTTER-SEARCH] ${result.title} has YouTube ID: ${result.youtubeId}');
              }
              if (result.spotifyId != null && result.spotifyId!.isNotEmpty) {
                debugPrint('🎵 [FLUTTER-SEARCH] ${result.title} has Spotify ID: ${result.spotifyId}');
              }
              
              return WikidataSearchResult(
                id: result.mediaId ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}',
                title: result.title ?? 'Unknown',
                artist: result.artist,
                description: result.description,
                imageUrl: result.coverArtUrl,
                releaseDate: null,
                genre: null,
                additionalData: {
                  'source': 'grpc_backend',
                  'themes': result.themes,
                  'genres': result.genres?.join(', '), // Convert List<String> to comma-separated string
                  'wikiUrl': result.wikiUrl,
                  'wikidataId': result.wikidataId,
                  'youtubeId': result.youtubeId,
                  'spotifyId': result.spotifyId,
                  'reasoning': result.botReasoning,
                },
              );
            }).toList();
            
            debugPrint('✅ gRPC search returned ${convertedResults.length} results');
            if (mounted) {
              setState(() {
                _searchResults = convertedResults;
                _isLoading = false;
              });
            }
          } catch (e) {
            debugPrint('❌ gRPC search error: $e');
            if (mounted) {
              setState(() {
                _searchResults = [];
                _isLoading = false;
                _error = 'Search failed: $e';
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Error searching ${widget.mediaType}: $e');
        if (mounted) {
          setState(() {
            _error = 'Failed to search ${widget.mediaType}: $e';
            _isLoading = false;
          });
        }
      }
    });
  }

  Future<void> _handlePlay(dynamic item) async {
    if (item is SimpleTrack) {
      try {
        await _spotifyService.playTrack(item.uri);
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
    } else if (item is SpotifyTrack) {
      try {
        // For SpotifyTrack objects, create a Track object for playback
        final track = Track(
          id: item.id,
          name: item.name,
          artists: [Artist(name: item.artist)],
          album: Album(name: item.album ?? 'Unknown Album', images: item.albumArtUrl != null ? [
            ImageData(url: item.albumArtUrl!, height: 300, width: 300)
          ] : []),
          uri: item.uri,
          previewUrl: item.previewUrl ?? '',
        );
        await _spotifyService.playTrack(track.uri);
      } catch (e) {
        debugPrint('Error playing Spotify track: $e');
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
    // For Wikipedia results, we don't have play functionality
  }

  Future<void> _handleSave(dynamic item) async {
    if (item is SimpleTrack) {
      try {
        await _spotifyService.saveTrack(item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added "${item.name}" to your library'),
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
    } else if (item is SpotifyTrack) {
      try {
        await _spotifyService.saveTrack(item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added "${item.name}" to your library'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        // Trigger a refresh of the Spotify library to show the newly saved track
        // Note: This would need to be implemented to refresh the liked tracks section
        debugPrint('🔄 Track saved to Spotify library - should refresh likes section');
      } catch (e) {
        debugPrint('Error saving Spotify track: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save track: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else if (item is InterestnautTrack) {
      // For Interestnaut tracks, save to local database with YouTube/Spotify IDs
      await _addInterestnautTrackToFavorites(item);
    } else if (item is WikidataSearchResult) {
      // For vector database results, add to favorites
      await _addToFavorites(item);
    }
  }

  Future<void> _addInterestnautTrackToFavorites(InterestnautTrack track) async {
    try {
      final db = SQLiteDatabase();
      
      // Create media item with YouTube/Spotify IDs preserved
      final mediaItemId = await db.createOrGetMediaItem(
        mediaType: 'music',
        vectorMediaId: 'music_${track.id}', // Use track ID as vector media ID
        title: track.name,
        primaryCreator: track.artist,
        coverArtUrl: track.albumArtUrl,
        description: track.album != null ? 'Album: ${track.album}' : null,
        wikiUrl: null,
        wikidataId: null,
        themes: null,
        genres: null, // TODO: Extract genres if available
        youtubeId: track.youtubeId, // Preserve YouTube ID
        spotifyId: track.spotifyId, // Preserve Spotify ID
      );
      
      // Add to favorites
      await db.addToFavorites(mediaItemId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${track.name}" to favorites'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      debugPrint('✅ Added Interestnaut track to favorites: ${track.name} (YouTube: ${track.youtubeId}, Spotify: ${track.spotifyId})');
      
      // Refresh favorites list
      WidgetsBinding.instance.addPostFrameCallback((_) {
        MusicSection.refreshFavoritesFromSearch(
          title: track.name,
          primaryCreator: track.artist,
        );
      });
    } catch (e) {
      debugPrint('❌ Error adding Interestnaut track to favorites: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add track to favorites: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _addToFavorites(WikidataSearchResult item) async {
    try {
      final db = SQLiteDatabase();
      
      // Add directly to favorites using the new normalized schema
      await db.addSearchItemToFavorites(
        mediaType: _convertMediaTypeToDb(widget.mediaType),
        title: item.title,
        primaryCreator: item.artist ?? '',
        vectorMediaId: item.id,
        coverArtUrl: item.imageUrl,
        description: item.description,
        wikiUrl: item.additionalData?['wikiUrl'],
        wikidataId: item.additionalData?['wikidataId'],
        themes: item.additionalData?['themes'],
        genres: item.additionalData?['genres'],
        youtubeId: item.additionalData?['youtubeId'],
        spotifyId: item.additionalData?['spotifyId'],
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${item.title}" to your favorites'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      debugPrint('✅ Added search result to favorites: ${item.title}');
      
      // Database operation is complete (await above), now refresh immediately
      // Use WidgetsBinding to ensure refresh happens after current frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Refresh the appropriate section's favorites list
        switch (widget.mediaType.toLowerCase()) {
          case 'music':
            MusicSection.refreshFavoritesFromSearch(
              title: item.title,
              primaryCreator: item.artist ?? '',
            );
            break;
          case 'movie':
          case 'movies':
            MovieSection.refreshFavoritesFromSearch(
              title: item.title,
              primaryCreator: item.artist ?? '',
            );
            break;
          case 'tv':
          case 'show':
          case 'shows':
            TVShowSection.refreshFavoritesFromSearch(
              title: item.title,
              primaryCreator: item.artist ?? '',
            );
            break;
          case 'book':
          case 'books':
            BookSection.refreshFavoritesFromSearch(
              title: item.title,
              primaryCreator: item.artist ?? '',
            );
            break;
          case 'game':
          case 'games':
            GameSection.refreshFavoritesFromSearch(
              title: item.title,
              primaryCreator: item.artist ?? '',
            );
            break;
        }
      });
    } catch (e) {
      debugPrint('❌ Error adding to favorites: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to favorites: $e'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _convertMediaTypeToDb(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'music':
        return 'music';
      case 'movie':
      case 'movies':
        return 'movie';
      case 'tv':
      case 'show':
      case 'shows':
        return 'tv_show';
      case 'book':
      case 'books':
        return 'book';
      case 'game':
      case 'games':
        return 'video_game';
      default:
        return mediaType;
    }
  }

  void _refreshFavoritesForMediaType(String mediaType, {String? title, String? primaryCreator}) {
    try {
      switch (mediaType.toLowerCase()) {
        case 'music':
          MusicSection.refreshFavoritesFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
        case 'movie':
        case 'movies':
          MovieSection.refreshFavoritesFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
        case 'tv':
        case 'show':
        case 'shows':
        case 'tv_show':
          TVShowSection.refreshFavoritesFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
        case 'book':
        case 'books':
          BookSection.refreshFavoritesFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
        case 'game':
        case 'games':
        case 'video_game':
          GameSection.refreshFavoritesFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
      }
    } catch (e) {
      debugPrint('❌ Error refreshing favorites: $e');
    }
  }

  void _refreshWatchlistForMediaType(String mediaType, {String? title, String? primaryCreator}) {
    try {
      switch (mediaType.toLowerCase()) {
        case 'music':
          MusicSection.refreshPlaylistFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
        case 'movie':
        case 'movies':
          MovieSection.refreshWatchlistFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
        case 'tv':
        case 'show':
        case 'shows':
        case 'tv_show':
          TVShowSection.refreshWatchlistFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
        case 'book':
        case 'books':
          BookSection.refreshReadingListFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
        case 'game':
        case 'games':
        case 'video_game':
          GameSection.refreshPlaylistFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
      }
    } catch (e) {
      debugPrint('❌ Error refreshing watchlist: $e');
    }
  }

  Future<void> _handleAddToWatchlist(dynamic item) async {
    if (item is WikidataSearchResult) {
      try {
        final db = SQLiteDatabase();
        
        // Add directly to watchlist using the new normalized schema
        await db.addSearchItemToWatchlist(
          mediaType: _convertMediaTypeToDb(widget.mediaType),
          title: item.title,
          primaryCreator: item.artist ?? '',
          vectorMediaId: item.id,
          coverArtUrl: item.imageUrl,
          description: item.description,
          wikiUrl: item.additionalData?['wikiUrl'],
          wikidataId: item.additionalData?['wikidataId'],
          themes: item.additionalData?['themes'],
          genres: item.additionalData?['genres'],
          youtubeId: item.additionalData?['youtubeId'],
          spotifyId: item.additionalData?['spotifyId'],
        );
        
        String watchlistTerm = _getWatchlistTerminology();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added "${item.title}" to your ${watchlistTerm.toLowerCase()}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        debugPrint('✅ Added search result to ${watchlistTerm.toLowerCase()}: ${item.title}');
        
        // Database operation is complete (await above), now refresh immediately
        // Use WidgetsBinding to ensure refresh happens after current frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Refresh the appropriate section's watchlist
          _refreshWatchlistForMediaType(
            widget.mediaType,
            title: item.title,
            primaryCreator: item.artist ?? '',
          );
        });
      } catch (e) {
        debugPrint('❌ Error adding to watchlist: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add to watchlist: $e'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  String _getWatchlistTerminology() {
    switch (widget.mediaType.toLowerCase()) {
      case 'music':
        return 'Playlist';
      case 'movie':
      case 'movies':
      case 'tv':
      case 'show':
      case 'shows':
        return 'Watchlist';
      case 'book':
      case 'books':
        return 'Reading List';
      case 'game':
      case 'games':
        return 'Playlist';
      default:
        return 'List';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.searchType == 'spotify') {
      if (_isSpotifyActive) {
        // Use existing SearchSection for Spotify results with limited actions
        return SearchSection(
          searchResults: _searchResults.whereType<SimpleTrack>()
              .map((track) => SpotifyTrack.fromSimpleTrack(track))
              .cast<BaseTrack>()
              .toList(),
          isLoading: _isLoading,
          error: _error,
          onSearch: _performSearch,
          onPlay: _handlePlay,
          onSave: _handleSave,
          onRemove: (track) async {}, // TODO: Implement remove functionality
          onRetry: () => _performSearch(widget.searchQuery),
          onClose: widget.onClearSearch,
          limitToSpotifyActions: true, // Limit actions for Spotify content
          spotifySearchEnabled: widget.spotifySearchEnabled,
          onSpotifySearchToggle: widget.onSpotifySearchToggle,
        );
      } else {
        // Show authentication required message
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SpotifyBranding(
                type: SpotifyBrandingType.fullLogo,
                size: SpotifyBrandingSize.medium,
                color: SpotifyBrandingColor.green,
                showAttribution: false,
              ),
              const SizedBox(height: 16),
              const Text(
                'Connect to Spotify to search music',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Use the Spotify button in the header to connect',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
    } else if (widget.mediaType == 'music') {
      // Convert WikidataSearchResult to InterestnautTrack for music searches
      final interestnautTracks = _searchResults.map((result) {
        if (result is WikidataSearchResult) {
          return InterestnautTrack.fromWikidataResult(result);
        }
        // Handle SimpleTrack from Spotify results
        if (result is SimpleTrack) {
          return SpotifyTrack.fromSimpleTrack(result);
        }
        // This shouldn't happen, but provide a fallback
        throw Exception('Unknown result type: ${result.runtimeType}');
      }).toList();
      
      // Use SearchSection for Interestnaut music search results  
      return SearchSection(
        searchResults: interestnautTracks,
        isLoading: _isLoading,
        error: _error,
        onSearch: _performSearch,
        onPlay: _handlePlay,
        onSave: _handleSave,
        onRemove: (track) async {}, // TODO: Implement remove functionality
        onRetry: () => _performSearch(widget.searchQuery),
        onClose: widget.onClearSearch,
        limitToSpotifyActions: false, // Full actions for Interestnaut content
        spotifySearchEnabled: widget.spotifySearchEnabled,
        onSpotifySearchToggle: widget.onSpotifySearchToggle,
      );
    } else {
      // Create a new search section for Wikipedia results
      return _WikidataSearchSection(
        searchResults: _searchResults.cast<WikidataSearchResult>(),
        mediaType: widget.mediaType,
        isLoading: _isLoading,
        error: _error,
        onAddToFavorites: _handleSave,
        onAddToWatchlist: _handleAddToWatchlist,
        onRetry: () => _performSearch(widget.searchQuery),
        onClose: widget.onClearSearch,
      );
    }
  }
}

// Widget to display Wikipedia search results
class _WikidataSearchSection extends StatelessWidget {
  final List<WikidataSearchResult> searchResults;
  final String mediaType;
  final bool isLoading;
  final String? error;
  final Function(WikidataSearchResult) onAddToFavorites;
  final Function(WikidataSearchResult) onAddToWatchlist;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const _WikidataSearchSection({
    Key? key,
    required this.searchResults,
    required this.mediaType,
    required this.isLoading,
    this.error,
    required this.onAddToFavorites,
    required this.onAddToWatchlist,
    required this.onRetry,
    required this.onClose,
  }) : super(key: key);

  String _getSearchResultsText(int count, String mediaType) {
    if (count == 0) return 'No results';
    
    // Convert plural mediaType to singular for count = 1
    String singularType = _getSingularMediaType(mediaType);
    String pluralType = _getPluralMediaType(mediaType);
    
    if (count == 1) {
      return 'Found 1 $singularType';
    }
    return 'Found $count $pluralType';
  }
  
  String _getSingularMediaType(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'books': return 'book';
      case 'movies': return 'movie';
      case 'games': return 'game';
      case 'tv': return 'show';
      case 'music': return 'track';
      default: return mediaType;
    }
  }
  
  String _getPluralMediaType(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'book': return 'books';
      case 'movie': return 'movies';
      case 'game': return 'games';
      case 'tv': return 'shows';
      case 'music': return 'tracks';
      default: 
        // If already plural, return as-is
        if (mediaType.endsWith('s')) return mediaType;
        return '${mediaType}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Colors.white70),
          ),
        ),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7B68EE),
                  side: const BorderSide(color: Color(0xFF7B68EE)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.5,
                    fontFamily: 'Inter',
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 120, // Constrain to minimum height like one result row
          child: Stack(
            children: [
              // Centered "No results" text
              Center(
                child: Transform.scale(
                  scaleX: 1.15, // Same horizontal stretch as stylized headers
                  child: const Text(
                    'No results',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              // X button positioned in top right
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onClose, // This should clear the search and close overlay
                  child: Container(
                    width: 24,
                    height: 24,
                    child: CustomPaint(
                      painter: _SearchXButtonPainter(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Use column layout with sticky header for search results
    return Column(
      children: [
        // Sticky header with results count and X button
        Container(
          padding: const EdgeInsets.fromLTRB(32.0, 16.0, 16.0, 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Transform.scale(
                scaleX: 1.15, // Same horizontal stretch as stylized headers
                child: Text(
                  _getSearchResultsText(searchResults.length, mediaType),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 28, // Slightly larger for easier tapping
                  height: 28,
                  child: CustomPaint(
                    painter: _SearchXButtonPainter(),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Scrollable results area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
            child: SingleChildScrollView(
              child: MediaGrid(
                columns: 3, // Using 3 columns for better readability
                children: searchResults
                    .map((result) => _WikidataCard(
                          result: result,
                          mediaType: mediaType,
                          onAddToFavorites: () => onAddToFavorites(result),
                          onAddToWatchlist: () => onAddToWatchlist(result),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Card component that matches SearchResultCard layout for Wikipedia results
class _WikidataCard extends StatefulWidget {
  final WikidataSearchResult result;
  final String mediaType;
  final VoidCallback onAddToFavorites;
  final VoidCallback onAddToWatchlist;

  const _WikidataCard({
    Key? key,
    required this.result,
    required this.mediaType,
    required this.onAddToFavorites,
    required this.onAddToWatchlist,
  }) : super(key: key);

  @override
  State<_WikidataCard> createState() => _WikidataCardState();
}

class _WikidataCardState extends State<_WikidataCard> {
  bool _isHovered = false;

  IconData _getMediaIcon() {
    switch (widget.mediaType.toLowerCase()) {
      case 'book':
      case 'books':
        return Icons.book;
      case 'music':
      case 'song':
      case 'album':
        return Icons.music_note;
      case 'movie':
      case 'movies':
      case 'film':
        return Icons.movie;
      case 'tv':
      case 'television':
      case 'show':
        return Icons.tv;
      case 'game':
      case 'games':
      case 'videogame':
        return Icons.games;
      default:
        return Icons.help_outline;
    }
  }

  String _convertMediaTypeToDb(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'music':
        return 'music';
      case 'movie':
      case 'movies':
        return 'movie';
      case 'tv':
      case 'show':
      case 'shows':
        return 'tv_show';
      case 'book':
      case 'books':
        return 'book';
      case 'game':
      case 'games':
        return 'video_game';
      default:
        return mediaType;
    }
  }

  void _refreshFavoritesForMediaType(String mediaType, {String? title, String? primaryCreator}) {
    try {
      switch (mediaType.toLowerCase()) {
        case 'music':
          MusicSection.refreshFavoritesFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
        case 'movie':
        case 'movies':
          MovieSection.refreshFavoritesFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
        case 'tv':
        case 'show':
        case 'shows':
        case 'tv_show':
          TVShowSection.refreshFavoritesFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
        case 'book':
        case 'books':
          BookSection.refreshFavoritesFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
        case 'game':
        case 'games':
        case 'video_game':
          GameSection.refreshFavoritesFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
      }
    } catch (e) {
      debugPrint('❌ Error refreshing favorites: $e');
    }
  }

  void _refreshWatchlistForMediaType(String mediaType, {String? title, String? primaryCreator}) {
    try {
      switch (mediaType.toLowerCase()) {
        case 'music':
          MusicSection.refreshPlaylistFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
        case 'movie':
        case 'movies':
          MovieSection.refreshWatchlistFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
        case 'tv':
        case 'show':
        case 'shows':
        case 'tv_show':
          TVShowSection.refreshWatchlistFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
        case 'book':
        case 'books':
          BookSection.refreshReadingListFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
        case 'game':
        case 'games':
        case 'video_game':
          GameSection.refreshPlaylistFromSearch(
            title: title,
            primaryCreator: primaryCreator,
          );
          break;
      }
    } catch (e) {
      debugPrint('❌ Error refreshing watchlist: $e');
    }
  }

  String _getWatchlistTerminology() {
    switch (widget.mediaType.toLowerCase()) {
      case 'music':
      case 'song':
      case 'album':
        return 'Playlist';
      case 'movie':
      case 'movies':
      case 'film':
      case 'tv':
      case 'television':
      case 'show':
        return 'Watchlist';
      case 'book':
      case 'books':
        return 'Reading List';
      case 'game':
      case 'games':
      case 'videogame':
        return 'Wishlist';
      default:
        return 'List';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: _isHovered
            ? Matrix4.translationValues(0, -6, 0)
            : Matrix4.translationValues(0, 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border: Border.all(
            color: _isHovered
                ? const Color.fromRGBO(123, 104, 238, 0.8)
                : const Color.fromRGBO(123, 104, 238, 0.3),
            width: _isHovered ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? const Color.fromRGBO(123, 104, 238, 0.3)
                  : Colors.black.withOpacity(0.3),
              blurRadius: _isHovered ? 16 : 8,
              offset: _isHovered ? const Offset(0, 8) : const Offset(0, 4),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: () => _openMediaDetailDrawer(context),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Reserve space for title/artist at bottom (~45px) and calculate artwork size
              final titleHeight = 45.0;
              final availableHeight = constraints.maxHeight - titleHeight;
              final maxArtworkSize = constraints.maxWidth; // Fill width
              final artworkSize = availableHeight > maxArtworkSize ? maxArtworkSize : availableHeight;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Media artwork - fills most of the card
                Expanded(
                  child: Container(
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppTheme.cardBorderRadius),
                        topRight: Radius.circular(AppTheme.cardBorderRadius),
                      ),
                      child: widget.result.imageUrl != null && widget.result.imageUrl!.isNotEmpty
                          ? Image.network(
                              widget.result.imageUrl!,
                              fit: BoxFit.contain, // Fit naturally without cropping
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: AppTheme.cardBackgroundColor,
                                  child: Center(
                                    child: Icon(_getMediaIcon(), size: 48, color: Colors.white54),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: AppTheme.cardBackgroundColor,
                              child: Center(
                                child: Icon(_getMediaIcon(), size: 48, color: Colors.white54),
                              ),
                            ),
                    ),
                  ),
                ),

                // Title and artist at bottom - clean and simple
                Container(
                  height: titleHeight,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(AppTheme.cardBorderRadius),
                      bottomRight: Radius.circular(AppTheme.cardBorderRadius),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromRGBO(28, 28, 28, 0.98),
                        Color.fromRGBO(35, 35, 35, 0.98),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center, // Center the text
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Display logic: if title is empty/null, show artist as title
                      Flexible(
                        child: Text(
                          (widget.result.title?.isNotEmpty == true) 
                              ? widget.result.title 
                              : widget.result.artist ?? 'Unknown',
                          style: InterestFonts.searchCardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Only show artist as subtitle if we have both title and artist
                      if (widget.result.title?.isNotEmpty == true && widget.result.artist != null) ...[
                        const SizedBox(height: 2),
                        Flexible(
                          child: Text(
                            widget.result.artist!,
                            style: InterestFonts.searchCardArtist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
    );
  }

  /// Helper method to filter out invalid string values from gRPC responses
  /// Returns null if the value is null, empty, or the string "null"
  String? _getValidString(String? value) {
    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      return null;
    }
    return value;
  }

  /// Opens the media detail drawer when cover art is clicked
  Future<void> _openMediaDetailDrawer(BuildContext context) async {
    try {
      // Get comprehensive status using single source of truth lookup
      final db = SQLiteDatabase();
      final statusResult = await db.getMediaItemStatus(vectorMediaId: widget.result.id);
      
      // Debug what data we have available
      debugPrint('🔧 [DRAWER-DATA] additionalData keys: ${widget.result.additionalData?.keys.toList()}');
      debugPrint('🔧 [DRAWER-DATA] genres from additionalData: "${widget.result.additionalData?['genres']}" (filtered: "${_getValidString(widget.result.additionalData?['genres'] as String?)}")');
      debugPrint('🔧 [DRAWER-DATA] genres from statusResult: "${statusResult['genres']}"');

      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          enableDrag: true,
          isDismissible: true,
          barrierColor: Colors.black54,
          builder: (context) => GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {}, // Prevent tap-through
                child: MediaDetailDrawer(
                  title: widget.result.title,
                  artist: widget.result.artist,
                  description: widget.result.description,
                  themes: _getValidString(widget.result.additionalData?['themes'] as String?),
                  genres: _getValidString(widget.result.additionalData?['genres'] as String?) ?? statusResult['genres'] as String?,
                  youtubeId: widget.result.additionalData?['youtubeId'] as String? ?? statusResult['youtubeId'] as String?,
                  spotifyId: widget.result.additionalData?['spotifyId'] as String? ?? statusResult['spotifyId'] as String?,
                  coverArtUrl: widget.result.imageUrl,
                  mediaType: widget.mediaType,
                  hasLiked: statusResult['hasLiked'] as bool? ?? false,
                  hasDisliked: statusResult['hasDisliked'] as bool? ?? false,
                  hasFavorited: statusResult['hasFavorited'] as bool? ?? false,
                  isInWatchlist: statusResult['isInWatchlist'] as bool? ?? false,
                  hasSkipped: statusResult['hasSkipped'] as bool? ?? false,
                  onAction: (action) => _handleDrawerAction(
                    context,
                    action,
                    MediaSearchResult(
                      mediaId: widget.result.id,
                      title: widget.result.title,
                      artist: widget.result.artist,
                      album: null,
                      description: widget.result.description,
                      themes: widget.result.additionalData?['themes'] as String?,
                      genres: widget.result.additionalData?['genres'] as String?,
                      wikiUrl: widget.result.additionalData?['wikiUrl'] as String?,
                      wikidataId: widget.result.additionalData?['wikidataId'] as String?,
                      coverArtUrl: widget.result.imageUrl,
                      youtubeId: widget.result.additionalData?['youtubeId'] as String?,
                      spotifyId: widget.result.additionalData?['spotifyId'] as String?,
                      mediaType: widget.mediaType,
                    ),
                    statusResult['mediaItemId'] as int?,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error opening media detail drawer: $e');
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Error'),
            content: Text('Failed to load item details: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Handle actions from the media detail drawer
  Future<void> _handleDrawerAction(
    BuildContext context,
    String action,
    MediaSearchResult item,
    int? existingMediaItemId,
  ) async {
    try {
      final db = SQLiteDatabase();
      
      // Create or get the media item if it doesn't exist
      int mediaItemId;
      if (existingMediaItemId != null) {
        mediaItemId = existingMediaItemId;
      } else {
        mediaItemId = await db.createOrGetMediaItem(
          mediaType: _convertMediaTypeToDb(widget.mediaType),
          vectorMediaId: item.mediaId,
          title: item.title ?? 'Unknown',
          primaryCreator: item.artist ?? '',
          coverArtUrl: item.coverArtUrl,
          description: item.description,
          wikiUrl: item.wikiUrl,
          wikidataId: item.wikidataId,
          themes: item.themes,
          genres: item.genres,
          youtubeId: item.youtubeId,
          spotifyId: item.spotifyId
        );
        debugPrint('🔍 [SEARCH-DRAWER] Created new media item with ID: $mediaItemId');
      }

      switch (action) {
        case 'like':
          // Add to favorites and handle other logic as needed
          await db.addToFavorites(mediaItemId);
          // Refresh favorites list
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _refreshFavoritesForMediaType(widget.mediaType, title: item.title, primaryCreator: item.artist);
          });
          break;
          
        case 'dislike':
          // Handle dislike action
          // Implementation depends on your requirements
          break;
          
        case 'favorite':
          // Add to favorites table
          await db.addToFavorites(mediaItemId);
          // Refresh favorites list
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _refreshFavoritesForMediaType(widget.mediaType, title: item.title, primaryCreator: item.artist);
          });
          break;
          
        case 'watchlist':
          // Add to watchlist table
          await db.addToWatchlist(mediaItemId);
          // Refresh watchlist
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _refreshWatchlistForMediaType(widget.mediaType, title: item.title, primaryCreator: item.artist);
          });
          break;
          
        case 'skip':
          // Handle skip action
          // Implementation depends on your requirements
          break;

        case 'clear_all':
          // Handle clearing all reactions
          // Implementation depends on your requirements
          break;
      }
      
      debugPrint('✅ [SEARCH-DRAWER] Handled action: $action for ${item.title}');
    } catch (e) {
      debugPrint('❌ [SEARCH-DRAWER] Error handling drawer action: $e');
    }
  }

  Widget _buildMiniPlayButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Icon(
              icon,
              color: color,
              size: 14,
            ),
          ),
        ),
      ),
    );
  }

  void _openYouTube(String videoId) async {
    try {
      // Show internal YouTube player dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => YouTubePlayerDialog(videoId: videoId),
        );
      }
    } catch (e) {
      debugPrint('Error opening YouTube player: $e');
      // Fallback to external app
      _openYouTubeExternal(videoId);
    }
  }
  
  void _openYouTubeExternal(String videoId) async {
    try {
      final url = 'https://www.youtube.com/watch?v=$videoId';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch YouTube URL: $url');
      }
    } catch (e) {
      debugPrint('Error opening YouTube: $e');
    }
  }

  void _openSpotify(String trackId) async {
    try {
      // Check if user is authenticated with Spotify
      final spotifyService = SpotifyService();
      final isAuthenticated = await spotifyService.checkAuthentication();
      
      if (!isAuthenticated && mounted) {
        // Show preview dialog for non-authenticated users
        showDialog(
          context: context,
          builder: (context) => SpotifyPreviewDialog(
            trackId: trackId,
            trackName: widget.result.title,
            artistName: widget.result.artist,
          ),
        );
      } else {
        // For authenticated users, use the existing external launch behavior
        final spotifyUrl = 'spotify:track:$trackId';
        final webUrl = 'https://open.spotify.com/track/$trackId';
        
        // Try Spotify app first, fallback to web
        if (await canLaunchUrl(Uri.parse(spotifyUrl))) {
          await launchUrl(Uri.parse(spotifyUrl), mode: LaunchMode.externalApplication);
        } else if (await canLaunchUrl(Uri.parse(webUrl))) {
          await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
        } else {
          debugPrint('Could not launch Spotify URL: $webUrl');
        }
      }
    } catch (e) {
      debugPrint('Error opening Spotify: $e');
    }
  }
}

/// Custom painter for the search X button - matches watchlist X styling
class _SearchXButtonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Purple outline paint (thicker)
    final outlinePaint = Paint()
      ..color = const Color(0xFFA855F7)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // White X paint (thinner, on top)
    final xPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Draw purple outline first (behind)
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.25),
      Offset(size.width * 0.75, size.height * 0.75),
      outlinePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.25),
      Offset(size.width * 0.25, size.height * 0.75),
      outlinePaint,
    );

    // Draw white X on top
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.25),
      Offset(size.width * 0.75, size.height * 0.75),
      xPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.25),
      Offset(size.width * 0.25, size.height * 0.75),
      xPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
