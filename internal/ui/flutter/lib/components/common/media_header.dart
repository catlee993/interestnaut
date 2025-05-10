import 'package:flutter/material.dart';
import 'dart:ui';
import 'search_bar.dart' as custom;
import 'settings_drawer.dart';
import '../../theme.dart';

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
  bool _showSettingsDrawer = false;

  @override
  void initState() {
    super.initState();
    activeMedia = widget.currentMedia;
    _menuKey = GlobalKey();
  }

  void _handleMediaChange(String media) {
    setState(() {
      activeMedia = media;
    });
    widget.onMediaChange?.call(media);
    Navigator.of(context).pop();
  }

  String _getMediaDisplayName(String mediaType) {
    switch (mediaType) {
      case 'music':
        return 'MUSIC';
      case 'movies':
        return 'MOVIES';
      case 'tv':
        return 'TV SHOWS';
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
      color: const Color.fromRGBO(18, 18, 18, 0.95),
      items: [
        _buildMenuItem('music'),
        _buildMenuItem('movies'),
        _buildMenuItem('tv'),
        _buildMenuItem('games'),
        _buildMenuItem('books'),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: Color.fromRGBO(255, 255, 255, 0.1)),
      ),
      elevation: 8,
    );
  }

  PopupMenuItem _buildMenuItem(String media) {
    final bool isSelected = activeMedia == media;
    final String displayText = {
      'music': 'MUSIC',
      'movies': 'MOVIES',
      'tv': 'TV SHOWS',
      'games': 'GAMES',
      'books': 'BOOKS',
    }[media] ?? 'MEDIA';

    return PopupMenuItem(
      value: media,
      height: 38,
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w300,
        letterSpacing: 1.2,
        fontFamily: 'Inter',
      ),
      child: Transform(
        transform: Matrix4.identity()..scale(1.1, 1.0),
        alignment: Alignment.centerLeft,
        child: Text(
          displayText,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w400 : FontWeight.w300,
            letterSpacing: 1.2,
            fontFamily: 'Inter',
          ),
        ),
      ),
      onTap: () => _handleMediaChange(media),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color.fromRGBO(18, 18, 18, 0.95),
      elevation: 0,
      child: Container(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              child: SizedBox(
                height: 46,
                child: Row(
                  children: [
                    // Left section: Media selector with fixed width
                    SizedBox(
                      width: 200,
                      child: Align(
                        alignment: Alignment.centerLeft,
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
                                Transform(
                                  transform: Matrix4.identity()..scale(1.1, 1.0),
                                  alignment: Alignment.center,
                                  child: Text(
                                    _getMediaDisplayName(activeMedia),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w300,
                                      letterSpacing: 1.2,
                                      fontFamily: 'Inter',
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Center section: Logo
                    Expanded(
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Gradient text for interestnaut
                            ShaderMask(
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
                                  letterSpacing: 1.5,
                                  fontFamily: 'Inter',
                                  color: Colors.white,
                                  height: 1.0,
                                  textBaseline: TextBaseline.alphabetic,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
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
                    // Right section: Additional controls and settings with fixed width
                    SizedBox(
                      width: 200,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (widget.additionalControl != null) 
                            Flexible(
                              child: widget.additionalControl!,
                            ),
                          IconButton(
                            icon: const Icon(Icons.settings, color: Color(0xFF7b68ee), size: 20),
                            onPressed: () {
                              setState(() {
                                _showSettingsDrawer = true;
                              });
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const SizedBox(width: 40), // Fixed left margin
                  Expanded(
                    child: custom.SearchBar(
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.0,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  const SizedBox(width: 40), // Fixed right margin - matches left
                ],
              ),
            ),
            SettingsDrawer(
              open: _showSettingsDrawer,
              onClose: () {
                setState(() {
                  _showSettingsDrawer = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}