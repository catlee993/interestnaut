import 'package:flutter/material.dart';
import '../../../models.dart';
import '../tracks/track_card.dart';
import '../../common/search_bar.dart' as custom;
import '../../common/media_grid.dart';
import 'dart:async';

class SearchSection extends StatefulWidget {
  final List<SimpleTrack> searchResults;
  final Future<void> Function(String) onSearch;
  final Future<void> Function(SimpleTrack) onPlay;
  final Future<void> Function(SimpleTrack) onSave;
  final Future<void> Function(SimpleTrack) onRemove;

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
    // Add debug logging to check search results
    debugPrint('SearchSection build: showResults=${_showResults}, resultCount=${widget.searchResults.length}');
    if (widget.searchResults.isNotEmpty) {
      debugPrint('Search results available but may not be displayed: showResults=${_showResults}');
      // Force show results when we have them
      if (!_showResults) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _showResults = true;
          });
        });
      }
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          custom.SearchBar(
            placeholder: 'Search tracks...',
            onSearch: _onSearchChanged,
            onClear: _onClear,
            initialValue: _searchQuery, // Restore this parameter now that it's supported
          ),
          if (_showResults && widget.searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(18, 18, 18, 0.95),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
                    columns: 4,
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
            )
          else if (_showResults && widget.searchResults.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(18, 18, 18, 0.95),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'No tracks found',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }
}