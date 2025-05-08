import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:window_size/window_size.dart' as window_package;
import 'components/movies/movie_section.dart';
import 'components/tv/tv_show_section.dart';
import 'components/books/book_section.dart';
import 'components/games/game_section.dart';
import 'components/audiobooks/audiobook_section.dart';
import 'components/music/music_section.dart';
import 'services/backend_service.dart';
import 'theme.dart'; // Import our new theme
import 'services/go_bindings.dart';
import 'services/ffi_init.dart';

// Flag to check if we're running on web
bool get isWeb => kIsWeb;

// Global navigator key for accessing the navigator from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set window size to match the legacy app (1024x768)
  if (!isWeb) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      window_package.setWindowTitle('Interestnaut');
      Size minSize = const Size(1024, 768);
      Size maxSize = const Size(1920, 1080);
      Size initialSize = const Size(1024, 768);
      window_package.setWindowMinSize(minSize);
      window_package.setWindowMaxSize(maxSize);
      window_package.setWindowFrame(Rect.fromLTWH(0, 0, initialSize.width, initialSize.height));
    }
  }
  
  // Initialize FFI and fail fast if it doesn't work
  if (!isWeb) {
    try {
      await FFIInitializer.initialize();
      debugPrint('FFI initialized successfully');
      GoBindings.initialize();
      
      // Register for app lifecycle events to signal shutdown to Go
      registerShutdownHooks();
    } catch (e) {
      // Log the error and exit
      debugPrint('FATAL ERROR: FFI initialization failed');
      debugPrint('$e');
      exit(1);
    }
  }
  
  runApp(const MyApp());
}

/// Register hooks to signal to the Go app when Flutter is terminating
void registerShutdownHooks() {
  // For desktop platforms, we need to tell Go when we're shutting down
  if (!isWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
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
    _checkServerConnection();
  }

  // In a production app, this would communicate with our Go backend
  Future<void> _checkServerConnection() async {
    try {
      // Web doesn't have access to Platform.environment
      if (isWeb) {
        print('Running on web, simulating auth...');
        // For web, we'll just simulate being authenticated
        setState(() {
          _isAuthenticated = true;
          _userProfile = {
            'display_name': 'Web User',
            'images': [
              {'url': ''}
            ]
          };
        });
        return;
      }
      
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            color: AppTheme.backgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // Top row with user info and auth
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (_isAuthenticated && _userProfile != null)
                      _buildUserControl(_userProfile!)
                    else
                      TextButton(
                        onPressed: () {
                          // Here we would connect to Spotify
                          print('Connecting to Spotify...');
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: const Text('Connect to Spotify'),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                // App title
                Text(
                  'INTERESTNAUT',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 36, // Increased to match MUI
                    color: AppTheme.primaryColor,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Media selector
                _buildMediaSelector(),
              ],
            ),
          ),
          
          // Content area with media section
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

  Widget _buildUserControl(Map<String, dynamic> user) {
    final displayName = user['display_name'] ?? 'Spotify User';
    final hasAvatar = user['images'] != null && 
        user['images'].isNotEmpty && 
        user['images'][0]['url'] != null && 
        user['images'][0]['url'].isNotEmpty;
    
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Logged in as',
              style: TextStyle(
                color: AppTheme.spotifyGreen,
                fontSize: 10,
              ),
            ),
            Text(
              displayName,
              style: TextStyle(
                color: AppTheme.spotifyGreen,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 12,
          backgroundColor: hasAvatar ? null : AppTheme.spotifyGreen,
          backgroundImage: hasAvatar 
              ? NetworkImage(user['images'][0]['url'])
              : null,
          child: hasAvatar 
              ? null 
              : Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: () {
            // Here we would clear auth
            print('Clearing auth...');
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.purpleRed,
            side: BorderSide(color: AppTheme.purpleRed),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            minimumSize: const Size(70, 20),
            textStyle: const TextStyle(fontSize: 10),
          ),
          child: const Text('Clear Auth'),
        ),
      ],
    );
  }

  Widget _buildMediaSelector() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF1E1E1E),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _mediaTypeButton('Music', 'music'),
          _mediaTypeButton('Movies', 'movies'),
          _mediaTypeButton('TV Shows', 'tv'),
          _mediaTypeButton('Books', 'books'),
          _mediaTypeButton('Games', 'games'),
        ],
      ),
    );
  }

  Widget _mediaTypeButton(String label, String mediaType) {
    final isSelected = _currentMediaType == mediaType;
    
    return InkWell(
      onTap: () {
        setState(() {
          _currentMediaType = mediaType;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
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
