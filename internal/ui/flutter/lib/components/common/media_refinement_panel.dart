import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/sqlite_db.dart';
import '../../enums/media_type.dart';
import 'autocomplete_search.dart';
import 'standard_close_button.dart';

/// Panel for refining media recommendations with advanced controls
class MediaRefinementPanel extends StatefulWidget {
  final String mediaType;

  const MediaRefinementPanel({
    Key? key,
    required this.mediaType,
  }) : super(key: key);

  @override
  State<MediaRefinementPanel> createState() => _MediaRefinementPanelState();
}

class _MediaRefinementPanelState extends State<MediaRefinementPanel> {
  final SQLiteDatabase _db = SQLiteDatabase();
  // Removed _themeCount since backend now extracts ALL themes/genres
  double _similarityThreshold = 0.5;
  final List<String> _positiveConstraints = [];
  final List<String> _negativeConstraints = [];
  final List<String> _priorityTitles = [];
  final List<String> _avoidTitles = [];
  final TextEditingController _constraintController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  bool _isLoading = true;

  final Map<double, String> _similarityLabels = {
    0.1: 'Bohemian',
    0.3: 'Eclectic', 
    0.5: 'Versatile',
    0.7: 'Discerning',
    1.0: 'Meticulous',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _constraintController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  /// Convert header media type to database media type using enum
  String _getDbMediaType() {
    try {
      final mediaType = MediaType.fromHeaderName(widget.mediaType);
      return mediaType.databaseName;
    } catch (e) {
      debugPrint('❌ [MEDIA-TYPE] Unknown media type: ${widget.mediaType}');
      return widget.mediaType; // Fallback to original string
    }
  }

  /// Load existing settings from database
  Future<void> _loadSettings() async {
    try {
      await _db.init();
      
      final dbMediaType = _getDbMediaType();
      debugPrint('🔧 [SETTINGS-LOAD] Loading settings for ${widget.mediaType} -> $dbMediaType');
      
      // Load media settings
      final mediaSettings = await _db.getMediaSettings(dbMediaType);
      if (mediaSettings != null) {
        setState(() {
          _similarityThreshold = mediaSettings['similarity_matching'] ?? 0.5;
          // Removed _themeCount = mediaSettings['themes_matching'] ?? 3;
        });
        debugPrint('✅ [SETTINGS-LOAD] Loaded media settings: similarity=${_similarityThreshold}');
      }
      
      // Load matching constraints
      final matchingConstraints = await _db.getMediaMatchingConstraints(dbMediaType);
      setState(() {
        _positiveConstraints.clear();
        _negativeConstraints.clear();
        _positiveConstraints.addAll(matchingConstraints['positive'] ?? []);
        _negativeConstraints.addAll(matchingConstraints['negative'] ?? []);
      });
      debugPrint('✅ [SETTINGS-LOAD] Loaded matching constraints: +${_positiveConstraints.length}, -${_negativeConstraints.length}');
      
      // Load priority titles
      final priorityTitles = await _db.getMediaPriorityTitles(dbMediaType);
      setState(() {
        _priorityTitles.clear();
        _avoidTitles.clear();
        for (final title in priorityTitles['positive'] ?? []) {
          _priorityTitles.add('${title['title']} by ${title['creator']}');
        }
        for (final title in priorityTitles['negative'] ?? []) {
          _avoidTitles.add('${title['title']} by ${title['creator']}');
        }
      });
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Save settings to database
  Future<void> _saveSettings() async {
    try {
      final dbMediaType = _getDbMediaType();
      debugPrint('🔧 [SETTINGS-SAVE] Saving settings for ${widget.mediaType} -> $dbMediaType');
      
      // Save media settings (use default theme count of 3 for compatibility since backend extracts ALL themes/genres)
      await _db.saveMediaSettings(dbMediaType, _similarityThreshold, 3);
      debugPrint('✅ [SETTINGS-SAVE] Saved media settings: similarity=${_similarityThreshold}');
      
      // Save matching constraints - need to clear existing ones first
      await _clearAndSaveMatchingConstraints();
      
      // Save priority titles - need to clear existing ones first
      await _clearAndSavePriorityTitles();
      
      debugPrint('✅ [SETTINGS-SAVE] Settings saved successfully for ${widget.mediaType}');
    } catch (e) {
      debugPrint('❌ [SETTINGS-SAVE] Error saving settings: $e');
    }
  }

  /// Clear existing matching constraints and save new ones
  Future<void> _clearAndSaveMatchingConstraints() async {
    try {
      final dbMediaType = _getDbMediaType();
      debugPrint('🔧 [CONSTRAINTS-SAVE] Saving constraints for ${widget.mediaType} -> $dbMediaType');
      
      // Get existing constraints to clear them
      final existingConstraints = await _db.getMediaMatchingConstraints(dbMediaType);
      
      // Clear existing positive constraints
      for (final constraint in existingConstraints['positive'] ?? []) {
        await _db.deleteMediaMatchingConstraint(dbMediaType, constraint);
      }
      
      // Clear existing negative constraints
      for (final constraint in existingConstraints['negative'] ?? []) {
        await _db.deleteMediaMatchingConstraint(dbMediaType, constraint);
      }
      
      // Add new positive constraints
      for (final constraint in _positiveConstraints) {
        await _db.addMediaMatchingConstraint(dbMediaType, constraint, true);
      }
      
      // Add new negative constraints
      for (final constraint in _negativeConstraints) {
        await _db.addMediaMatchingConstraint(dbMediaType, constraint, false);
      }
      
      debugPrint('✅ [CONSTRAINTS-SAVE] Saved +${_positiveConstraints.length} positive, -${_negativeConstraints.length} negative constraints');
    } catch (e) {
      debugPrint('❌ [CONSTRAINTS-SAVE] Error saving matching constraints: $e');
    }
  }

  /// Clear existing priority titles and save new ones
  Future<void> _clearAndSavePriorityTitles() async {
    try {
      // For now, just add new ones - the database handles uniqueness
      // In a full implementation, you'd want to create media items first
      // and then reference them in the priority titles table
      
      // This is a simplified approach - in reality you'd want to:
      // 1. Create or find media items for each title
      // 2. Add them to the priority titles table with proper media_item_id references
      
      debugPrint('Priority titles saving simplified - needs full implementation with media item creation');
    } catch (e) {
      debugPrint('Error saving priority titles: $e');
    }
  }

  void _addConstraintToList(String constraint, bool isPositive) {
    final targetList = isPositive ? _positiveConstraints : _negativeConstraints;
    if (constraint.isNotEmpty && !targetList.contains(constraint)) {
      setState(() {
        targetList.add(constraint);
      });
      _saveSettings(); // Save immediately when constraints change
    }
  }

  void _showIncludeExcludeDialog(String item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        title: Text(
          'Add "$item"',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Would you like to include or exclude this constraint?',
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _addConstraintToList(item, true);
            },
            icon: Icon(Icons.thumb_up_outlined, color: AppTheme.includeColor, size: 18),
            label: Text(
              'Include',
              style: TextStyle(color: AppTheme.includeColor),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _addConstraintToList(item, false);
            },
            icon: Icon(Icons.thumb_down_outlined, color: AppTheme.excludeColor, size: 18),
            label: Text(
              'Exclude',
              style: TextStyle(color: AppTheme.excludeColor),
            ),
          ),
        ],
      ),
    );
  }

  void _removePositiveConstraint(int index) {
    setState(() {
      _positiveConstraints.removeAt(index);
    });
    _saveSettings(); // Save immediately when constraints change
  }

  void _removeNegativeConstraint(int index) {
    setState(() {
      _negativeConstraints.removeAt(index);
    });
    _saveSettings(); // Save immediately when constraints change
  }

  void _addPriorityTitle(String title) {
    if (title.isNotEmpty && !_priorityTitles.contains(title)) {
      setState(() {
        _priorityTitles.add(title);
      });
      _saveSettings(); // Save immediately when titles change
    }
  }

  void _addAvoidTitle(String title) {
    if (title.isNotEmpty && !_avoidTitles.contains(title)) {
      setState(() {
        _avoidTitles.add(title);
      });
      _saveSettings(); // Save immediately when titles change
    }
  }

  void _removePriorityTitle(int index) {
    setState(() {
      _priorityTitles.removeAt(index);
    });
    _saveSettings(); // Save immediately when titles change
  }

  void _removeAvoidTitle(int index) {
    setState(() {
      _avoidTitles.removeAt(index);
    });
    _saveSettings(); // Save immediately when titles change
  }

  String _getCurrentSimilarityLabel() {
    // Find the closest match instead of defaulting to 'Custom'
    double closestKey = 0.5;
    double smallestDiff = double.infinity;
    
    for (double key in _similarityLabels.keys) {
      double diff = (_similarityThreshold - key).abs();
      if (diff < smallestDiff) {
        smallestDiff = diff;
        closestKey = key;
      }
    }
    
    return _similarityLabels[closestKey] ?? 'Versatile';
  }

  String _getCurrentSimilarityDescription() {
    final currentLabel = _getCurrentSimilarityLabel();
    
    switch (currentLabel) {
      case 'Bohemian':
        return 'Surprise me with unexpected gems! Casts a wide net for diverse discoveries across genres and themes.';
      case 'Eclectic':
        return 'Keep things interesting with varied but related picks. Explores different corners while staying connected.';
      case 'Versatile':
        return 'Balanced recommendations that mix familiar and fresh. The perfect middle ground for discovery.';
      case 'Discerning':
        return 'Stay on theme with focused picks that closely match your current mood and preferences.';
      case 'Meticulous':
        return 'Laser-focused precision matching. Only suggestions that align perfectly with your exact tastes.';
      default:
        return 'Custom similarity setting for personalized matching precision.';
    }
  }

  void _showTitleSelectionModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => TitleSelectionModal(
        mediaType: widget.mediaType,
        onPrioritySelected: (title) {
          _addPriorityTitle(title);
          Navigator.of(context).pop();
        },
        onAvoidSelected: (title) {
          _addAvoidTitle(title);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _buildModernSlider() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SIMILARITY MATCHING',
                style: TextStyle(
                  color: AppTheme.primaryColor.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getCurrentSimilarityLabel(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12), // Align with title text
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppTheme.primaryColor,
                inactiveTrackColor: Colors.white.withOpacity(0.1),
                thumbColor: AppTheme.primaryColor,
                overlayColor: AppTheme.primaryColor.withOpacity(0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                trackHeight: 4,
              ),
              child: Slider(
                value: _similarityThreshold,
                min: 0.1,
                max: 1.0,
                divisions: 4,
                onChanged: (value) {
                  setState(() => _similarityThreshold = value);
                  _saveSettings(); // Save immediately when slider changes
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Simple description blurb for current similarity level
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _getCurrentSimilarityDescription(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomConstraints() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INCLUDE/EXCLUDE MATCHING',
            style: TextStyle(
              color: AppTheme.primaryColor.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add criteria to explicitly match or avoid',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          
          // Themes search section
          Row(
            children: [
              Expanded(
                child: AutocompleteSearch(
                  mediaType: widget.mediaType,
                  searchType: 'themes',
                  hintText: 'Search themes (e.g., "industrial")',
                  existingItems: [..._positiveConstraints, ..._negativeConstraints],
                  onSelected: (theme) => _showIncludeExcludeDialog(theme),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Genres search section  
          Row(
            children: [
              Expanded(
                child: AutocompleteSearch(
                  mediaType: widget.mediaType,
                  searchType: 'genres',
                  hintText: 'Search genres (e.g., "rock")',
                  existingItems: [..._positiveConstraints, ..._negativeConstraints],
                  onSelected: (genre) => _showIncludeExcludeDialog(genre),
                ),
              ),
            ],
          ),
          // Only show columns if there are items
          if (_positiveConstraints.isNotEmpty || _negativeConstraints.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Include column (only show if has items)
                if (_positiveConstraints.isNotEmpty) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INCLUDE',
                          style: TextStyle(
                            color: AppTheme.includeColor.withOpacity(0.9), // Use theme color
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...(_positiveConstraints.asMap().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removePositiveConstraint(entry.key),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList()),
                      ],
                    ),
                  ),
                ],
                // Spacer between columns (only if both exist)
                if (_positiveConstraints.isNotEmpty && _negativeConstraints.isNotEmpty)
                  const SizedBox(width: 24),
                // Exclude column (only show if has items)
                if (_negativeConstraints.isNotEmpty) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EXCLUDE',
                          style: TextStyle(
                            color: AppTheme.excludeColor.withOpacity(0.9), // Use theme color
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...(_negativeConstraints.asMap().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removeNegativeConstraint(entry.key),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList()),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecificTitles() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PRIORITY TITLES',
            style: TextStyle(
              color: AppTheme.primaryColor.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select from history to prioritize or avoid',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          
          // Button to open selection modal
          OutlinedButton(
            onPressed: () => _showTitleSelectionModal(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(color: AppTheme.primaryColor),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 18),
                const SizedBox(width: 8),
                Transform.scale(
                  scaleX: 0.9,
                  scaleY: 1.05,
                  child: Text(
                    'SELECT FROM HISTORY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w200,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Only show columns if there are titles
          if (_priorityTitles.isNotEmpty || _avoidTitles.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Priority column (only show if has titles)
                if (_priorityTitles.isNotEmpty) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRIORITIZE',
                          style: TextStyle(
                            color: const Color(0xFF4DD0E1).withOpacity(0.9), // Turquoise
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...(_priorityTitles.asMap().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removePriorityTitle(entry.key),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList()),
                      ],
                    ),
                  ),
                ],
                // Spacer between columns (only if both exist)
                if (_priorityTitles.isNotEmpty && _avoidTitles.isNotEmpty)
                  const SizedBox(width: 24),
                // Avoid column (only show if has titles)
                if (_avoidTitles.isNotEmpty) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AVOID',
                          style: TextStyle(
                            color: const Color(0xFFBA68C8).withOpacity(0.9), // Red-violet
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...(_avoidTitles.asMap().entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removeAvoidTitle(entry.key),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList()),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildModernSlider(),
            const SizedBox(height: 16),
            _buildCustomConstraints(),
            const SizedBox(height: 16),
            _buildSpecificTitles(),
          ],
        ),
      ),
    );
  }
}

/// Modal for selecting titles from media history
class TitleSelectionModal extends StatefulWidget {
  final String mediaType;
  final Function(String) onPrioritySelected;
  final Function(String) onAvoidSelected;

  const TitleSelectionModal({
    Key? key,
    required this.mediaType,
    required this.onPrioritySelected,
    required this.onAvoidSelected,
  }) : super(key: key);

  @override
  _TitleSelectionModalState createState() => _TitleSelectionModalState();
}

class _TitleSelectionModalState extends State<TitleSelectionModal> {
  List<Map<String, dynamic>> _historyItems = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final SQLiteDatabase _db = SQLiteDatabase();

  @override
  void initState() {
    super.initState();
    _loadHistoryItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistoryItems() async {
    try {
      await _db.init();
      
      // Convert header media type to database media type using enum
      String dbMediaType = widget.mediaType;
      try {
        final mediaType = MediaType.fromHeaderName(widget.mediaType);
        dbMediaType = mediaType.databaseName;
      } catch (e) {
        debugPrint('❌ [MEDIA-TYPE] Unknown media type in TitleSelectionModal: ${widget.mediaType}');
      }
      
      // Load real data from database - combine favorited and liked items
      final favorited = await _db.getAllFavorites(dbMediaType);
      final liked = await _db.getLikedRecommendations(dbMediaType);
      
      final allItems = <Map<String, dynamic>>[];
      
      // Add favorited items
      for (final item in favorited) {
        allItems.add({
          'title': item.title ?? 'Unknown Title',
          'artist': item.artist ?? 'Unknown Artist',
          'type': 'favorite',
          'mediaItemId': item.mediaItemId,
        });
      }
      
      // Add liked items that aren't already favorites
      for (final item in liked) {
        if (!allItems.any((existing) => existing['mediaItemId'] == item.mediaItemId)) {
          allItems.add({
            'title': item.title ?? 'Unknown Title',
            'artist': item.artist ?? 'Unknown Artist',
            'type': 'liked',
            'mediaItemId': item.mediaItemId,
          });
        }
      }
      
      setState(() {
        _historyItems = allItems;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading history items: $e');
      setState(() {
        _historyItems = [];
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_searchQuery.isEmpty) {
      return _historyItems;
    }
    return _historyItems.where((item) {
      final title = (item['title'] as String).toLowerCase();
      final artist = (item['artist'] as String? ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || artist.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.7, // Narrower modal
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${widget.mediaType.toUpperCase()} HISTORY',
                        style: TextStyle(
                          color: AppTheme.primaryColor.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.0,
                        ),
                      ),
                      StandardCloseButton(
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search titles...',
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
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withOpacity(0.5),
                        size: 20,
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : _filteredItems.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isEmpty 
                                ? 'No ${widget.mediaType} history found'
                                : 'No results for "$_searchQuery"',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final title = item['title'] as String;
                            final artist = item['artist'] as String?;
                            final type = item['type'] as String;
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Type indicator
                                  Container(
                                    width: 4,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: type == 'favorite' 
                                          ? AppTheme.primaryColor
                                          : const Color(0xFF4DD0E1),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // Title and artist
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (artist != null && artist.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            artist,
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.6),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  
                                  // Action buttons
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () => widget.onPrioritySelected(title),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.thumb_up_outlined,
                                            color: AppTheme.includeColor,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => widget.onAvoidSelected(title),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.thumb_down_outlined,
                                            color: AppTheme.excludeColor,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
} 