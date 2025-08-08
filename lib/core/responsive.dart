import 'package:flutter/material.dart';

/// Responsive utility class for handling different screen sizes
class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 768;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 768 && 
      MediaQuery.of(context).size.width < 1200;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1200;

  static bool isSmallMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 400;

  /// Returns appropriate number of grid columns based on screen size
  static int getGridColumns(BuildContext context) {
    if (isSmallMobile(context)) return 2;
    if (isMobile(context)) return 3;
    if (isTablet(context)) return 4;
    return 6; // Desktop
  }

  /// Returns appropriate padding based on screen size
  static EdgeInsets getScreenPadding(BuildContext context) {
    if (isMobile(context)) return const EdgeInsets.all(8.0);
    if (isTablet(context)) return const EdgeInsets.all(12.0);
    return const EdgeInsets.all(16.0); // Desktop
  }

  /// Returns appropriate spacing between elements
  static double getSpacing(BuildContext context) {
    if (isMobile(context)) return 8.0;
    if (isTablet(context)) return 12.0;
    return 16.0; // Desktop
  }

  /// Returns appropriate font size based on screen size
  static double getFontSize(BuildContext context, double baseFontSize) {
    if (isMobile(context)) return baseFontSize * 0.9;
    if (isTablet(context)) return baseFontSize * 0.95;
    return baseFontSize; // Desktop
  }

  /// Returns appropriate drawer width based on screen size
  static double getDrawerWidth(BuildContext context) {
    if (isMobile(context)) return MediaQuery.of(context).size.width * 0.85;
    if (isTablet(context)) return 320.0;
    return 400.0; // Desktop
  }

  /// Returns whether to show navigation drawer on the side or as overlay
  static bool shouldShowPersistentDrawer(BuildContext context) =>
      isDesktop(context);

  /// Returns appropriate media card height based on screen size
  static double getMediaCardHeight(BuildContext context) {
    if (isSmallMobile(context)) return 180.0;
    if (isMobile(context)) return 220.0;
    if (isTablet(context)) return 280.0;
    return 320.0; // Desktop
  }
}