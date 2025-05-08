import 'package:flutter/material.dart';
import '../../models.dart';
import '../common/media_card.dart';

class BookWithSavedStatus {
  final String title;
  final String author;
  final String key;
  final String coverPath;
  final int? year;
  final List<String>? subjects;
  final String? description;
  
  // Added fields to match the usage in _toMediaItem()
  String get id => key;
  String get imageUrl => coverPath;
  String? get publishedDate => year?.toString();

  BookWithSavedStatus({
    required this.title,
    required this.author,
    required this.key,
    required this.coverPath,
    this.year,
    this.subjects,
    this.description,
  });
}

class BookCard extends StatelessWidget {
  final BookWithSavedStatus book;
  final bool isSaved;
  final bool isInReadList;
  final String view; // 'default' or 'readlist'
  final void Function(String, String) onSave;
  final void Function(String, String)? onAddToReadList;
  final void Function(String, String)? onRemoveFromReadList;
  final void Function(String, String)? onLike;
  final void Function(String, String)? onDislike;

  const BookCard({
    Key? key,
    required this.book,
    required this.isSaved,
    this.isInReadList = false,
    this.view = 'default',
    required this.onSave,
    this.onAddToReadList,
    this.onRemoveFromReadList,
    this.onLike,
    this.onDislike,
  }) : super(key: key);

  MediaItem _toMediaItem() {
    return MediaItem(
      id: book.id,
      title: book.title,
      overview: book.description ?? '',
      posterPath: book.imageUrl ?? '',
      mediaType: 'book',
      subjects: book.subjects,
      author: book.author,
      voteAverage: 0,
      releaseDate: book.publishedDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaCard(
      item: _toMediaItem(),
      isSaved: isSaved,
      isInWatchlist: isInReadList,
      view: view,
      onSave: (id) => onSave(book.title, book.author),
      onAddToWatchlist: onAddToReadList != null ? (id) => onAddToReadList!(book.title, book.author) : null,
      onRemoveFromWatchlist: onRemoveFromReadList != null ? (id) => onRemoveFromReadList!(book.title, book.author) : null,
      onLike: onLike != null ? (id) => onLike!(book.title, book.author) : null,
      onDislike: onDislike != null ? (id) => onDislike!(book.title, book.author) : null,
    );
  }
} 