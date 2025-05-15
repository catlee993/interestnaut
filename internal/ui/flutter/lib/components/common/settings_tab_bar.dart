import 'package:flutter/material.dart';

class SettingsTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const SettingsTabBar({
    Key? key,
    required this.currentIndex,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TabBar(
      indicatorColor: const Color(0xFF7B68EE),
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white,
      labelStyle: const TextStyle(fontWeight: FontWeight.w500),
      tabs: const [
        Tab(text: 'Settings'),
        Tab(text: 'Authentication'),
      ],
      onTap: onChanged,
      controller: TabController(
        length: 2,
        vsync: Scaffold.of(context),
        initialIndex: currentIndex,
      ),
    );
  }
} 