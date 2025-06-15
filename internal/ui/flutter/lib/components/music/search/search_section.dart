import 'package:flutter/material.dart';
import '../../../models.dart';
import '../tracks/search_result_card.dart';
import '../../common/media_grid.dart';

class SearchSection extends StatelessWidget {
  final List<SimpleTrack> searchResults;
  final bool isLoading;
  final String? error;
  final Future<void> Function(String) onSearch;
  final Future<void> Function(SimpleTrack) onPlay;
  final Future<void> Function(SimpleTrack) onSave;
  final Future<void> Function(SimpleTrack) onRemove;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  const SearchSection({
    Key? key,
    required this.searchResults,
    this.isLoading = false,
    this.error,
    required this.onSearch,
    required this.onPlay,
    required this.onSave,
    required this.onRemove,
    required this.onRetry,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24.0),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Colors.white70),
          ),
        ),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Display search results in a MediaGrid with 3 columns using SearchResultCard
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
                  child: Text(
                    'Search Results: ${searchResults.length} tracks',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onClose,
                  tooltip: 'Close search',
                ),
              ],
            ),
            MediaGrid(
              columns: 3,  // Using 3 columns for better readability
              children: searchResults
                  .map((track) => SearchResultCard(
                        track: track,
                        isSaved: false,
                        onPlay: (t) => onPlay(t),
                        onSave: (t) => onSave(t),
                        onRemove: (t) => onRemove(t),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}