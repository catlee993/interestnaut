import 'package:flutter/material.dart';
import '../../theme.dart';

class SpotifyUserControl extends StatelessWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onClearAuth;

  const SpotifyUserControl({
    Key? key,
    required this.user,
    required this.onClearAuth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1DB954)),
          ),
          const SizedBox(width: 8),
          const Text(
            'Loading user...',
            style: TextStyle(
              color: Color(0xFF1DB954),
              fontSize: 12,
            ),
          ),
        ],
      );
    }
    final displayName = user!['display_name'] ?? 'Spotify User';
    final hasAvatar = user!['images'] != null &&
        user!['images'].isNotEmpty &&
        user!['images'][0]['url'] != null &&
        user!['images'][0]['url'].isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Logged in as',
                style: TextStyle(
                  color: Color(0xFF1DB954),
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
              Text(
                displayName,
                style: const TextStyle(
                  color: Color(0xFF1DB954),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 12,
            backgroundColor: hasAvatar ? null : const Color(0xFF1DB954),
            backgroundImage: hasAvatar ? NetworkImage(user!['images'][0]['url']) : null,
            child: hasAvatar
                ? null
                : Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onClearAuth,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.purpleRed,
              side: BorderSide(color: AppTheme.purpleRed),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              minimumSize: const Size(70, 20),
              textStyle: const TextStyle(fontSize: 10),
            ),
            child: const Text('Clear Auth'),
          ),
        ],
      ),
    );
  }
} 