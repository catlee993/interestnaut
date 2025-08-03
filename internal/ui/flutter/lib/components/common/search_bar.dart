import 'package:flutter/material.dart';
import 'dart:async';
import 'standard_close_button.dart';

class SearchBar extends StatefulWidget {
  final String placeholder;
  final void Function(String) onSearch;
  final VoidCallback? onClear;
  final int debounceTime;
  final TextStyle? style;
  final String initialValue;

  const SearchBar({
    Key? key,
    required this.placeholder,
    required this.onSearch,
    this.onClear,
    this.debounceTime = 500,
    this.style,
    this.initialValue = '',
  }) : super(key: key);

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounce;
  String _lastSearch = '';
  late final String _focusNodeId;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    // Create focus node with unique debug label to help identify conflicts
    _focusNodeId = 'SearchBar_${widget.placeholder}_${DateTime.now().millisecondsSinceEpoch}';
    _focusNode = FocusNode(debugLabel: _focusNodeId);
    _lastSearch = widget.initialValue;
    
    // If there's an initial value, notify the search handler after build completes
    if (widget.initialValue.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSearch(widget.initialValue);
      });
    }
  }

  @override
  void didUpdateWidget(SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller if initialValue changes externally
    if (widget.initialValue != oldWidget.initialValue && 
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
      _lastSearch = widget.initialValue;
    }
  }
  
  @override
  void dispose() {
    debugPrint('🗑️ Disposing SearchBar with focus node: $_focusNodeId');
    _debounce?.cancel();
    _controller.dispose();
    // Unfocus before disposing to ensure proper cleanup
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (value == _lastSearch) return;
    
    // Update UI to show/hide clear button
    setState(() {});
    
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
    // Only request focus if this widget is still mounted and the focus node is available
    if (mounted && !_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
    setState(() {});
  }

  void _onSubmitted(String value) {
    _debounce?.cancel();
    if (value != _lastSearch) {
      _lastSearch = value;
      widget.onSearch(value);
    }
    // Unfocus after submission to prevent keyboard events from sticking
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
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
          // Clear button (X) - only show when there's text
          if (_controller.text.isNotEmpty)
            Positioned(
              right: 0,
              child: StandardCloseButton(
                onPressed: _handleClear,
                size: 16,
                padding: const EdgeInsets.all(4),
              ),
            ),
        ],
      ),
    );
  }
}

