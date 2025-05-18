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
      activeColor: const Color(0xFF7B68EE), // Bright purple color for the thumb when active
      activeTrackColor: const Color(0x887B68EE), // Slightly transparent purple for the track
      inactiveThumbColor: Colors.grey[400], // Light grey for inactive thumb
      inactiveTrackColor: Colors.grey[800], // Dark grey for inactive track
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading, // Place the switch on the left
      dense: true, // Make the tile more compact
    );
  }
}