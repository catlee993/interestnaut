import 'package:flutter/material.dart';

class LLMProviderSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const LLMProviderSelector({
    Key? key,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      decoration: InputDecoration(
        labelText: 'LLM Provider',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color.fromRGBO(123, 104, 238, 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      dropdownColor: Color.fromRGBO(30, 30, 30, 0.95),
      style: TextStyle(color: Colors.white),
      items: const [
        DropdownMenuItem(value: 'openai', child: Text('OpenAI (Default)')),
        DropdownMenuItem(value: 'gemini', child: Text('Google Gemini')),
      ],
    );
  }
} 