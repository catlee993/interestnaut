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
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Logged in as',
                      style: TextStyle(
                        color: Color(0xFF1DB954),
                        fontSize: 8.5, 
                        fontWeight: FontWeight.w300,
                        fontFamily: 'Inter, Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
                        height: 1.2,
                      ),
                    ),
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Color(0xFF1DB954),
                        fontSize: 9.5, 
                        fontWeight: FontWeight.w600, 
                        fontFamily: 'Inter, Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
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
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 20, 
                  child: OutlinedButton(
                    onPressed: onClearAuth,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.purpleRed,
                      side: const BorderSide(color: AppTheme.purpleRed),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      minimumSize: const Size(70, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 8.5, 
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.3,
                        fontFamily: 'Inter, Roboto, -apple-system, BlinkMacSystemFont, Segoe UI, Helvetica, Arial, sans-serif',
                      ),
                    ),
                    child: const Text('Clear Auth'),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }
}