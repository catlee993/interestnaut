import 'package:flutter/material.dart';

// Universal margin constant - single source of truth for all layout spacing
class LayoutConstants {
  static const double universalHorizontalMargin = 24.0;
  static const double sectionVerticalSpacing = 32.0;
  static const double componentVerticalSpacing = 16.0;
}

/// Universal wrapper for all media sections - ensures consistent vertical stacking and margins
class MediaSectionWrapper extends StatelessWidget {
  final List<Widget> children;
  
  const MediaSectionWrapper({
    Key? key,
    required this.children,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: LayoutConstants.universalHorizontalMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children.map((child) => Padding(
          padding: const EdgeInsets.only(bottom: LayoutConstants.componentVerticalSpacing),
          child: child,
        )).toList(),
      ),
    );
  }
}

/// Wrapper for suggestion displays - consistent styling and no additional margins (already handled by MediaSectionWrapper)
class SuggestionDisplayWrapper extends StatelessWidget {
  final Widget child;
  
  const SuggestionDisplayWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF282828),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// Wrapper for action buttons - ensures single horizontal line with consistent spacing
class ActionButtonsWrapper extends StatelessWidget {
  final List<Widget> children;
  
  const ActionButtonsWrapper({
    Key? key,
    required this.children,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children.map((child) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: child,
        )).toList(),
      ),
    );
  }
}

/// Wrapper for library sections - consistent spacing without additional horizontal margins
class LibrarySectionWrapper extends StatelessWidget {
  final String title;
  final Widget child;
  
  const LibrarySectionWrapper({
    Key? key,
    required this.title,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: LayoutConstants.sectionVerticalSpacing),
        Center(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: LayoutConstants.componentVerticalSpacing),
        child,
      ],
    );
  }
} 