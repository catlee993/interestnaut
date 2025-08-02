import 'package:flutter/material.dart';
import 'dart:ui';
import '../../theme.dart';
import 'continuous_playback_switch.dart';
import 'media_refinement_panel.dart';
import 'media_blend_panel.dart';
import '../../services/sqlite_db.dart';
import '../../services/continuous_playback_service.dart';

class SettingsDrawer extends StatefulWidget {
  final String mediaType;
  final VoidCallback onClose;

  const SettingsDrawer({
    Key? key,
    required this.mediaType,
    required this.onClose,
  }) : super(key: key);

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _continuousPlayback = false;
  bool _youTubePreviews = false;
  final SQLiteDatabase _db = SQLiteDatabase();
  final ContinuousPlaybackService _continuousPlaybackService = ContinuousPlaybackService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

      // Load YouTube previews setting (all media types)
      debugPrint('📱 Loading YouTube previews setting from general_settings...');
      final youTubePreviews = await _db.getYouTubePreviewsSetting();
      debugPrint('📱 YouTube previews value: $youTubePreviews');
      setState(() {
        _youTubePreviews = youTubePreviews;
      });
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

  /// Save the YouTube previews setting to database
  Future<void> _saveYouTubePreviewsSetting(bool value) async {
    try {
      debugPrint('💾 Saving YouTube previews setting: $value');
      final success = await _db.setYouTubePreviewsSetting(value);
      debugPrint('💾 Save result: $success');
      
      setState(() {
        _youTubePreviews = value;
      });
      
      // Verify it was saved
      final savedValue = await _db.getYouTubePreviewsSetting();
      debugPrint('💾 Verification - YouTube previews after save: $savedValue');
    } catch (e) {
      debugPrint('❌ Error saving YouTube previews setting: $e');
    }
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
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: AppTheme.primaryColor.withOpacity(0.8),
                                size: 20,
                                shadows: [
                                  Shadow(
                                    color: AppTheme.primaryColor.withOpacity(0.6),
                                    offset: const Offset(0, 0),
                                    blurRadius: 1,
                                  ),
                                ],
                              ),
                              onPressed: widget.onClose,
                              style: IconButton.styleFrom(
                                padding: const EdgeInsets.all(6),
                              ),
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
                  Tab(text: 'DATABASE'),
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
                  // TODO: Replace with History tab as requested by user
                  const SizedBox.shrink(),
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
                  
                  // YouTube Previews (all media types)
                  SwitchListTile(
                    value: _youTubePreviews,
                    onChanged: _saveYouTubePreviewsSetting,
                    title: const Text(
                      'Enable YouTube previews if available',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    activeColor: const Color(0xFF7B68EE),
                    activeTrackColor: const Color(0x887B68EE),
                    inactiveThumbColor: Colors.grey[400],
                    inactiveTrackColor: Colors.grey[800],
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                  
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
void showMediaSpecificSettingsDrawer(BuildContext context, String mediaType) {
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