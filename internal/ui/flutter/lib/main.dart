import 'dart:async';
import 'dart:io';
import 'dart:ffi' as ffi;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart' as window_package;
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:path/path.dart' as path;

import 'theme.dart';
import 'services/go_bindings.dart';
import 'services/ffi_init.dart';
import 'components/common/media_header.dart';
import 'components/music/spotify_user_control.dart';
import 'components/music/spotify_connect_button.dart';
import 'components/music/music_section.dart';
import 'services/event_bus.dart';

/// Entry point for the Flutter app
void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the FFI - must happen before anything else
  try {
    await FFIInitializer.initialize();
    debugPrint('FFI initialized successfully');
    
    // Initialize the event bus (don't await - it should connect in background)
    EventBus.initialize().catchError((e) {
      debugPrint('Error initializing event bus (non-fatal): $e');
    });
  } catch (e) {
    debugPrint('Error initializing FFI: $e');
    // Continue anyway, the app will handle missing FFI gracefully
  }

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
  } catch (e) {
    debugPrint('Dart: Overall FFI setup failed: $e');
    // Continue anyway, the app will handle missing FFI gracefully
  }

  // 3. Initialize GoBindings (Dart wrapper for FFI calls)
  // This should now find that FFIInitializer.isInitialized is true, 
  // and Go-side resources are also ready.
  await GoBindings.initialize();
  debugPrint('Dart: GoBindings.initialize() complete. Status: ${GoBindings
      .ffiAvailable}');

  // Verify by looking up a function without storing the reference
  if (GoBindings.ffiAvailable) {
    debugPrint('Verifying FFI by looking up FreeString function...');
    FFIInitializer.dylib.lookupFunction<
        ffi.Void Function(ffi.Pointer<ffi.Char>),
        void Function(ffi.Pointer<ffi.Char>)>('FreeString');
    debugPrint('Successfully verified FreeString function exists');
  }

  // Register for app lifecycle events to signal shutdown to Go
  registerShutdownHooks();

  runApp(const MyApp());
}

/// Register hooks to signal Go app to shut down
void registerShutdownHooks() {
  debugPrint('Registering shutdown hooks for Go interop');

  // Catch SIGTERM on macOS/Linux
  if (Platform.isLinux || Platform.isMacOS) {
    ProcessSignal.sigterm.watch().listen((_) {
      debugPrint('SIGTERM received, signaling Go app');
      try {
        GoBindings.signalShutdown();
      } catch (e) {
        debugPrint('Error signaling Go shutdown: $e');
      }
    });
  }
  // Handle app lifecycle events
  final binding = WidgetsBinding.instance;
  binding.addObserver(_AppLifecycleObserver());
}

/// Observer for app lifecycle events
class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    _initEventBus();
  }

  // Ensure FFI is properly initialized
  Future<void> _ensureInitialized() async {
    try {
      // Now proceed with server connection check
      await _checkServerConnection();

      // And check if we're already authenticated with Spotify
      try {
        final musicService = GoBindings.instance.music;
        final authStatus = await musicService.getAuthStatus();
        
        // Only update state if we got a valid response
        if (authStatus != null && authStatus.containsKey('isAuthenticated')) {
          setState(() {
            _isAuthenticated = authStatus['isAuthenticated'] == true;
          });

          if (_isAuthenticated) {
            try {
              final profile = await musicService.getCurrentUser();
              if (profile != null) {
                setState(() {
                  _userProfile = profile;
                });
              } else {
                debugPrint('User profile is null even though authentication succeeded');
              }
            } catch (e) {
              debugPrint('Failed to get user profile: $e');
              // Set default profile if we can't get the actual profile
              setState(() {
                _userProfile = {
                  'display_name': 'Spotify User',
                  'images': []
                };
              });
            }
          }
        } else {
          debugPrint('Invalid auth status response: $authStatus');
        }
      } catch (e) {
        debugPrint('Failed to check auth status: $e');
      }
    } catch (e) {
      debugPrint('Error during initialization: $e');
    }
  }

  // Initialize the event bus and listen for authentication events
  Future<void> _initEventBus() async {
    try {
      // Initialize the event bus
      await EventBus.initialize();
      
      // Listen for authentication status changes
      EventBus().authEvents.listen((event) {
        debugPrint('Received auth event: $event');
        final payload = event;

        // Handle auth status changes
        if (payload.containsKey('isAuthenticated')) {
          setState(() {
            _isAuthenticated = payload['isAuthenticated'] == true;
            // If userProfile is present, update it
            if (payload.containsKey('userProfile')) {
              _userProfile = payload['userProfile'] as Map<String, dynamic>?;
            } else if (!_isAuthenticated) {
              _userProfile = null;
            }
          });
        }
      });
      
      // Listen for user profile updates
      EventBus().profileEvents.listen((event) {
        debugPrint('Received profile event: $event');
        
        // Handle user profile updates
        if (event.containsKey('userProfile')) {
          setState(() {
            _userProfile = event['userProfile'] as Map<String, dynamic>?;
            // Ensure we mark as authenticated when we get a profile
            if (_userProfile != null && !_userProfile!.isEmpty) {
              _isAuthenticated = true;
            }
          });
          debugPrint('Updated user profile: $_userProfile');
        }
      });
      
      debugPrint('Event bus initialized and all event subscriptions active');
    } catch (e) {
      debugPrint('Failed to initialize event bus: $e');
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
        debugPrint('Found server port: $port');
        
        // Don't override authentication state if FFI is properly initialized
        // as it will be handled by _ensureInitialized
        if (!FFIInitializer.isInitialized) {
          debugPrint('FFI not initialized, using mock authentication');
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
      }
    } catch (e) {
      debugPrint('Error connecting to server: $e');
      // Only set mock authentication if FFI isn't initialized
      if (!FFIInitializer.isInitialized) {
        debugPrint('Using mock authentication due to server connection error');
        setState(() {
          _isAuthenticated = true; // For demo purposes only
          _userProfile = {
            'display_name': 'Demo User',
            'images': [
              {'url': ''}
            ]
          };
        });
      }
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
            additionalControl: _currentMediaType == 'music' 
                ? (_isAuthenticated 
                  ? SpotifyUserControl(
                      user: _userProfile,
                      onClearAuth: _handleClearAuth,
                    )
                  : SpotifyConnectButton(
                      onConnect: () async {
                        try {
                          // With the event bus, we only need to initiate auth
                          // State updates will come through the event bus
                          await GoBindings.instance.music.initiateSpotifyAuth();
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Spotify authentication initiated'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        } catch (e) {
                          debugPrint('Error initiating Spotify auth: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to connect to Spotify: $e'),
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        }
                      },
                    ))
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
        return MusicSection(
          onAuthStatusChanged: (isAuthenticated, userProfile) {
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
          },
        );
      case 'movies':
        return const Text('Movies');
      case 'tv':
        return const Text('TV Shows');
      case 'books':
        return const Text('Books');
      case 'games':
        return const Text('Games');
      default:
        return const Text('Unknown media type');
    }
  }
}
