import 'package:flutter/material.dart';

class LoadingSuggestion extends StatelessWidget {
  final String mediaType;
  
  const LoadingSuggestion({
    Key? key,
    required this.mediaType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF282828), // Same surface color as suggestion cards
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3), // Match suggestion card border
          width: 1,
        ),
      ),
      child: SizedBox(
        height: 450, // Same height as suggestion cards
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFFA855F7),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Fetching next suggestion...',
                style: TextStyle(
                  fontFamily: 'Inter', // Match theme font
                  color: Colors.grey[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w300, // Match theme weight
                  letterSpacing: 0.8, // Match theme letter spacing
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 