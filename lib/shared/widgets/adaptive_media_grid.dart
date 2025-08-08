import 'package:flutter/material.dart';
import '../../core/responsive.dart';
import 'media_grid.dart';

/// Adaptive media grid that provides different layouts for mobile vs desktop
/// without affecting the existing desktop MediaGrid behavior
class AdaptiveMediaGrid extends StatelessWidget {
  final double spacing;
  final double childAspectRatio;
  final List<Widget> children;

  const AdaptiveMediaGrid({
    Key? key,
    this.spacing = 16.0,
    this.childAspectRatio = 1.0,
    required this.children,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (Responsive.isMobile(context)) {
      // Mobile-specific grid layout
      return _MobileMediaGrid(
        children: children,
        spacing: spacing,
        childAspectRatio: childAspectRatio,
      );
    } else {
      // Use existing desktop MediaGrid unchanged
      return MediaGrid(
        columns: 6, // Desktop default
        spacing: spacing,
        childAspectRatio: childAspectRatio,
        children: children,
      );
    }
  }
}

/// Mobile-specific media grid implementation
class _MobileMediaGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double childAspectRatio;

  const _MobileMediaGrid({
    required this.children,
    required this.spacing,
    required this.childAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    final columns = Responsive.getGridColumns(context);
    
    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: spacing * 0.75, // Slightly tighter spacing on mobile
      mainAxisSpacing: spacing * 0.75,
      childAspectRatio: childAspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}