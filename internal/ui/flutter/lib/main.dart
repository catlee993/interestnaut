import 'dart:async';
import 'dart:io';
import 'dart:ffi' as ffi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_size/window_size.dart' as window_package;

import 'theme.dart';
import 'services/go_bindings.dart';
import 'services/ffi_init.dart';
import 'components/music/spotify_service.dart';
import 'services/secure_storage.dart';
import 'components/common/media_header.dart';
import 'components/music/spotify_user_control.dart';
import 'components/music/spotify_connect_button.dart';
import 'components/music/music_section.dart';

/// Entry point for the Flutter app
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize platform channels
  const eventBusChannel = MethodChannel('com.interestnaut.eventbus');
  
  // Set up server event streams
  try {
    final serverPort = await eventBusChannel.invokeMethod<int>('initializeEventBus');
    if (serverPort != null) {
      debugPrint('Connected to event bus on port $serverPort');
      debugPrint('Event bus initialized and all event subscriptions active');
    } else {
      debugPrint('Failed to initialize event bus: No port returned');
    }
  } catch (e) {
    debugPrint('Error initializing event bus: $e');
    // Continue without event bus
  }
  
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
      Size initialSize = const Size(1200, 800);
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
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userProfile;
  final SpotifyService _spotifyService = SpotifyService();
  String _currentMediaType = 'music'; // Default media type
  
  @override
  void initState() {
    super.initState();
    _ensureInitialized();
  }

  // Ensure FFI is properly initialized
  Future<void> _ensureInitialized() async {
    try {
      // Initialize Spotify service
      await _spotifyService.initialize();
      
      // Check if user is authenticated with Spotify
      final isAuthenticated = _spotifyService.isAuthenticated;
      
      if (isAuthenticated) {
        try {
          // Get user profile information
          final userProfile = await _spotifyService.getCurrentUser();
          
          if (userProfile != null) {
            setState(() {
              _isAuthenticated = true;
              _userProfile = userProfile;
            });
          }
        } catch (e) {
          debugPrint('Error getting user profile: $e');
        }
      }
    } catch (e) {
      debugPrint('Error initializing services: $e');
    }
  }

  void _handleClearAuth() async {
    try {
      // There's no logout method, so use SecureStorage to clear tokens
      await SecureStorage.clearSpotifyCredentials();
      setState(() {
        _isAuthenticated = false;
        _userProfile = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Spotify credentials cleared'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error clearing auth: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing credentials: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Main app UI
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Header - Always show the header regardless of media type
          MediaHeader(
            currentMedia: _currentMediaType,
            onMediaChange: (media) {
              setState(() {
                _currentMediaType = media;
                
                // Update the content based on the selected media type
                _buildCurrentContent();
              });
            },
            onSearch: (query) {
              // TODO: Implement search per media type
            },
            onClearSearch: () {
              // TODO: Implement clear search per media type
            },
            // Only show Spotify controls in music section
            additionalControl: _currentMediaType == 'music' 
                ? (_isAuthenticated 
                  ? SpotifyUserControl(
                      user: _userProfile,
                      onClearAuth: _handleClearAuth,
                    )
                  : SpotifyConnectButton(
                      onConnect: () async {
                        try {
                          // authenticate requires BuildContext
                          final success = await _spotifyService.authenticate(context);
                          
                          if (success) {
                            final profile = await _spotifyService.getCurrentUser();
                            setState(() {
                              _isAuthenticated = true;
                              _userProfile = profile;
                            });
                            
                            if (mounted) {
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Connected to Spotify'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          } else {
                            if (mounted) {
                              final scaffoldMessenger = ScaffoldMessenger.of(context);
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to connect to Spotify'),
                                  duration: Duration(seconds: 5),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          debugPrint('Error initiating Spotify auth: $e');
                          if (mounted) {
                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed to connect to Spotify: $e'),
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        }
                      },
                    ))
                : null,
          ),
          
          // Main content area
          Expanded(
            child: Container(
              color: AppTheme.backgroundColor,
              child: _buildCurrentContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentContent() {
    switch (_currentMediaType) {
      case 'music':
        return MusicSection(
          onAuthStatusChanged: (isAuthenticated, userProfile) {
            if (mounted) {
              setState(() {
                _isAuthenticated = isAuthenticated;
                if (userProfile != null) {
                  _userProfile = userProfile;
                } else if (isAuthenticated) {
                  // Provide a minimal profile if authenticated but no profile data
                  _userProfile = {
                    'display_name': 'Spotify User',
                    'images': []
                  };
                }
              });
            }
          },
        );
      case 'movies':
        return const Center(child: Text('Movies Section', style: TextStyle(color: Colors.white)));
      case 'tv':
        return const Center(child: Text('TV Shows Section', style: TextStyle(color: Colors.white)));
      case 'home':
      default:
        return const Center(child: Text('Home Section', style: TextStyle(color: Colors.white)));
    }
  }
}
