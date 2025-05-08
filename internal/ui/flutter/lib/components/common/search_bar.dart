import 'package:flutter/material.dart';
import 'dart:async';

class SearchBar extends StatefulWidget {
  final String placeholder;
  final void Function(String) onSearch;
  final VoidCallback? onClear;
  final int debounceTime;

  const SearchBar({
    Key? key,
    required this.placeholder,
    required this.onSearch,
    this.onClear,
    this.debounceTime = 500,
  }) : super(key: key);

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _lastSearch = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (value == _lastSearch) return;
    if (value.isEmpty) {
      _lastSearch = '';
      widget.onSearch('');
      widget.onClear?.call();
      return;
    }
    _debounce = Timer(Duration(milliseconds: widget.debounceTime), () {
      if (value != _lastSearch) {
        _lastSearch = value;
        widget.onSearch(value);
      }
    });
  }

  void _handleClear() {
    _controller.clear();
    _debounce?.cancel();
    _lastSearch = '';
    widget.onSearch('');
    widget.onClear?.call();
    FocusScope.of(context).requestFocus(FocusNode());
    setState(() {});
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    if (value != _lastSearch) {
      _lastSearch = value;
      widget.onSearch(value);
    }
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          onSubmitted: _onSubmitted,
          decoration: InputDecoration(
            hintText: widget.placeholder,
            filled: true,
            fillColor: Colors.transparent,
            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color.fromRGBO(123, 104, 238, 0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color.fromRGBO(123, 104, 238, 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color.fromRGBO(123, 104, 238, 0.9)),
            ),
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14),
          ),
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        if (_controller.text.isNotEmpty)
          IconButton(
            icon: Icon(Icons.clear, color: Color.fromRGBO(123, 104, 238, 0.7)),
            onPressed: _handleClear,
            splashRadius: 18,
            tooltip: 'Clear',
            hoverColor: Color.fromRGBO(123, 104, 238, 0.1),
            highlightColor: Colors.transparent,
          ),
      ],
    );
  }
} 