import 'package:flutter/material.dart';

/// Configuration class for media types - centralized single source of truth
class MediaTypeConfig {
  final String displayName;
  final String pluralDisplayName;
  final IconData icon;
  final IconData fallbackIcon;
  final String listName;
  final String listActionName;
  final String searchPlaceholder;
  final String estimatedDbSize;
  final String headerDisplayName;

  const MediaTypeConfig({
    required this.displayName,
    required this.pluralDisplayName,
    required this.icon,
    required this.fallbackIcon,
    required this.listName,
    required this.listActionName,
    required this.searchPlaceholder,
    required this.estimatedDbSize,
    required this.headerDisplayName,
  });

  // Default/unknown media type configuration
  const MediaTypeConfig.unknown()
      : displayName = 'Unknown',
        pluralDisplayName = 'Unknown',
        icon = Icons.category,
        fallbackIcon = Icons.category,
        listName = 'List',
        listActionName = 'list',
        searchPlaceholder = 'Search...',
        estimatedDbSize = '~200 MB',
        headerDisplayName = 'UNKNOWN';
} 