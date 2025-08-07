import 'package:flutter/material.dart';
import '../../theme.dart';

/// A small button for the header to connect to Spotify
class SpotifyConnectButton extends StatelessWidget {
  final VoidCallback onConnect;

  const SpotifyConnectButton({
    Key? key,
    required this.onConnect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onConnect,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFFA855F7), // Exact same purple as pagination buttons
        side: const BorderSide(color: Color(0xFFA855F7)), // Exact same border color
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Same padding as pagination
        minimumSize: const Size(10, 32),
        maximumSize: const Size(150, 32),
      ),
      child: Transform.scale(
        scaleX: 0.9, // Same horizontal compression as pagination buttons
        scaleY: 1.05, // Same vertical stretching as pagination buttons
        child: const Text(
          'Connect Spotify',
          style: TextStyle(
            fontSize: 12, // Same font size as pagination buttons
            fontWeight: FontWeight.w200, // Same font weight as pagination buttons
            letterSpacing: 2.0, // Same letter spacing as pagination buttons
          ),
        ),
      ),
    );
  }
}
