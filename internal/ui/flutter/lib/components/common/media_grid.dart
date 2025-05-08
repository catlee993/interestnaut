import 'package:flutter/material.dart';

class MediaGrid extends StatelessWidget {
  final List<Widget> children;

  const MediaGrid({Key? key, required this.children}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Responsive column count based on screen width
    int columns = 1;
    double width = MediaQuery.of(context).size.width;
    if (width >= 1600) {
      columns = 5;
    } else if (width >= 1200) {
      columns = 4;
    } else if (width >= 900) {
      columns = 3;
    } else if (width >= 600) {
      columns = 2;
    }
    return GridView.count(
      crossAxisCount: columns,
      crossAxisSpacing: 24,
      mainAxisSpacing: 24,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      children: children,
    );
  }
} 