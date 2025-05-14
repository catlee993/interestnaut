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
      child: ScrollConfiguration(
        // This custom behavior prevents headers from showing when scrolled behind the app header
        behavior: _HeaderAwareScrollBehavior(headerHeight: widget.headerHeight),
        child: SingleChildScrollView(
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
      ),
    );
  }
}

/// Custom scroll behavior that hides text elements when they scroll behind the header
class _HeaderAwareScrollBehavior extends ScrollBehavior {
  final double headerHeight;
  
  const _HeaderAwareScrollBehavior({required this.headerHeight});
  
  @override
  Widget buildViewportChrome(BuildContext context, Widget child, AxisDirection axisDirection) {
    return _HeaderClippingWidget(
      headerHeight: headerHeight,
      child: child,
    );
  }
}

/// Widget that clips or fades out text content when it reaches the header boundary
class _HeaderClippingWidget extends StatelessWidget {
  final double headerHeight;
  final Widget child;
  
  const _HeaderClippingWidget({
    required this.headerHeight,
    required this.child,
  });
  
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect rect) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,  // Transparent at the top (behind header)
            Colors.white,        // Fully visible below the header
          ],
          stops: [0.0, 0.05],    // Quick transition just below the header
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}
