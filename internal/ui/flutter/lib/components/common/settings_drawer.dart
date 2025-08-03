import 'package:flutter/material.dart';
import 'dart:ui';
import '../../theme.dart';
import 'continuous_playback_switch.dart';
import 'media_refinement_panel.dart';
import 'media_blend_panel.dart';
import '../../services/sqlite_db.dart';
import '../../services/continuous_playback_service.dart';
import 'media_history_screen.dart';
import 'standard_close_button.dart';
import 'spotify_branding.dart';

class SettingsDrawer extends StatefulWidget {
  final String mediaType;
  final VoidCallback onClose;
  final bool? spotifySearchEnabled;
  final ValueChanged<bool>? onSpotifySearchToggle;

  const SettingsDrawer({
    Key? key,
    required this.mediaType,
    required this.onClose,
    this.spotifySearchEnabled,
    this.onSpotifySearchToggle,
  }) : super(key: key);

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _continuousPlayback = false;
  bool _spotifySearchEnabled = false;
  final SQLiteDatabase _db = SQLiteDatabase();
  final ContinuousPlaybackService _continuousPlaybackService = ContinuousPlaybackService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _spotifySearchEnabled = widget.spotifySearchEnabled ?? false;
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Load all settings from database
  Future<void> _loadSettings() async {
    try {
      // Load continuous playback setting (music only)
      if (widget.mediaType == 'music') {
        debugPrint('📱 Loading continuous playback setting from general_settings...');
        final continuousPlayback = await _db.getContinuousPlaybackSetting();
        debugPrint('📱 Continuous playback value: $continuousPlayback');
        setState(() {
          _continuousPlayback = continuousPlayback;
        });
      }

      // Spotify search is managed by parent widget state
      // YouTube previews are always enabled now
    } catch (e) {
      debugPrint('❌ Error loading settings: $e');
    }
  }

  /// Save the continuous playback setting to database and update service
  Future<void> _saveContinuousPlaybackSetting(bool value) async {
    try {
      debugPrint('💾 Saving continuous playback setting: $value');
      final success = await _db.setContinuousPlaybackSetting(value);
      debugPrint('💾 Save result: $success');
      
      // Activate continuous playback service
      await _continuousPlaybackService.setEnabled(value);
      
      setState(() {
        _continuousPlayback = value;
      });
      
      // Verify it was saved
      final savedValue = await _db.getContinuousPlaybackSetting();
      debugPrint('💾 Verification - Continuous playback after save: $savedValue');
    } catch (e) {
      debugPrint('❌ Error saving continuous playback setting: $e');
    }
  }

  /// Toggle Spotify search setting
  void _toggleSpotifySearch(bool value) {
    setState(() {
      _spotifySearchEnabled = value;
    });
    widget.onSpotifySearchToggle?.call(value);
  }

  String get _mediaDisplayName {
    switch (widget.mediaType) {
      case 'music': return 'Music';
      case 'movies': return 'Movies';
      case 'tv': return 'TV Shows';
      case 'books': return 'Books';
      case 'games': return 'Games';
      default: return 'Media';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A), // Deeper black for modern look
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomLeft: Radius.circular(8),
          ),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(-4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with frosted glass effect
            Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                ),
              ),
                              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and close button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Transform(
                                  transform: Matrix4.identity()..scale(1.15, 1.0),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _mediaDisplayName.toUpperCase(),
                                    style: AppTheme.settingsMediaHeaderStyle,
                                  ),
                                ),
                                Text(
                                  'Settings',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor.withOpacity(0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                            StandardCloseButton(
                              onPressed: widget.onClose,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Tab bar with modern styling
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.6),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
                tabs: const [
                  Tab(text: 'REFINE'),
                  Tab(text: 'BLEND'),
                  Tab(text: 'HISTORY'),
                ],
              ),
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Refinement Panel
                  MediaRefinementPanel(mediaType: widget.mediaType),
                  
                  // Blend Panel
                  MediaBlendPanel(currentMediaType: widget.mediaType),
                  
                  // History Panel (replaces Database Panel)
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: MediaHistoryScreen(
                      initialMediaType: widget.mediaType,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom section with general settings
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GENERAL',
                    style: TextStyle(
                      color: AppTheme.primaryColor.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Spotify Search (music only)
                  if (widget.mediaType == 'music') ...[
                    Row(
                      children: [
                        Switch(
                          value: _spotifySearchEnabled,
                          onChanged: _toggleSpotifySearch,
                          activeColor: const Color(0xFF1ED760), // Spotify green
                          activeTrackColor: const Color(0x881ED760),
                          inactiveThumbColor: Colors.grey[400],
                          inactiveTrackColor: Colors.grey[800],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Row(
                            children: [
                              if (_spotifySearchEnabled) ...[
                                SpotifyBranding(
                                  type: SpotifyBrandingType.iconOnly,
                                  size: SpotifyBrandingSize.small,
                                  color: SpotifyBrandingColor.green,
                                  showAttribution: false,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Use Spotify search',
                                  style: TextStyle(color: Color(0xFF1ED760), fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ] else ...[
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFFC165DD), Color(0xFF9880FF)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'I',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Use Interestnaut search',
                                  style: TextStyle(color: Color(0xFF7B68EE), fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Continuous Playback (music only)
                  if (widget.mediaType == 'music') ...[
                    const SizedBox(height: 8),
                    ContinuousPlaybackSwitch(
                      value: _continuousPlayback,
                      onChanged: _saveContinuousPlaybackSetting,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the media-specific settings drawer as an overlay
void showMediaSpecificSettingsDrawer(
  BuildContext context, 
  String mediaType, {
  bool? spotifySearchEnabled,
  ValueChanged<bool>? onSpotifySearchToggle,
}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.3),
      pageBuilder: (context, _, __) {
        return Align(
          alignment: Alignment.centerRight,
          child: SettingsDrawer(
            mediaType: mediaType,
            spotifySearchEnabled: spotifySearchEnabled,
            onSpotifySearchToggle: onSpotifySearchToggle,
            onClose: () => Navigator.of(context).pop(),
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
    ),
  );
} 