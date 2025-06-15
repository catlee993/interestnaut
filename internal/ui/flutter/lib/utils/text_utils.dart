class TextUtils {
  /// Formats artist names from database format to display format
  /// Handles special cases like {{Plainlist|* Artist1 * Artist2}} and converts to "Artist1, Artist2 and Artist3"
  static String formatArtistNames(String? artistString) {
    if (artistString == null || artistString.isEmpty) {
      return 'Unknown Artist';
    }

    // Handle {{Plainlist|* Artist1 * Artist2}} format
    if (artistString.contains('{{Plainlist|')) {
      // Extract content between {{Plainlist| and }}
      final match = RegExp(r'\{\{Plainlist\|(.*?)\}\}').firstMatch(artistString);
      if (match != null) {
        final content = match.group(1) ?? '';
        // Split by * and clean up each artist name
        final artists = content
            .split('*')
            .map((artist) => artist.trim())
            .where((artist) => artist.isNotEmpty)
            .toList();
        
        return _formatArtistList(artists);
      }
    }

    // Handle comma-separated lists
    if (artistString.contains(',')) {
      final artists = artistString
          .split(',')
          .map((artist) => artist.trim())
          .where((artist) => artist.isNotEmpty)
          .toList();
      
      return _formatArtistList(artists);
    }

    // Single artist or already formatted
    return artistString.trim();
  }

  /// Formats a list of artists with proper conjunction
  static String _formatArtistList(List<String> artists) {
    if (artists.isEmpty) return 'Unknown Artist';
    if (artists.length == 1) return artists.first;
    if (artists.length == 2) return '${artists.first} and ${artists.last}';
    
    // For 3 or more artists: "Artist1, Artist2 and Artist3"
    final allButLast = artists.sublist(0, artists.length - 1);
    final last = artists.last;
    return '${allButLast.join(', ')} and $last';
  }
} 