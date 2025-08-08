import 'package:flutter/material.dart';

class ModelSelector extends StatelessWidget {
  final String provider; // 'openai' or 'gemini'
  final String value;
  final ValueChanged<String> onChanged;

  const ModelSelector({
    Key? key,
    required this.provider,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<DropdownMenuItem<String>> items;
    if (provider == 'openai') {
      items = const [
        DropdownMenuItem(value: 'gpt-4o', child: Text('GPT-4o (Default)')),
        DropdownMenuItem(value: 'gpt-4', child: Text('GPT-4')),
        DropdownMenuItem(value: 'gpt-3.5-turbo', child: Text('GPT-3.5 Turbo')),
      ];
    } else {
      items = const [
        DropdownMenuItem(value: 'gemini-1.5-pro', child: Text('Gemini 1.5 Pro (Default)')),
        DropdownMenuItem(value: 'gemini-2.0-flash', child: Text('Gemini 2.0 Flash (Faster)')),
        DropdownMenuItem(value: 'gemini-2.0-flash-lite', child: Text('Gemini 2.0 Flash-Lite (Lightweight)')),
      ];
    }
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
      decoration: InputDecoration(
        labelText: provider == 'openai' ? 'ChatGPT Model' : 'Gemini Model',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color.fromRGBO(123, 104, 238, 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      dropdownColor: const Color.fromRGBO(30, 30, 30, 0.95),
      style: const TextStyle(color: Colors.white),
      items: items,
    );
  }
} 