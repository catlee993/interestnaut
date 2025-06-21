import 'package:flutter/material.dart';
import '../../services/sqlite_db.dart';

class UserConstraintsDialog extends StatefulWidget {
  const UserConstraintsDialog({Key? key}) : super(key: key);

  @override
  State<UserConstraintsDialog> createState() => _UserConstraintsDialogState();
}

class _UserConstraintsDialogState extends State<UserConstraintsDialog> {
  final SQLiteDatabase _db = SQLiteDatabase();
  final TextEditingController _constraintController = TextEditingController();
  
  List<Map<String, dynamic>> _constraints = [];
  List<Map<String, dynamic>> _mediaTypes = [];
  String? _selectedMediaType;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final constraints = await _db.getAllUserConstraints();
      final mediaTypes = await _db.getAllMediaTypes();
      
      setState(() {
        _constraints = constraints;
        _mediaTypes = mediaTypes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user constraints: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addConstraint() async {
    if (_constraintController.text.trim().isEmpty || _selectedMediaType == null) {
      return;
    }

    try {
      final success = await _db.addUserConstraint(
        _selectedMediaType!,
        _constraintController.text.trim(),
      );

      if (success) {
        _constraintController.clear();
        _selectedMediaType = null;
        await _loadData(); // Reload data
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Constraint added successfully!')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error adding constraint: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add constraint')),
        );
      }
    }
  }

  Future<void> _deleteConstraint(int constraintId) async {
    try {
      final success = await _db.deleteUserConstraint(constraintId);
      
      if (success) {
        await _loadData(); // Reload data
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Constraint deleted')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting constraint: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete constraint')),
        );
      }
    }
  }

  String _formatMediaType(String mediaType) {
    switch (mediaType) {
      case 'book':
        return 'Books';
      case 'music':
        return 'Music';
      case 'movie':
        return 'Movies';
      case 'tv_show':
        return 'TV Shows';
      case 'video_game':
        return 'Video Games';
      default:
        return mediaType.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'User Preferences',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Set preferences to customize your recommendations',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // Add new constraint section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add New Preference',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Media type dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedMediaType,
                      decoration: const InputDecoration(
                        labelText: 'Media Type',
                        border: OutlineInputBorder(),
                      ),
                      items: _mediaTypes.map((mediaType) {
                        final name = mediaType['name'] as String;
                        return DropdownMenuItem<String>(
                          value: name,
                          child: Text(_formatMediaType(name)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedMediaType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Constraint text field
                    TextField(
                      controller: _constraintController,
                      decoration: const InputDecoration(
                        labelText: 'Preference',
                        hintText: 'e.g., "no horror", "only sci-fi", "upbeat music"',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addConstraint(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Add button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addConstraint,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Preference'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B68EE),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Existing constraints list
            const Text(
              'Current Preferences',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _constraints.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.tune,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No preferences set yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add preferences to customize your recommendations',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _constraints.length,
                          itemBuilder: (context, index) {
                            final constraint = _constraints[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFF7B68EE),
                                  child: Text(
                                    _formatMediaType(constraint['media_type'])[0],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(constraint['value']),
                                subtitle: Text(
                                  _formatMediaType(constraint['media_type']),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                trailing: IconButton(
                                  onPressed: () => _deleteConstraint(constraint['id']),
                                  icon: const Icon(Icons.delete_outline),
                                  color: Colors.red[400],
                                ),
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

  @override
  void dispose() {
    _constraintController.dispose();
    super.dispose();
  }
} 