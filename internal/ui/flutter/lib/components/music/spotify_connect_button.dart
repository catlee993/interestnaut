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
    return OutlinedButton(
      onPressed: onConnect,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF7B68EE), // Purple primary color
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(10, 32),
        maximumSize: const Size(150, 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        side: const BorderSide(color: Color(0xFF7B68EE), width: 1),
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
      child: const Text('Connect Spotify'),
    );
  }
}
