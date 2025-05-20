import 'package:flutter/material.dart';

/// A wrapper component that manages scrollable content beneath a header
/// - Adds appropriate padding at the top to account for the header height
/// - Hides title elements when they scroll behind the header
typedef ScrollContentBuilder = Widget Function(double scrollOffset);

class ScrollContentWrapper extends StatefulWidget {
  /// The main content builder, gets scroll offset
  final ScrollContentBuilder builder;
  /// The height of the header to account for
  final double headerHeight;
  /// Custom padding (beyond the header height)
  final EdgeInsets? padding;

  const ScrollContentWrapper({
    Key? key,
    required this.builder,
    this.headerHeight = 106.0, // Default header height (46px top row + 60px search bar)
    this.padding,
  }) : super(key: key);

  @override
  State<ScrollContentWrapper> createState() => _ScrollContentWrapperState();
}

class _ScrollContentWrapperState extends State<ScrollContentWrapper> {
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.only(
            top: widget.headerHeight + (widget.padding?.top ?? 16.0),
            left: widget.padding?.left ?? 16.0,
            right: widget.padding?.right ?? 16.0,
            bottom: widget.padding?.bottom ?? 16.0,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          child: widget.builder(_scrollOffset),
        ),
        // Top gradient overlay for blending header/content
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 40,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromRGBO(18, 18, 18, 0.92), // Match header
                  Colors.transparent,
                ],
                stops: [0.0, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Example usage:
class ExampleUsage extends StatelessWidget {
  const ExampleUsage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScrollContentWrapper(
      headerHeight: 106.0,
      builder: (scrollOffset) {
        return Column(
          children: [
            // Hide title when scrolled behind header
            Opacity(
              opacity: scrollOffset < 106.0 ? 1.0 : 0.0,
              child: const Text(
                'Suggested for You',
                style: TextStyle(fontSize: 24.0),
              ),
            ),
            const SizedBox(height: 16.0),
            // Other content...
            const Text('Other content...'),
          ],
        );
      },
    );
  }
}
