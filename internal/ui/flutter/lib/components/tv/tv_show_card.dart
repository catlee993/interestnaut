import 'package:flutter/material.dart';
import '../../models.dart';
import '../common/media_card.dart';

class TVShowWithSavedStatus {
  final int id;
  final String name;
  final String? overview;
  final String? posterPath;
  final double voteAverage;
  final int voteCount;
  final String? firstAirDate;
  final String? lastAirDate;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;
  final List<String>? genres;
  final String? network;
  final String? status;

  TVShowWithSavedStatus({
    required this.id,
    required this.name,
    this.overview,
    this.posterPath,
    required this.voteAverage,
    required this.voteCount,
    this.firstAirDate,
    this.lastAirDate,
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.genres,
    this.network,
    this.status,
  });
}

class TVShowCard extends StatelessWidget {
  final TVShowWithSavedStatus show;
  final bool isSaved;
  final bool isInWatchlist;
  final String view; // 'default' or 'watchlist'
  final void Function(int) onSave;
  final void Function(int)? onAddToWatchlist;
  final void Function(int)? onRemoveFromWatchlist;
  final void Function(int)? onLike;
  final void Function(int)? onDislike;

  const TVShowCard({
    Key? key,
    required this.show,
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
      id: show.id,
      title: show.name,
      overview: show.overview ?? '',
      posterPath: show.posterPath ?? '',
      mediaType: 'tv',
      voteAverage: show.voteAverage,
      releaseDate: show.firstAirDate,
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