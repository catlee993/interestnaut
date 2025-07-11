import 'package:flutter/material.dart';
import 'dart:ui';
import '../../theme.dart';
import 'continuous_playback_switch.dart';
import 'media_refinement_panel.dart';
import 'media_blend_panel.dart';
import 'database_management_panel.dart';

class MediaSpecificSettingsDrawer extends StatefulWidget {
  final String mediaType;
  final VoidCallback onClose;

  const MediaSpecificSettingsDrawer({
    Key? key,
    required this.mediaType,
    required this.onClose,
  }) : super(key: key);

  @override
  State<MediaSpecificSettingsDrawer> createState() => _MediaSpecificSettingsDrawerState();
}

class _MediaSpecificSettingsDrawerState extends State<MediaSpecificSettingsDrawer> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _continuousPlayback = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                  
                  // Database Panel
                  DatabaseManagementPanel(mediaType: widget.mediaType),
                ],
              ),
            ),

            // Bottom section with continuous playback (music only)
            if (widget.mediaType == 'music') ...[
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
                      'PLAYBACK',
                      style: TextStyle(
                        color: AppTheme.primaryColor.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ContinuousPlaybackSwitch(
                      value: _continuousPlayback,
                      onChanged: (value) => setState(() => _continuousPlayback = value),
                    ),
                  ],
                ),
              ),
            ],
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
          child: MediaSpecificSettingsDrawer(
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