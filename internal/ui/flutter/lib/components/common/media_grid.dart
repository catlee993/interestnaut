import 'package:flutter/material.dart';

class MediaGrid extends StatelessWidget {
  final List<Widget> children;
  final int columns;

  const MediaGrid({
    Key? key, 
    required this.children,
    this.columns = 2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}