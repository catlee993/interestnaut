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
    return ClipPath(
      clipper: _HeaderBoundaryClipper(headerHeight: headerHeight),
      child: ShaderMask(
        shaderCallback: (Rect rect) {
          return const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,  // Transparent at the top (behind header)
              Colors.white,        // Fully visible below the header
            ],
            // Make the transition more pronounced to ensure text disappears quickly
            stops: [0.0, 0.02],    // Even quicker transition just below the header
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: child,
      ),
    );
  }
}

/// Custom clipper that completely clips content above the header boundary
class _HeaderBoundaryClipper extends CustomClipper<Path> {
  final double headerHeight;
  
  _HeaderBoundaryClipper({required this.headerHeight});
  
  @override
  Path getClip(Size size) {
    final path = Path();
    // Make clipping trigger much earlier (60px below header)
    path.moveTo(0, headerHeight + 60);
    // Create a rectangle that covers everything below the header (with extra buffer)
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, headerHeight + 60);
    path.close();
    return path;
  }
  
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
