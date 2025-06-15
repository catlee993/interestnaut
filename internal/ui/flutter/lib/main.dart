import 'dart:async';
import 'dart:io';
import 'dart:ffi' as ffi;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_size/window_size.dart' as window_package;
import 'package:path_provider/path_provider.dart';
import 'package:ffi/ffi.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

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
import 'services/llama_service.dart';
import 'services/wikidata_service.dart';
import 'services/recommendation_service.dart';
import 'services/ffi_init.dart';
import 'services/go_bindings.dart';
import 'models.dart';
import 'theme.dart';

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

  // --- Initialize LlamaService directly with native Dart implementation ---
  final llamaService = LlamaService();
  bool llamaInitialized = false;

  try {
    // Initialize LlamaService (downloads model if needed)
    llamaInitialized = await llamaService.initialize();
    
    if (llamaInitialized) {
      debugPrint('LlamaService initialized successfully');
    } else {
      debugPrint('LlamaService initialization failed - continuing with limited functionality');
    }
  } catch (e) {
    debugPrint('Error initializing LlamaService: $e');
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
        // Provide LlamaService, RecommendationService, etc.
        Provider.value(value: llamaService),
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

    // Prefill recommendation queues if LlamaService is available
    if (llamaInitialized) {
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
        // Use Wikidata for all other cases
        debugPrint('🔍 Starting Wikidata search for "$query" in ${widget.mediaType}');
        try {
          final results = await _wikidataService.search(query, widget.mediaType);
          debugPrint('✅ Wikidata search returned ${results.length} results');
          if (mounted) {
            setState(() {
              _searchResults = results;
              _isLoading = false;
            });
          }
        } catch (e) {
          debugPrint('❌ Wikidata search error: $e');
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
    // For Wikidata results, we don't have play functionality
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
      // For Wikidata results, add to favorites/watchlist
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${item.title}" to your favorites'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleRemove(dynamic item) async {
    if (item is SimpleTrack) {
      try {
        await _spotifyService.removeTrack(item.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Removed "${item.name}" from your library'),
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
    } else if (item is WikidataSearchResult) {
      // For Wikidata results, remove from favorites/watchlist
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${item.title}" from your favorites'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
        onRemove: _handleRemove,
        onRetry: () => _performSearch(widget.searchQuery),
        onClose: widget.onClearSearch,
      );
    } else {
      // Create a new search section for Wikidata results
      return _WikidataSearchSection(
        searchResults: _searchResults.cast<WikidataSearchResult>(),
        mediaType: widget.mediaType,
        isLoading: _isLoading,
        error: _error,
        onSave: _handleSave,
        onRemove: _handleRemove,
        onRetry: () => _performSearch(widget.searchQuery),
        onClose: widget.onClearSearch,
      );
    }
  }
}

// Widget to display Wikidata search results
class _WikidataSearchSection extends StatelessWidget {
  final List<WikidataSearchResult> searchResults;
  final String mediaType;
  final bool isLoading;
  final String? error;
  final Function(WikidataSearchResult) onSave;
  final Function(WikidataSearchResult) onRemove;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const _WikidataSearchSection({
    Key? key,
    required this.searchResults,
    required this.mediaType,
    required this.isLoading,
    this.error,
    required this.onSave,
    required this.onRemove,
    required this.onRetry,
    required this.onClose,
  }) : super(key: key);

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
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: Text(
            'No results found',
            style: TextStyle(color: Colors.white70),
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
                  padding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
                  child: Text(
                    'Search Results: ${searchResults.length} ${mediaType}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onClose,
                  tooltip: 'Close search',
                ),
              ],
            ),
            MediaGrid(
              columns: 3, // Using 3 columns for better readability
              children: searchResults
                  .map((result) => _WikidataCard(
                        result: result,
                        mediaType: mediaType,
                        onSave: () => onSave(result),
                        onRemove: () => onRemove(result),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// Card component that matches TrackCard layout for Wikidata results
class _WikidataCard extends StatefulWidget {
  final WikidataSearchResult result;
  final String mediaType;
  final VoidCallback onSave;
  final VoidCallback onRemove;

  const _WikidataCard({
    Key? key,
    required this.result,
    required this.mediaType,
    required this.onSave,
    required this.onRemove,
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
          color: AppTheme.surfaceColor,
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media artwork - no overlays, rounded corners per Spotify guidelines
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4), // 4px for large devices per Spotify guidelines
                  child: Container(
                    width: double.infinity,
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
              
              const SizedBox(height: 12),
              
              // Title - separate from artwork
              Text(
                widget.result.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 4),
              
              // Artist/Creator name
              Text(
                widget.result.artist ?? 'Unknown ${widget.mediaType}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 12),
              
              // Controls row - separate from artwork
              Row(
                children: [
                  // Info button instead of play button
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        // Show more info or open Wikipedia link
                        final url = widget.result.additionalData?['url'];
                        if (url != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Wikipedia: $url'),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      tooltip: "More info",
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Save button (same style as TrackCard)
                  TextButton(
                    onPressed: widget.onSave,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: const Size(10, 10),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
