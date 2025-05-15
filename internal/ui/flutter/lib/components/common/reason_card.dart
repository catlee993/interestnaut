import 'package:flutter/material.dart';
import '../../theme.dart';
import 'icons.dart';

class ReasonCard extends StatelessWidget {
  final String reason;
  final BoxDecoration? decoration;

  const ReasonCard({
    Key? key,
    required this.reason,
    this.decoration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: decoration ?? BoxDecoration(
        color: const Color(0xFF121212).withOpacity(0.5),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                AppIcons.spotify,
                size: AppIcons.iconSizeSmall,
                color: AppTheme.primaryColor,
              ),
              SizedBox(width: 8),
              Text(
                'Our AI Says:',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            reason,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
} 