import 'package:flutter/material.dart';
import '../../theme.dart';

/// Unified external media play button component
/// Used for YouTube and Spotify play buttons across the app
class ExternalMediaButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String tooltip;
  final bool glowEffect;
  final double size;

  const ExternalMediaButton({
    Key? key,
    this.icon = Icons.play_arrow,
    required this.color,
    required this.onPressed,
    required this.tooltip,
    this.glowEffect = false,
    this.size = 28,
  }) : super(key: key);

  @override
  State<ExternalMediaButton> createState() => _ExternalMediaButtonState();
}

class _ExternalMediaButtonState extends State<ExternalMediaButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          transform: isHovered
              ? (Matrix4.translationValues(0, -2, 0)..scale(1.1))
              : Matrix4.identity(),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  widget.icon,
                  color: widget.glowEffect 
                      ? (isHovered ? Colors.white : Colors.white.withOpacity(0.9))
                      : (isHovered ? widget.color : widget.color.withOpacity(0.7)),
                  size: widget.size,
                  shadows: widget.glowEffect ? [
                    Shadow(
                      color: widget.color.withOpacity(isHovered ? 0.8 : 0.5),
                      blurRadius: isHovered ? 16 : 12,
                    ),
                  ] : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// YouTube play button with consistent styling
class YouTubePlayButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double size;

  const YouTubePlayButton({
    Key? key,
    required this.onPressed,
    this.size = 28,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ExternalMediaButton(
      color: const Color(0xFF4FC3F7), // Lighter blue for YouTube
      onPressed: onPressed,
      tooltip: 'Play on YouTube',
      size: size,
    );
  }
}

/// Spotify play button with consistent styling
class SpotifyPlayButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double size;

  const SpotifyPlayButton({
    Key? key,
    required this.onPressed,
    this.size = 28,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ExternalMediaButton(
      color: AppTheme.spotifyGreen,
      onPressed: onPressed,
      tooltip: 'Play on Spotify',
      glowEffect: true,
      size: size,
    );
  }
}