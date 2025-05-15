import 'package:flutter/material.dart';

/// A wrapper component that manages scrollable content beneath a header
/// - Adds appropriate padding at the top to account for the header height
/// - Hides title elements when they scroll behind the header
class ScrollContentWrapper extends StatefulWidget {
  /// The main content to display and scroll
  final Widget child;
  
  /// The height of the header to account for
  final double headerHeight;
  
  /// Custom padding (beyond the header height)
  final EdgeInsets? padding;

  const ScrollContentWrapper({
    Key? key,
    required this.child,
    this.headerHeight = 106.0, // Default header height (46px top row + 60px search bar)
    this.padding,
  }) : super(key: key);

  @override
  State<ScrollContentWrapper> createState() => _ScrollContentWrapperState();
}

class _ScrollContentWrapperState extends State<ScrollContentWrapper> {
  final ScrollController _scrollController = ScrollController();
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        // You could add scroll position tracking here if needed
        return false;
      },
      child: Stack(
        children: [
          // Main scrollable content
          SingleChildScrollView(
            controller: _scrollController,
            // Add padding that considers the header height
            padding: EdgeInsets.only(
              top: widget.headerHeight + (widget.padding?.top ?? 16.0),
              left: widget.padding?.left ?? 16.0,
              right: widget.padding?.right ?? 16.0,
              bottom: widget.padding?.bottom ?? 80.0, // Account for player bar
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            child: widget.child,
          ),
          
          // Overlay gradient to hide content behind header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: widget.headerHeight + 60, // Extra buffer for transition
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),  // Less opaque at top to allow blur effect
                      Colors.black.withOpacity(0.4),  // Less opacity in middle
                      Colors.black.withOpacity(0.0),  // Transparent at bottom for smooth transition
                    ],
                    stops: const [0.0, 0.7, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
