import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Spotify branding component that adheres to official design guidelines
/// Uses official Spotify assets and follows brand requirements
class SpotifyBranding extends StatelessWidget {
  final SpotifyBrandingType type;
  final SpotifyBrandingSize size;
  final SpotifyBrandingColor color;
  final VoidCallback? onTap;
  final bool showAttribution;

  const SpotifyBranding({
    Key? key,
    this.type = SpotifyBrandingType.fullLogo,
    this.size = SpotifyBrandingSize.medium,
    this.color = SpotifyBrandingColor.green,
    this.onTap,
    this.showAttribution = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLogo(),
          if (showAttribution) ...[
            const SizedBox(height: 4),
            _buildAttribution(),
          ],
        ],
      ),
    );
  }

  Widget _buildLogo() {
    final assetPath = _getAssetPath();
    final logoSize = _getLogoSize();

    if (assetPath.endsWith('.svg')) {
      return SvgPicture.asset(
        assetPath,
        width: logoSize.width,
        height: logoSize.height,
        fit: BoxFit.contain,
      );
    } else {
      return Image.asset(
        assetPath,
        width: logoSize.width,
        height: logoSize.height,
        fit: BoxFit.contain,
      );
    }
  }

  Widget _buildAttribution() {
    return Text(
      'Powered by Spotify',
      style: TextStyle(
        fontSize: 10,
        color: Colors.white.withOpacity(0.6),
        fontWeight: FontWeight.w300,
      ),
    );
  }

  String _getAssetPath() {
    switch (type) {
      case SpotifyBrandingType.fullLogo:
        switch (color) {
          case SpotifyBrandingColor.green:
            return 'assets/spotify/Spotify_Full_Logo_RGB_Green.png';
          case SpotifyBrandingColor.black:
            return 'assets/spotify/Spotify_Full_Logo_RGB_Black.png';
          case SpotifyBrandingColor.white:
            return 'assets/spotify/Spotify_Full_Logo_RGB_White.png';
        }
      case SpotifyBrandingType.iconOnly:
        switch (color) {
          case SpotifyBrandingColor.green:
            return 'assets/spotify/Spotify_Primary_Logo_RGB_Green.png';
          case SpotifyBrandingColor.black:
            return 'assets/spotify/Spotify_Primary_Logo_RGB_Black.png';
          case SpotifyBrandingColor.white:
            return 'assets/spotify/Spotify_Primary_Logo_RGB_White.png';
        }
    }
  }

  Size _getLogoSize() {
    switch (size) {
      case SpotifyBrandingSize.small:
        return type == SpotifyBrandingType.fullLogo 
            ? const Size(70, 21)   // Minimum size per guidelines
            : const Size(21, 21);  // Minimum icon size
      case SpotifyBrandingSize.medium:
        return type == SpotifyBrandingType.fullLogo 
            ? const Size(120, 36)
            : const Size(36, 36);
      case SpotifyBrandingSize.large:
        return type == SpotifyBrandingType.fullLogo 
            ? const Size(200, 60)
            : const Size(60, 60);
    }
  }
}

/// Spotify button with proper branding and interestnaut styling
class SpotifyButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String? label;
  final SpotifyBrandingSize iconSize;
  final bool roundedCorners;

  const SpotifyButton({
    Key? key,
    required this.onPressed,
    this.label,
    this.iconSize = SpotifyBrandingSize.small,
    this.roundedCorners = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1ED760), // Official Spotify Green
        borderRadius: roundedCorners 
            ? BorderRadius.circular(9999) // Spotify guideline: fully rounded
            : BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF1ED760).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: roundedCorners 
              ? BorderRadius.circular(9999)
              : BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SpotifyBranding(
                  type: SpotifyBrandingType.iconOnly,
                  size: iconSize,
                  color: SpotifyBrandingColor.white,
                  showAttribution: false,
                ),
                if (label != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    label!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Spotify attribution widget for compliance
class SpotifyAttribution extends StatelessWidget {
  const SpotifyAttribution({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SpotifyBranding(
          type: SpotifyBrandingType.iconOnly,
          size: SpotifyBrandingSize.small,
          color: SpotifyBrandingColor.white,
          showAttribution: false,
        ),
        const SizedBox(width: 6),
        Text(
          'Music from Spotify',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}

enum SpotifyBrandingType {
  fullLogo,
  iconOnly,
}

enum SpotifyBrandingSize {
  small,
  medium,
  large,
}

enum SpotifyBrandingColor {
  green,
  black,
  white,
}