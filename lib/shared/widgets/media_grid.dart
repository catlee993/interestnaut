import 'package:flutter/material.dart';

class MediaGrid extends StatelessWidget {
  final List<Widget> children;
  final int columns;
  final double spacing;
  final double childAspectRatio;

  const MediaGrid({
    Key? key, 
    required this.children,
    this.columns = 2,
    this.spacing = 16.0,
    this.childAspectRatio = 1.0, // Default to square (1:1)
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      childAspectRatio: childAspectRatio,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}