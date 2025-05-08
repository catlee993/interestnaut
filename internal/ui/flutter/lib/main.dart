import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'components/movies/movie_section.dart';
import 'components/tv/tv_show_section.dart';
import 'components/books/book_section.dart';
import 'components/games/game_section.dart';
import 'components/audiobooks/audiobook_section.dart';
import 'theme.dart'; // Import our new theme

// Flag to check if we're running on web
bool get isWeb => kIsWeb;

void main() {
  runApp(const MyApp());
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
        return _buildMusicSection();
      case 'movies':
        return const MovieSection();
      case 'tv':
        return const TVShowSection();
      case 'books':
        return const BookSection();
      case 'games':
        return const GameSection();
      default:
        return _buildMusicSection();
    }
  }

  Widget _buildMusicSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Suggestions section
        _buildSuggestionSection(),
        const SizedBox(height: 24),
        // Library section
        _buildLibrarySection(),
      ],
    );
  }

  Widget _buildSuggestionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 16),
          child: Text(
            'Suggested for You',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                offset: const Offset(0, 2),
                blurRadius: 6,
                spreadRadius: 0,
              ),
            ],
            border: Border.all(
              color: const Color(0xFF323232),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.music_note, size: 56, color: AppTheme.primaryColor),
              const SizedBox(height: 24),
              Text(
                'No suggestion currently. Click below to get one.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Here we would request a suggestion
                  print('Requesting suggestion...');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Get a Suggestion'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLibrarySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 36, bottom: 16),
          child: Text(
            'Your Library',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                offset: const Offset(0, 2),
                blurRadius: 6,
                spreadRadius: 0,
              ),
            ],
            border: Border.all(
              color: const Color(0xFF323232),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 48) / 3;
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: List.generate(3, (index) => SizedBox(
                  width: cardWidth,
                  height: 240,
                  child: _buildTrackCard(
                    'Track ${index + 1}',
                    'Artist ${index + 1}',
                    'https://i.scdn.co/image/ab67616d0000b273ea7caaff71dea1051d49b2fe',
                  ),
                )),
              );
            }
          ),
        ),
      ],
    );
  }

  Widget _buildTrackCard(String title, String artist, String imageUrl) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(
          color: const Color(0xFF424242),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Album art
          Positioned.fill(
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppTheme.cardBackgroundColor,
                  child: const Center(
                    child: Icon(Icons.music_note, size: 48, color: Colors.white54),
                  ),
                );
              },
            ),
          ),
          // Gradient overlay for text visibility
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.9),
                  ],
                  stops: const [0.6, 0.8, 1.0],
                ),
              ),
            ),
          ),
          // Text at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    artist,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          // Play button overlay
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Play the track
                print('Playing $title by $artist');
              },
              highlightColor: Colors.transparent,
              splashColor: AppTheme.primaryColor.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNowPlayingBar() {
    return Container(
      color: AppTheme.surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Album art
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              'https://i.scdn.co/image/ab67616d0000b273ea7caaff71dea1051d49b2fe',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 48,
                  height: 48,
                  color: AppTheme.cardBackgroundColor,
                  child: const Icon(Icons.music_note),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          // Track info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Current Track Title',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Artist Name',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          // Play/pause button
          IconButton(
            icon: const Icon(Icons.pause),
            onPressed: () {
              // Toggle play/pause
              print('Toggle play/pause');
            },
            color: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}
