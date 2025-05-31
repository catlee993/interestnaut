// This is a utility class that re-exports the icons we need
// from font_awesome_flutter, so we have a central place to manage them

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Custom icons for the app
class AppIcons {
  AppIcons._();
  
  // Font Awesome icons used throughout the app 
  static const IconData play = FontAwesomeIcons.play;
  static const IconData pause = FontAwesomeIcons.pause;
  static const IconData thumbUp = FontAwesomeIcons.thumbsUp;
  static const IconData thumbDown = FontAwesomeIcons.thumbsDown;
  static const IconData plus = FontAwesomeIcons.plus;
  static const IconData stepForward = FontAwesomeIcons.stepForward;
  static const IconData times = FontAwesomeIcons.xmark;
  static const IconData spotify = FontAwesomeIcons.spotify;
  static const IconData robot = FontAwesomeIcons.robot;
  
  // Define standard sizes to use throughout the app
  static const double iconSizeSmall = 14.0;   // Smaller to match Font Awesome default size
  static const double iconSizeMedium = 18.0;  // Standard Font Awesome size
  static const double iconSizeLarge = 24.0;
} 