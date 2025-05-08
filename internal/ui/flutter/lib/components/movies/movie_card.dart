import 'package:flutter/material.dart';
import '../../models.dart';
import '../common/media_card.dart';

class MovieWithSavedStatus {
  final int id;
  final String title;
  final String? overview;
  final String? posterPath;
  final double voteAverage;
  final int voteCount;
  final String? releaseDate;
  final String? director;
  final String? writer;

  MovieWithSavedStatus({
    required this.id,
    required this.title,
    this.overview,
    this.posterPath,
    required this.voteAverage,
    required this.voteCount,
    this.releaseDate,
    this.director,
    this.writer,
  });
}

class MovieCard extends StatelessWidget {
  final MovieWithSavedStatus movie;
  final bool isSaved;
  final bool isInWatchlist;
  final String view; // 'default' or 'watchlist'
  final void Function(int) onSave;
  final void Function(int)? onAddToWatchlist;
  final void Function(int)? onRemoveFromWatchlist;
  final void Function(int)? onLike;
  final void Function(int)? onDislike;

  const MovieCard({
    Key? key,
    required this.movie,
    required this.isSaved,
    this.isInWatchlist = false,
    this.view = 'default',
    required this.onSave,
    this.onAddToWatchlist,
    this.onRemoveFromWatchlist,
    this.onLike,
    this.onDislike,
  }) : super(key: key);

  MediaItem _toMediaItem() {
    return MediaItem(
      id: movie.id,
      title: movie.title,
      overview: movie.overview ?? '',
      posterPath: movie.posterPath ?? '',
      mediaType: 'movie',
      voteAverage: movie.voteAverage,
      releaseDate: movie.releaseDate,
      director: movie.director,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaCard(
      item: _toMediaItem(),
      isSaved: isSaved,
      isInWatchlist: isInWatchlist,
      view: view,
      onSave: onSave,
      onAddToWatchlist: onAddToWatchlist,
      onRemoveFromWatchlist: onRemoveFromWatchlist,
      onLike: onLike,
      onDislike: onDislike,
    );
  }
} 