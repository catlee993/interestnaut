import 'package:flutter/material.dart';
import '../../models.dart';
import '../common/media_card.dart';

class AudiobookWithSavedStatus {
  final String title;
  final String author;
  final String key;
  final String coverPath;
  final int? year;
  final List<String>? subjects;
  final String? description;
  final String? narrator;
  final double? durationHours;
  
  // Added fields to match the usage in _toMediaItem()
  String get id => key;
  String get imageUrl => coverPath;
  String? get publishedDate => year?.toString();

  AudiobookWithSavedStatus({
    required this.title,
    required this.author,
    required this.key,
    required this.coverPath,
    this.year,
    this.subjects,
    this.description,
    this.narrator,
    this.durationHours,
  });
}

class AudiobookCard extends StatelessWidget {
  final AudiobookWithSavedStatus audiobook;
  final bool isSaved;
  final bool isInListenList;
  final String view; // 'default' or 'listenlist'
  final void Function(String, String) onSave;
  final void Function(String, String)? onAddToListenList;
  final void Function(String, String)? onRemoveFromListenList;
  final void Function(String, String)? onLike;
  final void Function(String, String)? onDislike;

  const AudiobookCard({
    Key? key,
    required this.audiobook,
    required this.isSaved,
    this.isInListenList = false,
    this.view = 'default',
    required this.onSave,
    this.onAddToListenList,
    this.onRemoveFromListenList,
    this.onLike,
    this.onDislike,
  }) : super(key: key);

  MediaItem _toMediaItem() {
    return MediaItem(
      id: audiobook.id,
      title: audiobook.title,
      overview: audiobook.description ?? '',
      posterPath: audiobook.imageUrl ?? '',
      mediaType: 'audiobook',
      voteAverage: 0,
      author: audiobook.author,
      subjects: audiobook.subjects,
      releaseDate: audiobook.publishedDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaCard(
      item: _toMediaItem(),
      isSaved: isSaved,
      isInWatchlist: isInListenList,
      view: view,
      onSave: (id) => onSave(audiobook.title, audiobook.author),
      onAddToWatchlist: onAddToListenList != null ? (id) => onAddToListenList!(audiobook.title, audiobook.author) : null,
      onRemoveFromWatchlist: onRemoveFromListenList != null ? (id) => onRemoveFromListenList!(audiobook.title, audiobook.author) : null,
      onLike: onLike != null ? (id) => onLike!(audiobook.title, audiobook.author) : null,
      onDislike: onDislike != null ? (id) => onDislike!(audiobook.title, audiobook.author) : null,
    );
  }
} 