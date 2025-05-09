import 'package:flutter/material.dart';
import 'search_bar.dart' as custom;
import 'settings_drawer.dart';

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
    );
  }

  PopupMenuItem _buildMenuItem(String media) {
    return PopupMenuItem(
      value: media,
      child: Text(
        _getMediaDisplayName(media),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            child: SizedBox(
              height: 46,
              child: Row(
                children: [
                  // Left section: Media selector
                  SizedBox(
                    width: 200,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        key: _menuKey,
                        onTap: _showMediaMenu,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.transparent,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _getMediaDisplayName(activeMedia),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
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
                          Text(
                            'INTERESTNAUT',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              letterSpacing: 2,
                              color: const Color(0xFFb39ddb),
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
                  // Right section: Additional controls and settings
                  SizedBox(
                    width: 200,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (widget.additionalControl != null)
                          widget.additionalControl!,
                        IconButton(
                          icon: const Icon(Icons.settings, color: Color(0xFF7b68ee)),
                          onPressed: () {
                            setState(() {
                              _showSettingsDrawer = true;
                            });
                          },
                          padding: const EdgeInsets.all(2),
                          splashRadius: 18,
                          tooltip: 'Settings',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
    );
  }
} 