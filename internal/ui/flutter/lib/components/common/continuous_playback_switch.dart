import 'package:flutter/material.dart';

class ContinuousPlaybackSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ContinuousPlaybackSwitch({
    Key? key,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: const Text(
        'Continue playing liked songs',
        style: TextStyle(color: Colors.white, fontSize: 14),
      ),
      activeColor: const Color(0xFF7B68EE),
      activeTrackColor: const Color.fromRGBO(123, 104, 238, 0.5),
      inactiveTrackColor: Colors.white24,
      contentPadding: EdgeInsets.zero,
    );
  }
} 