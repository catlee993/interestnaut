import 'package:flutter/material.dart';
import '../../theme.dart';

/// Standardized close button based on settings drawer design
/// Used throughout the app for consistency
class StandardCloseButton extends StatelessWidget {
  final VoidCallback onPressed;
  final double? size;
  final EdgeInsets? padding;

  const StandardCloseButton({
    Key? key,
    required this.onPressed,
    this.size = 20,
    this.padding = const EdgeInsets.all(6),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.close,
        color: AppTheme.primaryColor.withOpacity(0.8),
        size: size,
        shadows: [
          Shadow(
            color: AppTheme.primaryColor.withOpacity(0.6),
            offset: const Offset(0, 0),
            blurRadius: 1,
          ),
        ],
      ),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        padding: padding,
      ),
    );
  }
}