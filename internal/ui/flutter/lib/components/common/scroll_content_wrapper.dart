import 'package:flutter/material.dart';

// Universal layout constants - single source of truth for all spacing
class LayoutConstants {
  static const double universalHorizontalMargin = 24.0;
  static const double sectionVerticalSpacing = 32.0;
  static const double componentVerticalSpacing = 16.0;
  static const double defaultHeaderHeight = 106.0; // 46px top row + 60px search bar
}

/// A universal layout wrapper for media sections that manages:
/// - Scrollable content beneath a header
/// - Consistent horizontal margins across all sections
/// - Proper spacing between components
/// - Title visibility based on scroll position
typedef ScrollContentBuilder = Widget Function(double scrollOffset);

class MediaSectionLayout extends StatefulWidget {
  /// The main content builder, gets scroll offset for dynamic behavior
  final ScrollContentBuilder builder;
  /// The height of the header to account for
  final double headerHeight;
  /// Whether to apply universal horizontal margins (default: true)
  final bool useUniversalMargins;
  /// Custom padding override (if you need different spacing)
  final EdgeInsets? customPadding;

  const MediaSectionLayout({
    Key? key,
    required this.builder,
    this.headerHeight = LayoutConstants.defaultHeaderHeight,
    this.useUniversalMargins = true,
    this.customPadding,
  }) : super(key: key);

  @override
  State<MediaSectionLayout> createState() => _MediaSectionLayoutState();
}

class _MediaSectionLayoutState extends State<MediaSectionLayout> {
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
    // Calculate padding based on universal margins or custom override
    final EdgeInsets effectivePadding = widget.customPadding ?? EdgeInsets.only(
      top: widget.headerHeight + LayoutConstants.componentVerticalSpacing,
      left: widget.useUniversalMargins ? LayoutConstants.universalHorizontalMargin : 16.0,
      right: widget.useUniversalMargins ? LayoutConstants.universalHorizontalMargin : 16.0,
      bottom: LayoutConstants.componentVerticalSpacing,
    );

    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          padding: effectivePadding,
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

/// Helper widget for consistent section spacing within MediaSectionLayout
class SectionSpacing extends StatelessWidget {
  final Widget child;
  final double? customSpacing;

  const SectionSpacing({
    Key? key,
    required this.child,
    this.customSpacing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: customSpacing ?? LayoutConstants.sectionVerticalSpacing,
      ),
      child: child,
    );
  }
}

/// Helper widget for consistent component spacing within sections
class ComponentSpacing extends StatelessWidget {
  final Widget child;
  final double? customSpacing;

  const ComponentSpacing({
    Key? key,
    required this.child,
    this.customSpacing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: customSpacing ?? LayoutConstants.componentVerticalSpacing,
      ),
      child: child,
    );
  }
}

// Backward compatibility alias
typedef ScrollContentWrapper = MediaSectionLayout;

// Example usage:
class ExampleUsage extends StatelessWidget {
  const ExampleUsage({super.key});

  @override
  Widget build(BuildContext context) {
    return MediaSectionLayout(
      builder: (scrollOffset) {
        return Column(
          children: [
            // Hide title when scrolled behind header
            Opacity(
              opacity: scrollOffset < LayoutConstants.defaultHeaderHeight ? 1.0 : 0.0,
              child: const Text(
                'Suggested for You',
                style: TextStyle(fontSize: 24.0),
              ),
            ),
            ComponentSpacing(
              child: Container(/* suggestion content */),
            ),
            SectionSpacing(
              child: Column(
                children: [
                  const Text('Library Section'),
                  ComponentSpacing(
                    child: Container(/* library content */),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
