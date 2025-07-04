import 'dart:async';
import 'dart:io';
import 'dart:ffi' as ffi;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_size/window_size.dart' as window_package;
import 'package:path_provider/path_provider.dart';
import 'package:ffi/ffi.dart';
// Removed llama_cpp_dart - using TensorFlow Lite instead
import 'package:flutter/services.dart';
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
import 'components/music/spotify_service.dart';
import 'components/music/player/spotify_player_view.dart';
import 'components/music/player/spotify_web_player.dart';
import 'services/tflite_llm_service.dart';
import 'services/wikidata_service.dart';
import 'services/wikipedia_service.dart';
import 'services/recommendation_service.dart';
import 'services/sqlite_db.dart';
import 'services/ffi_init.dart';
import 'services/go_bindings.dart';
import 'models.dart';
import 'theme.dart';
import 'db/vector_db.dart'; // Import for VectorDatabase



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

  // --- Initialize TensorFlow Lite LLM Service ---
  final tfliteService = TFLiteLLMService();
  bool llmInitialized = false;

  try {
    // Initialize TensorFlow Lite LLM (looks for model in Documents/models/)
    debugPrint('🔄 Starting TensorFlow Lite LLM initialization...');
    llmInitialized = await tfliteService.initialize();
    
    if (llmInitialized) {
      debugPrint('✅ TensorFlow Lite LLM initialized successfully');
    } else {
      debugPrint('❌ TensorFlow Lite LLM initialization failed - continuing with limited functionality');
    }
  } catch (e) {
    debugPrint('💥 Error initializing TensorFlow Lite LLM: $e');
    debugPrint('📍 Stack trace: ${StackTrace.current}');
    // Continue anyway, the app will handle missing LLM gracefully
  }

  // --- Initialize RecommendationService ---
  // Create the recommendation service
  final recommendationService = RecommendationService();

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
  runApp(
    MultiProvider(
      providers: [
        // Provide TensorFlow Lite LLM Service, RecommendationService, etc.
        Provider.value(value: tfliteService),
        ChangeNotifierProvider.value(value: recommendationService),
        // If SpotifyService needs to be a provider:
        Provider.value(value: SpotifyService()),
      ],
      child: const MyApp(),
    ),
  );

  // --- Post-runApp async initialization for RecommendationService ---
  // Initialize the recommendation service with the SQLite database
  try {
    await recommendationService.init();

    // Prefill recommendation queues if TensorFlow Lite LLM is available
    if (llmInitialized) {
      await recommendationService.prefillQueues();
      debugPrint('RecommendationService initialized with queues prefilled');
    } else {
      debugPrint('RecommendationService initialized without LLM support');
    }
  } catch (e) {
    debugPrint('Error initializing RecommendationService: $e');
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

  void _handleMediaChange(String media) {
    // Clear any active focus when switching media types to prevent keyboard conflicts
    FocusScope.of(context).unfocus();
    
    setState(() {
      _currentMediaType = media;
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
              onClearSearch: _clearSearch,
            ),
          ),
        ),
      ],
    );
  }
}

// A unified search handler that uses Spotify for music and Wikidata for other media types
class _UnifiedSearchHandler extends StatefulWidget {
  final String searchQuery;
  final String mediaType;
  final VoidCallback onClearSearch;

  const _UnifiedSearchHandler({
    Key? key,
    required this.searchQuery,
    required this.mediaType,
    required this.onClearSearch,
  }) : super(key: key);

  @override
  State<_UnifiedSearchHandler> createState() => _UnifiedSearchHandlerState();
}

class _UnifiedSearchHandlerState extends State<_UnifiedSearchHandler> {
  final SpotifyService _spotifyService = SpotifyService();
  final WikidataService _wikidataService = WikidataService();
  
  List<dynamic> _searchResults = []; // Can be SimpleTrack or WikidataSearchResult
  bool _isLoading = false;
  String? _error;
  bool _isSpotifyActive = false;

  @override
  void initState() {
    super.initState();
    _checkSpotifyStatus();
    _performSearch(widget.searchQuery);
  }

  @override
  void didUpdateWidget(_UnifiedSearchHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery || widget.mediaType != oldWidget.mediaType) {
      _checkSpotifyStatus();
      _performSearch(widget.searchQuery);
    }
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

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.mediaType == 'music' && _isSpotifyActive) {
        // Use Spotify for music when authenticated
        final results = await _spotifyService.searchTracks(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isLoading = false;
          });
        }
      } else {
        // Use vector database search for all media types
        debugPrint('🔍 Starting vector database search for "$query" in ${widget.mediaType}');
        try {
          final vectorDb = VectorDatabase();
          await vectorDb.init();
          
          // Convert media type to vector database format
          String dbMediaType;
          switch (widget.mediaType.toLowerCase()) {
            case 'music':
              dbMediaType = 'music';
              break;
            case 'movie':
            case 'movies':
              dbMediaType = 'movie';
              break;
            case 'tv':
            case 'show':
            case 'shows':
              dbMediaType = 'tv_show';
              break;
            case 'book':
            case 'books':
              dbMediaType = 'book';
              break;
            case 'game':
            case 'games':
              dbMediaType = 'video_game';
              break;
            default:
              dbMediaType = widget.mediaType;
          }
          
          // Check if this media type is available in vector database
          if (vectorDb.isMediaTypeAvailable(dbMediaType)) {
            final results = await vectorDb.searchByText(
              query: query,
              mediaType: dbMediaType,
              limit: 20,
            );
            
            // Convert MediaSearchResult to WikidataSearchResult for UI compatibility
            final convertedResults = results.map((result) => WikidataSearchResult(
              id: result.mediaId,
              title: (result.title?.isNotEmpty == true) ? result.title! : 
                     (result.artist?.isNotEmpty == true) ? result.artist! : 'Unknown',
              artist: result.artist,
              description: result.description,
              imageUrl: result.coverArtUrl,
              releaseDate: null,
              genre: null,
              additionalData: {
                'source': 'vector_database',
                'similarity': result.similarity,
                'themes': result.themes,
                'wikiUrl': result.wikiUrl,
                'wikidataId': result.wikidataId,
              },
            )).toList();
            
            debugPrint('✅ Vector database search returned ${convertedResults.length} results');
            if (mounted) {
              setState(() {
                _searchResults = convertedResults;
                _isLoading = false;
              });
            }
          } else {
            // No fallback - just return empty results with a message
            debugPrint('⚠️ Vector database not available for $dbMediaType');
            if (mounted) {
              setState(() {
                _searchResults = [];
                _isLoading = false;
                _error = 'Search database not available for ${widget.mediaType}. Please install the ${widget.mediaType} database first.';
              });
            }
          }
        } catch (e) {
          debugPrint('❌ Vector database search error: $e');
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
    } else if (item is WikidataSearchResult) {
      // For vector database results, add to favorites
      await _addToFavorites(item);
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
        vectorMediaId: item.id?.toString(),
        coverArtUrl: item.imageUrl,
        description: item.description,
        wikiUrl: item.additionalData?['wikiUrl'],
        wikidataId: item.additionalData?['wikidataId'],
        themes: item.additionalData?['themes'],
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
            backgroundColor: Colors.red,
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
          vectorMediaId: item.id?.toString(),
          coverArtUrl: item.imageUrl,
          description: item.description,
          wikiUrl: item.additionalData?['wikiUrl'],
          wikidataId: item.additionalData?['wikidataId'],
          themes: item.additionalData?['themes'],
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
              backgroundColor: Colors.red,
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
    if (widget.mediaType == 'music' && _isSpotifyActive) {
      // Use existing SearchSection for Spotify results
      return SearchSection(
        searchResults: _searchResults.cast<SimpleTrack>(),
        isLoading: _isLoading,
        error: _error,
        onSearch: _performSearch,
        onPlay: _handlePlay,
        onSave: _handleSave,
        onRemove: (track) async {}, // TODO: Implement remove functionality
        onRetry: () => _performSearch(widget.searchQuery),
        onClose: widget.onClearSearch,
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
              ElevatedButton(
                onPressed: onRetry,
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

    // Use the same layout as Spotify search results
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                  child: Transform.scale(
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
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 24,
                    height: 24,
                    child: CustomPaint(
                      painter: _SearchXButtonPainter(),
                    ),
                  ),
                ),
              ],
            ),
            MediaGrid(
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
          ],
        ),
      ),
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
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: _isHovered 
            ? Matrix4.translationValues(0, -4, 0)
            : Matrix4.translationValues(0, 0, 0),
        decoration: BoxDecoration(
          // Uniform gradient background like SearchResultCard
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color.fromRGBO(28, 28, 28, 0.98), // Darker at top
              const Color.fromRGBO(40, 40, 40, 0.95), // Lighter at bottom
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border: Border.all(
            color: _isHovered 
                ? const Color.fromRGBO(123, 104, 238, 0.5)
                : const Color.fromRGBO(123, 104, 238, 0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Reserve space for controls at bottom (~60px) and calculate artwork size
            final controlsHeight = 60.0;
            final availableHeight = constraints.maxHeight - controlsHeight;
            final maxArtworkSize = constraints.maxWidth * 0.75; // Reduced from 85% to 75%
            final artworkSize = availableHeight > maxArtworkSize ? maxArtworkSize : availableHeight;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Media artwork - size calculated to fit properly
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 6.0),
                    child: Center(
                      child: SizedBox(
                        width: artworkSize,
                        height: artworkSize,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4), // 4px for large devices per Spotify guidelines
                          child: widget.result.imageUrl != null && widget.result.imageUrl!.isNotEmpty
                              ? Image.network(
                                  widget.result.imageUrl!,
                                  fit: BoxFit.cover,
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
                  ),
                ),
                
                // Controls panel at bottom - Spotify-style layout with buttons flanking text
                SizedBox(
                  height: controlsHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4.0, 4.0, 4.0, 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Add to Watchlist button - blue bookmark (left side)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.bookmark_add,
                              color: Colors.blue,
                              size: 16,
                            ),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: widget.onAddToWatchlist,
                            tooltip: 'Add to ${_getWatchlistTerminology()}',
                          ),
                        ),
                        
                        // Title and artist/director centered between controls
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.result.title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.5),
                                        offset: const Offset(0, 1),
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                                if (widget.result.artist != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.result.artist!,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 9,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.3),
                                          offset: const Offset(0, 1),
                                          blurRadius: 1,
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        
                        // Add to Favorites button - purple heart (right side)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF7B68EE).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.favorite,
                              color: Color(0xFF7B68EE), // Primary purple color
                              size: 16,
                            ),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: widget.onAddToFavorites,
                            tooltip: 'Add to Favorites',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
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
