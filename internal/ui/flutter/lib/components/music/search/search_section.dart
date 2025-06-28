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

  String _getSearchResultsText(int count) {
    if (count == 0) return 'No results';
    if (count == 1) {
      return 'Found 1 track';
    }
    return 'Found $count tracks';
  }

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

    if (searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: 120, // Constrain to minimum height like one result row
          child: Stack(
            children: [
              // Centered "No results" text
              Center(
                child: Transform.scale(
                  scaleX: 1.15, // Same horizontal stretch as stylized headers
                  child: const Text(
                    'No results',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              // X button positioned in top right
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onClose, // This should clear the search and close overlay
                  child: Container(
                    width: 24,
                    height: 24,
                    child: CustomPaint(
                      painter: _SearchXButtonPainter(),
                    ),
                  ),
                ),
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
                  padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                  child: Transform.scale(
                    scaleX: 1.15, // Same horizontal stretch as stylized headers
                    child: Text(
                      _getSearchResultsText(searchResults.length),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    width: 24,
                    height: 24,
                    child: CustomPaint(
                      painter: _SearchXButtonPainter(),
                    ),
                  ),
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

/// Custom painter for the search X button - matches watchlist X styling
class _SearchXButtonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Purple outline paint (thicker)
    final outlinePaint = Paint()
      ..color = const Color(0xFFA855F7)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    // White X paint (thinner, on top)
    final xPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Draw purple outline first (behind)
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.25),
      Offset(size.width * 0.75, size.height * 0.75),
      outlinePaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.25),
      Offset(size.width * 0.25, size.height * 0.75),
      outlinePaint,
    );

    // Draw white X on top
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.25),
      Offset(size.width * 0.75, size.height * 0.75),
      xPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.25),
      Offset(size.width * 0.25, size.height * 0.75),
      xPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}