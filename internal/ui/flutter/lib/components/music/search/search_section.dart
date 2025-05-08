import 'package:flutter/material.dart';
import '../../../models.dart';
import '../tracks/track_card.dart';
import '../../common/search_bar.dart';
import '../../common/media_grid.dart';
import 'dart:async';

class SearchSection extends StatefulWidget {
  final List<Track> searchResults;
  final Future<void> Function(String) onSearch;
  final Future<void> Function(Track) onPlay;
  final Future<void> Function(Track) onSave;
  final Future<void> Function(Track) onRemove;

  const SearchSection({
    Key? key,
    required this.searchResults,
    required this.onSearch,
    required this.onPlay,
    required this.onSave,
    required this.onRemove,
  }) : super(key: key);

  @override
  State<SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends State<SearchSection> {
  String _searchQuery = '';
  Timer? _debounce;
  bool _showResults = false;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    setState(() => _searchQuery = query);
    if (query.isEmpty) {
      setState(() => _showResults = false);
      widget.onSearch('');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      await widget.onSearch(query);
      setState(() => _showResults = true);
    });
  }

  void _onClear() {
    setState(() {
      _searchQuery = '';
      _showResults = false;
    });
    widget.onSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SearchBar(
            placeholder: 'Search tracks...',
            onSearch: _onSearchChanged,
            onClear: _onClear,
          ),
          if (_showResults && widget.searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                color: Color.fromRGBO(18, 18, 18, 0.95),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: MediaGrid(
                    children: widget.searchResults
                        .map((track) => TrackCard(
                              track: track,
                              isSaved: false,
                              onPlay: (t) => widget.onPlay(t),
                              onSave: (t) => widget.onSave(t),
                              onRemove: (t) => widget.onRemove(t),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 