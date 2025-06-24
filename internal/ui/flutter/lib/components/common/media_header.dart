import 'package:flutter/material.dart';
import 'dart:ui';
import 'search_bar.dart' as custom;
import 'settings_drawer.dart';
import '../music/spotify_service.dart';
import '../music/spotify_connect_button.dart';
import '../music/spotify_user_control.dart';

class MediaHeader extends StatefulWidget {
  final Widget? additionalControl;
  final void Function(String) onSearch;
  final VoidCallback? onClearSearch;
  final String currentMedia;
  final void Function(String)? onMediaChange;

  const MediaHeader({
    Key? key,
    this.additionalControl,
    required this.onSearch,
    this.onClearSearch,
    this.currentMedia = 'music',
    this.onMediaChange,
  }) : super(key: key);

  @override
  State<MediaHeader> createState() => _MediaHeaderState();
}

class _MediaHeaderState extends State<MediaHeader> {
  late String activeMedia;
  late GlobalKey _menuKey;
  final bool _showSettingsDrawer = false;
  
  // Add Spotify-related state
  final SpotifyService _spotifyService = SpotifyService();
  bool _isAuthenticated = false;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    activeMedia = widget.currentMedia;
    _menuKey = GlobalKey();
    
    // Initialize Spotify service
    _initializeSpotify();
    
    // Listen for auth status changes
    _spotifyService.onAuthStatusChange.listen((event) {
      if (mounted) {
        setState(() {
          _isAuthenticated = event.isAuthenticated;
        });
        
        // Fetch user profile if authenticated
        if (event.isAuthenticated) {
          _spotifyService.getCurrentUser().then((profile) {
            if (mounted && profile != null) {
              setState(() {
                _userProfile = profile;
              });
            }
          });
        } else {
          setState(() {
            _userProfile = null;
          });
        }
      }
    });
    
    // Listen for user profile updates
    _spotifyService.onUserProfileChange.listen((event) {
      if (mounted) {
        setState(() {
          _userProfile = {
            'id': event.id,
            'display_name': event.displayName,
            'images': [{'url': event.imageUrl}]
          };
        });
      }
    });
  }
  
  Future<void> _initializeSpotify() async {
    await _spotifyService.initialize();
    
    // Check initial authentication state
    final isAuthenticated = await _spotifyService.checkAuthentication();
    
    if (mounted) {
      setState(() {
        _isAuthenticated = isAuthenticated;
      });
      
      // If authenticated, fetch user profile
      if (isAuthenticated) {
        final profile = await _spotifyService.getCurrentUser();
        if (profile != null) {
          setState(() {
            _userProfile = profile;
          });
        }
      }
    }
  }
  
  void _handleClearAuth() async {
    try {
      await _spotifyService.logout();
      // Auth state will be updated via the event listener
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

  void _handleMediaChange(String media) {
    setState(() {
      activeMedia = media;
    });
    widget.onMediaChange?.call(media);
  }

  String _getMediaDisplayName(String mediaType) {
    switch (mediaType) {
      case 'music':
        return 'MUSIC';
      case 'movies':
        return 'MOVIES';
      case 'tv':
        return 'SHOWS';
      case 'games':
        return 'GAMES';
      case 'books':
        return 'BOOKS';
      default:
        return 'MEDIA';
    }
  }

  void _showMediaMenu() {
    final RenderBox button = _menuKey.currentContext!.findRenderObject() as RenderBox;
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset position = button.localToGlobal(Offset.zero, ancestor: overlay);
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + button.size.height,
        position.dx + button.size.width,
        position.dy,
      ),
      color: const Color.fromRGBO(18, 18, 18, 0.92),
      items: [
        _buildMenuItem('music'),
        _buildMenuItem('movies'),
        _buildMenuItem('tv'),
        _buildMenuItem('games'),
        _buildMenuItem('books'),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color.fromRGBO(255, 255, 255, 0.15)),
      ),
      elevation: 12,
    );
  }

  PopupMenuItem _buildMenuItem(String media) {
    final bool isSelected = activeMedia == media;
    final String displayText = {
      'music': 'MUSIC',
      'movies': 'MOVIES',
      'tv': 'SHOWS',
      'games': 'GAMES',
      'books': 'BOOKS',
    }[media] ?? 'MEDIA';

    return PopupMenuItem(
      value: media,
      height: 42,
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w100,
        letterSpacing: 1.5,
        fontFamily: 'Inter',
      ),
      child: SizedBox(
        width: 80, // Reduced width for shorter "SHOWS" text
        child: Transform(
          transform: Matrix4.identity()..scale(1.3, 1.0),
          alignment: Alignment.centerLeft,
          child: Text(
            displayText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w200 : FontWeight.w100,
              letterSpacing: 1.5,
              fontFamily: 'Inter',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      onTap: () => _handleMediaChange(media),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 600, // Minimum width to prevent component overlap
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: const BoxDecoration(
              color: Color.fromRGBO(18, 18, 18, 0.92),
            ),
            child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0), // Match search bar padding
                child: SizedBox(
                  height: 46,
                  child: Stack(
                    children: [
                      // Absolutely centered logo - unaffected by left/right content
                      Positioned.fill(
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Gradient text for interestnaut
                              Transform(
                                transform: Matrix4.identity()..scale(1.2, 1.0),
                                alignment: Alignment.center,
                                child: ShaderMask(
                                  shaderCallback: (Rect bounds) {
                                    return const LinearGradient(
                                      colors: [Color(0xFFC165DD), Color(0xFF9880FF)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      stops: [0.3, 0.9],
                                    ).createShader(bounds);
                                  },
                                  child: const Text(
                                    'INTERESTNAUT',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w100,
                                      fontSize: 14,
                                      letterSpacing: 1.8,
                                      fontFamily: 'Inter',
                                      color: Colors.white,
                                      height: 1.0,
                                      textBaseline: TextBaseline.alphabetic,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10), // More space between text and icon
                              Container(
                                height: 28,
                                width: 28,
                                margin: const EdgeInsets.only(bottom: 4),
                                child: Image.asset(
                                  'assets/images/logo/interestnaut-mascot.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Left section: Media selector
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: SizedBox(
                          width: 110, // Optimized for "SHOWS" instead of "TV SHOWS"
                          child: GestureDetector(
                            key: _menuKey,
                            onTap: _showMediaMenu,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.transparent,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Use Flexible to allow text to take only the space it needs
                                  Flexible(
                                    fit: FlexFit.loose,
                                    child: Transform(
                                      transform: Matrix4.identity()..scale(1.3, 1.0),
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _getMediaDisplayName(activeMedia),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w100,
                                          letterSpacing: 1.5,
                                          fontFamily: 'Inter',
                                          height: 1.1,
                                        ),
                                        softWrap: false, // Prevent text wrapping
                                        overflow: TextOverflow.visible, // Allow text to extend if needed
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16), // Extra spacing to account for 1.3x horizontal text scale
                                  const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Right section: Settings button anchored to right edge
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Show Spotify-specific controls when in music section
                            if (activeMedia == 'music')
                              _isAuthenticated 
                                ? SpotifyUserControl(
                                    user: _userProfile,
                                    onClearAuth: _handleClearAuth,
                                  )
                                : SpotifyConnectButton(
                                    onConnect: () async {
                                      try {
                                        await _spotifyService.authenticate(context);
                                        // No need to manually update state - we're listening to the event stream
                                      } catch (e) {
                                        debugPrint('Error initiating Spotify auth: $e');
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Failed to connect to Spotify: $e'),
                                              duration: const Duration(seconds: 5),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                            // Keep any non-Spotify additional controls that might be provided
                            if (widget.additionalControl != null && activeMedia != 'music')
                              widget.additionalControl!,
                            // Add spacing between controls and settings
                            if (activeMedia == 'music' || widget.additionalControl != null)
                              const SizedBox(width: 12),
                            // Settings button - always anchored to the right
                            IconButton(
                              icon: const Icon(Icons.settings, color: Color(0xFF7b68ee), size: 20),
                              onPressed: () {
                                // Use the showSettingsDrawer function to display drawer as overlay
                                showSettingsDrawer(context);
                              },
                              padding: const EdgeInsets.all(2),
                              splashRadius: 18,
                              tooltip: 'Settings',
                              style: IconButton.styleFrom(
                                hoverColor: const Color.fromRGBO(123, 104, 238, 0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Add a custom search bar in the header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24.0), // Even more padding to make search bar narrower
                child: custom.SearchBar(
                  key: ValueKey('SearchBar_$activeMedia'), // Unique key for each media type
                  placeholder: activeMedia == 'music'
                      ? 'Search tracks...'
                      : activeMedia == 'movies'
                          ? 'Search movies...'
                          : activeMedia == 'tv'
                              ? 'Search TV shows...'
                              : activeMedia == 'books'
                                  ? 'Search books...'
                                  : 'Search games...',
                  onSearch: widget.onSearch,
                  onClear: widget.onClearSearch,
                  initialValue: '',  // Add this parameter to match the updated SearchBar API
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 1.0,
                    fontFamily: 'Inter',
                  ),
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