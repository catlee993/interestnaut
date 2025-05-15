import 'package:flutter/material.dart';

class MediaGrid extends StatelessWidget {
  final List<Widget> children;

  const MediaGrid({Key? key, required this.children}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Fixed column count of 2 as requested
    const int columns = 2;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.count(
        crossAxisCount: columns,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: children,
      ),
    );
  }
}