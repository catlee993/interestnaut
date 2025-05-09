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
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1DB954)),
          ),
          SizedBox(width: 6),
          Text(
            'Loading...',
            style: TextStyle(
              color: Color(0xFF1DB954),
              fontSize: 11,
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
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Logged in as ${displayName}',
            style: const TextStyle(
              color: Color(0xFF1DB954),
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 10,
            backgroundColor: hasAvatar ? null : const Color(0xFF1DB954),
            backgroundImage: hasAvatar ? NetworkImage(user!['images'][0]['url']) : null,
            child: hasAvatar
                ? null
                : Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: onClearAuth,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.purpleRed,
              side: BorderSide(color: AppTheme.purpleRed),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              minimumSize: const Size(50, 18),
              textStyle: const TextStyle(fontSize: 9),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
} 