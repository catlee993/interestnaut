import 'package:flutter/material.dart';

class ApiCredentialsManager extends StatefulWidget {
  final String label;
  final String value;
  final Future<void> Function(String) onChange;
  final Future<void> Function() onClear;
  final String? placeholderText;
  final bool disabled;
  final Future<void> Function()? refreshHandler;

  const ApiCredentialsManager({
    Key? key,
    required this.label,
    required this.value,
    required this.onChange,
    required this.onClear,
    this.placeholderText,
    this.disabled = false,
    this.refreshHandler,
  }) : super(key: key);

  @override
  State<ApiCredentialsManager> createState() => _ApiCredentialsManagerState();
}

class _ApiCredentialsManagerState extends State<ApiCredentialsManager> {
  late TextEditingController _controller;
  bool _showApiKey = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(ApiCredentialsManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleChange(String value) async {
    setState(() => _loading = true);
    await widget.onChange(value);
    setState(() => _loading = false);
    if (widget.refreshHandler != null) await widget.refreshHandler!();
  }

  Future<void> _handleClear() async {
    setState(() => _loading = true);
    await widget.onClear();
    _controller.clear();
    setState(() => _loading = false);
    if (widget.refreshHandler != null) await widget.refreshHandler!();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            obscureText: !_showApiKey,
            enabled: !widget.disabled && !_loading,
            decoration: InputDecoration(
              labelText: '${widget.label} API Key',
              hintText: widget.placeholderText,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color.fromRGBO(123, 104, 238, 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color.fromRGBO(123, 104, 238, 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.white),
              ),
              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: TextStyle(color: Colors.white),
            onChanged: (v) => _handleChange(v),
          ),
        ),
        IconButton(
          icon: Icon(_showApiKey ? Icons.visibility_off : Icons.visibility, color: Colors.white),
          onPressed: widget.disabled ? null : () => setState(() => _showApiKey = !_showApiKey),
        ),
        IconButton(
          icon: Icon(Icons.clear, color: Colors.purple[300]),
          onPressed: (widget.disabled || _controller.text.isEmpty) ? null : _handleClear,
        ),
        if (_loading)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
      ],
    );
  }
} 