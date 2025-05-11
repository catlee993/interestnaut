import 'package:flutter/material.dart';

/// A small button for the header to connect to Spotify
class SpotifyConnectButton extends StatelessWidget {
  final VoidCallback onConnect;

  const SpotifyConnectButton({
    Key? key,
    required this.onConnect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onConnect,
      icon: const Icon(
        Icons.music_note,
        size: 14,
        color: Colors.white,
      ),
      label: const Text(
        'Connect Spotify',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1DB954), // Spotify green
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        minimumSize: const Size(10, 26),
        maximumSize: const Size(150, 26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
    );
  }
}
