import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/grpc_client.dart';
import '../../enums/media_type.dart';

/// Autocomplete widget for themes and genres using FTS search
class AutocompleteSearch extends StatefulWidget {
  final String mediaType;
  final String searchType; // 'themes' or 'genres'
  final String hintText;
  final Function(String) onSelected;
  final List<String> existingItems; // To avoid duplicates

  const AutocompleteSearch({
    Key? key,
    required this.mediaType,
    required this.searchType,
    required this.hintText,
    required this.onSelected,
    this.existingItems = const [],
  }) : super(key: key);

  @override
  State<AutocompleteSearch> createState() => _AutocompleteSearchState();
}

class _AutocompleteSearchState extends State<AutocompleteSearch> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Convert header media type to database media type
  String _getDbMediaType() {
    try {
      final mediaType = MediaType.fromHeaderName(widget.mediaType);
      return mediaType.databaseName;
    } catch (e) {
      debugPrint('Unknown media type: ${widget.mediaType}');
      return widget.mediaType;
    }
  }

  /// Search for themes or genres using FTS
  Future<void> _searchItems(String query) async {
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    if (query == _lastQuery) return; // Avoid duplicate searches
    _lastQuery = query;

    setState(() {
      _isLoading = true;
      _showSuggestions = true;
    });

    try {
      final grpcClient = GrpcRecommendationClient();
      await grpcClient.init(); // Ensure client is initialized
      final dbMediaType = _getDbMediaType();
      List<String> results;

      if (widget.searchType == 'themes') {
        final response = await grpcClient.searchThemes(
          mediaType: dbMediaType,
          query: query,
          limit: 10,
        );
        results = List<String>.from(response['themes'] ?? []);
      } else {
        final response = await grpcClient.searchGenres(
          mediaType: dbMediaType,
          query: query,
          limit: 10,
        );
        results = List<String>.from(response['genres'] ?? []);
      }

      // Filter out items that are already selected
      final filteredResults = results
          .where((item) => !widget.existingItems.contains(item))
          .toList();

      setState(() {
        _suggestions = filteredResults;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
    }
  }

  void _selectItem(String item) {
    widget.onSelected(item);
    _controller.clear();
    _focusNode.unfocus();
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
      _lastQuery = '';
    });
  }

  /// Get the correct icon for the current media type and search type
  IconData _getIconForMediaType() {
    try {
      final mediaType = MediaType.fromHeaderName(widget.mediaType);
      if (widget.searchType == 'themes') {
        return Icons.label_outline; // Always use label for themes
      } else {
        return mediaType.icon; // Use media-specific icon for genres
      }
    } catch (e) {
      debugPrint('Unknown media type: ${widget.mediaType}');
      return widget.searchType == 'themes' ? Icons.label_outline : Icons.music_note_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input field
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
            filled: true,
            fillColor: const Color(0xFF0A0A0A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.primaryColor),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            suffixIcon: _isLoading
                ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryColor.withOpacity(0.6),
                      ),
                    ),
                  )
                : Icon(
                    Icons.search,
                    color: Colors.white.withOpacity(0.5),
                    size: 20,
                  ),
          ),
          onChanged: _searchItems,
          onTap: () {
            if (_controller.text.length >= 2) {
              setState(() => _showSuggestions = true);
            }
          },
        ),

        // Suggestions dropdown
        if (_showSuggestions && (_suggestions.isNotEmpty || _isLoading))
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _isLoading
                ? Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Searching ${widget.searchType}...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return InkWell(
                        onTap: () => _selectItem(suggestion),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getIconForMediaType(),
                                color: AppTheme.primaryColor.withOpacity(0.7),
                                size: 16,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  suggestion,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}