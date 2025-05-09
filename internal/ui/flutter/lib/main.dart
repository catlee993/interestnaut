import 'dart:ffi' as ffi;
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:window_size/window_size.dart' as window_package;
import 'components/movies/movie_section.dart';
import 'components/tv/tv_show_section.dart';
import 'components/books/book_section.dart';
import 'components/games/game_section.dart';
import 'components/music/music_section.dart';
import 'theme.dart';
import 'services/go_bindings.dart';
import 'services/ffi_init.dart';
import 'components/common/media_header.dart';
import 'components/music/spotify_user_control.dart';

// Global navigator key for accessing the navigator from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      window_package.setWindowTitle('Interestnaut');
      Size maxSize = const Size(1920, 1080);
      Size minSize = const Size(800, 200);
      Size initialSize = const Size(1024, 768);
      window_package.setWindowMaxSize(maxSize);
      window_package.setWindowMinSize(minSize);
      window_package.setWindowFrame(
          Rect.fromLTWH(0, 0, initialSize.width, initialSize.height));
    }

    try {
      // 1. Initialize FFI to load the dylib
      await FFIInitializer.initialize();
      debugPrint(
          'Dart: FFIInitializer.initialize() complete. Dylib loaded. Status: ${FFIInitializer
              .isInitialized}');

      if (FFIInitializer.isInitialized) {
        // 2. Call the exported Go function to initialize Go-side resources
        try {
          final goInitFFIBridge =
          FFIInitializer.dylib.lookupFunction<ffi.Void Function(),
              void Function()>('InitializeFFIBridge');
          debugPrint('Dart: Calling Go InitializeFFIBridge()...');
          goInitFFIBridge();
          debugPrint('Dart: Go InitializeFFIBridge() called successfully.');
        } catch (e) {
          debugPrint(
              'Dart: ERROR looking up or calling InitializeFFIBridge: $e');
          // Handle critical error: Go FFI resources might not be set up.
          // The app might not function correctly.
        }
      } else {
        debugPrint(
            'Dart: FFIInitializer.isInitialized is false. Skipping call to InitializeFFIBridge.');
        // Handle critical error: Dylib not loaded.
      }

      // 3. Initialize GoBindings (Dart wrapper for FFI calls)
      // This should now find that FFIInitializer.isInitialized is true, 
      // and Go-side resources are also ready.
      await GoBindings.initialize();
      debugPrint('Dart: GoBindings.initialize() complete. Status: ${GoBindings
          .ffiAvailable}');

      // Verify by trying to access a function
      if (GoBindings.ffiAvailable) {
        debugPrint('Verifying FFI by looking up FreeString function...');
        final freeStringFn = FFIInitializer.dylib.lookupFunction<
            ffi.Void Function(ffi.Pointer<ffi.Char>),
            void Function(ffi.Pointer<ffi.Char>)>('FreeString');
        debugPrint('Successfully verified FreeString function exists');
      }

      // Register for app lifecycle events to signal shutdown to Go
      registerShutdownHooks();
    } catch (e) {
      debugPrint('Dart: Overall FFI setup failed: $e');
      // Continue anyway, the app will handle missing FFI gracefully
    }

  runApp(const MyApp());
}

/// Register hooks to signal to the Go app when Flutter is terminating
void registerShutdownHooks() {
  // For desktop platforms, we need to tell Go when we're shutting down
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    debugPrint('Registering shutdown hooks for Go interop');

    // Signal Go when app is being terminated
    Future.delayed(Duration.zero, () {
      WidgetsBinding.instance.addObserver(_AppLifecycleObserver());
    });

    // Register a synchronous handler for more immediate termination scenarios
    // This isn't perfect but helps in some cases
    ProcessSignal.sigterm.watch().listen((_) {
      debugPrint('SIGTERM received, signaling Go app');
      try {
        GoBindings.signalShutdown();
      } catch (e) {
        debugPrint('Error signaling Go shutdown: $e');
      }
    });
  }
}

/// Life cycle observer to detect app termination
class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('App lifecycle state changed to: $state');
    if (state == AppLifecycleState.detached) {
      debugPrint('App is detached, signaling Go app to shut down');
      try {
        GoBindings.signalShutdown();
      } catch (e) {
        debugPrint('Error signaling Go shutdown: $e');
      }
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Interestnaut',
      debugShowCheckedModeBanner: false,
      // Use our custom theme instead of the generic one
      theme: AppTheme.theme,
      home: const InterestnautApp(),
      navigatorKey: navigatorKey,
    );
  }
}

class InterestnautApp extends StatefulWidget {
  const InterestnautApp({super.key});

  @override
  State<InterestnautApp> createState() => _InterestnautAppState();
}

class _InterestnautAppState extends State<InterestnautApp> {
  String _currentMediaType = 'music';
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _ensureInitialized();
  }

  // Ensure FFI is properly initialized
  Future<void> _ensureInitialized() async {
    try {
      if (!GoBindings.ffiAvailable) {
        await FFIInitializer.initialize();
        await GoBindings.initialize();
      }

      // Now proceed with server connection check
      await _checkServerConnection();

      // And check if we're already authenticated with Spotify
      try {
        final authStatus = await GoBindings.instance.music.getAuthStatus();
        setState(() {
          _isAuthenticated = authStatus['isAuthenticated'] == true;
        });

        if (_isAuthenticated) {
          try {
            final profile = await GoBindings.instance.music.getCurrentUser();
            setState(() {
              _userProfile = profile;
            });
          } catch (e) {
            debugPrint('Failed to get user profile: $e');
          }
        }
      } catch (e) {
        debugPrint('Failed to check auth status: $e');
      }
    } catch (e) {
      debugPrint('Failed to initialize FFI: $e');
      // Continue anyway - app will handle missing FFI gracefully

      // Still check the server connection
      await _checkServerConnection();
    }
  }

  // In a production app, this would communicate with our Go backend
  Future<void> _checkServerConnection() async {
    try {
      // Native platforms
      final commsDir = Platform.environment['INTERESTNAUT_COMMS_DIR'] ??
          path.join(Directory.systemTemp.path, 'interestnaut');

      // Read the server port file
      final portFile = File(path.join(commsDir, 'server_port'));
      if (await portFile.exists()) {
        final port = await portFile.readAsString();
        print('Found server port: $port');

        // Here we would establish communication with the Go backend
        // For now, we'll just simulate being authenticated
        setState(() {
          _isAuthenticated = true;
          _userProfile = {
            'display_name': 'Demo User',
            'images': [
              {'url': ''}
            ]
          };
        });
      }
    } catch (e) {
      print('Error connecting to server: $e');
      setState(() {
        _isAuthenticated = true; // For demo purposes, always authenticate
        _userProfile = {
          'display_name': 'Demo User',
          'images': [
            {'url': ''}
          ]
        };
      });
    }
  }

  void _handleClearAuth() async {
    try {
      await GoBindings.instance.music.clearSpotifyCredentials();
      setState(() {
        _isAuthenticated = false;
        _userProfile = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Spotify credentials cleared'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error clearing auth: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear Spotify credentials: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Main app UI
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Header
          MediaHeader(
            currentMedia: _currentMediaType,
            onMediaChange: (media) {
              setState(() {
                _currentMediaType = media;
              });
            },
            onSearch: (query) {
              // TODO: Implement search per media type
            },
            onClearSearch: () {
              // TODO: Implement clear search per media type
            },
            additionalControl: _currentMediaType == 'music' && _isAuthenticated
                ? SpotifyUserControl(
                    user: _userProfile,
                    onClearAuth: _handleClearAuth,
                  )
                : null,
          ),
          // Main content area
          Expanded(
            child: Container(
              color: AppTheme.backgroundColor,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: _buildCurrentContent(),
              ),
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
        return const MovieSection();
      case 'tv':
        return const TVShowSection();
      case 'books':
        return const BookSection();
      case 'games':
        return const GameSection();
      default:
        return const MusicSection();
    }
  }
}
