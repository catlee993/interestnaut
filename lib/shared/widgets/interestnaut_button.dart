import 'package:flutter/material.dart';

/// Universal Interestnaut-styled button component
/// Consistent with pagination and Spotify connect buttons
class InterestNautButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;
  final bool isActive;
  final bool isDisabled;
  final Icon? icon;
  final double? minWidth;
  final double? maxWidth;

  const InterestNautButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.color,
    this.backgroundColor,
    this.isActive = false,
    this.isDisabled = false,
    this.icon,
    this.minWidth,
    this.maxWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? const Color(0xFFA855F7);
    
    ButtonStyle style;
    
    if (isActive && backgroundColor != null) {
      // Active/selected state with colored background
      style = ElevatedButton.styleFrom(
        backgroundColor: backgroundColor!.withOpacity(0.25),
        foregroundColor: effectiveColor,
        elevation: 0,
        side: BorderSide(color: effectiveColor, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11), // More comfortable size
        minimumSize: Size(minWidth ?? 105, 42), // Taller buttons
        maximumSize: Size(maxWidth ?? 175, 42),
      );
    } else if (isDisabled) {
      // Disabled state
      style = ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.withOpacity(0.3),
        foregroundColor: Colors.grey,
        elevation: 0,
        side: BorderSide(color: Colors.grey.withOpacity(0.3), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        minimumSize: Size(minWidth ?? 105, 42),
        maximumSize: Size(maxWidth ?? 175, 42),
      );
    } else {
      // Default state: black background with white text (like original action buttons)
      style = ElevatedButton.styleFrom(
        backgroundColor: Colors.black.withOpacity(0.7),
        foregroundColor: Colors.white,
        elevation: 0,
        side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        minimumSize: Size(minWidth ?? 105, 42),
        maximumSize: Size(maxWidth ?? 175, 42),
      );
    }

    Widget child = Transform.scale(
      scaleX: 0.9, // Same horizontal compression as pagination buttons
      scaleY: 1.05, // Same vertical stretching as pagination buttons
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12, // Slightly bigger for taller buttons
          fontWeight: FontWeight.w200, // Same thin weight as pagination buttons
          letterSpacing: 1.5, // Same letter spacing style
        ),
      ),
    );

    if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon!.icon, size: 14), // Smaller icon
          const SizedBox(width: 6), // Reduced spacing
          Flexible(child: child), // Wrap text in Flexible to prevent overflow
        ],
      );
    }

    // Always use ElevatedButton since we have background colors for all states
    return ElevatedButton(
      onPressed: isDisabled ? null : onPressed,
      style: style,
      child: child,
    );
  }
}