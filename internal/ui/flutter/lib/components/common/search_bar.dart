import 'package:flutter/material.dart';
import 'dart:async';
import '../../theme.dart';

class SearchBar extends StatefulWidget {
  final String placeholder;
  final void Function(String) onSearch;
  final VoidCallback? onClear;
  final int debounceTime;
  final TextStyle? style;

  const SearchBar({
    Key? key,
    required this.placeholder,
    required this.onSearch,
    this.onClear,
    this.debounceTime = 500,
    this.style,
  }) : super(key: key);

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  String _lastSearch = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
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
    _focusNode.requestFocus();
    setState(() {});
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    if (value != _lastSearch) {
      _lastSearch = value;
      widget.onSearch(value);
    }
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color.fromRGBO(123, 104, 238, 0.5), width: 1),
        color: Colors.transparent,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 24.0),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              onChanged: _onChanged,
              onSubmitted: _onSubmitted,
              decoration: InputDecoration(
                hintText: widget.placeholder,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                hintStyle: const TextStyle(
                  color: Color.fromRGBO(255, 255, 255, 0.55),
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 2.0,
                  wordSpacing: 4.0,
                  fontFamily: 'Inter',
                ),
              ),
              style: widget.style ?? const TextStyle(
                color: Color.fromRGBO(255, 255, 255, 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w300,
                letterSpacing: 2.0,
                wordSpacing: 4.0,
                fontFamily: 'Inter',
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            Positioned(
              right: 8,
              top: 10,
              child: IconButton(
                icon: const Icon(Icons.clear, color: Color.fromRGBO(123, 104, 238, 0.7), size: 16),
                onPressed: _handleClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                splashRadius: 16,
                tooltip: 'Clear',
                style: IconButton.styleFrom(
                  hoverColor: const Color.fromRGBO(123, 104, 238, 0.1),
                  highlightColor: Colors.transparent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}