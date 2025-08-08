import 'package:flutter/material.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/media_card.dart';

class GameWithSavedStatus {
  final int id;
  final String name;
  final String? description;
  final String? coverUrl;
  final double rating;
  final int ratingsCount;
  final String? releaseDate;
  final List<String>? genres;
  final String? developer;
  final String? publisher;
  final String? platform;

  GameWithSavedStatus({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    required this.rating,
    required this.ratingsCount,
    this.releaseDate,
    this.genres,
    this.developer,
    this.publisher,
    this.platform,
  });
}

class GameCard extends StatelessWidget {
  final GameWithSavedStatus game;
  final bool isSaved;
  final bool isInLibrary;
  final String view; // 'default' or 'library'
  final void Function(int) onSave;
  final void Function(int)? onAddToLibrary;
  final void Function(int)? onRemoveFromLibrary;
  final void Function(int)? onLike;
  final void Function(int)? onDislike;

  const GameCard({
    Key? key,
    required this.game,
    required this.isSaved,
    this.isInLibrary = false,
    this.view = 'default',
    required this.onSave,
    this.onAddToLibrary,
    this.onRemoveFromLibrary,
    this.onLike,
    this.onDislike,
  }) : super(key: key);

  MediaItem _toMediaItem() {
    return MediaItem(
      id: game.id,
      title: game.name,
      overview: game.description ?? '',
      posterPath: game.coverUrl ?? '',
      mediaType: 'game',
      voteAverage: game.rating ?? 0,
      releaseDate: game.releaseDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaCard(
      item: _toMediaItem(),
      isSaved: isSaved,
      isInWatchlist: isInLibrary,
      view: view,
      onSave: onSave,
      onAddToWatchlist: onAddToLibrary,
      onRemoveFromWatchlist: onRemoveFromLibrary,
      onLike: onLike,
      onDislike: onDislike,
    );
  }
} 