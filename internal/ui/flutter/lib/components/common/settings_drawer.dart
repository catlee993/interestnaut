import 'package:flutter/material.dart';
import 'settings_tab_bar.dart';
import 'section_container.dart';
import 'api_credentials_manager.dart';
import 'llm_provider_selector.dart';
import 'model_selector.dart';
import 'continuous_playback_switch.dart';

class SettingsDrawer extends StatefulWidget {
  final bool open;
  final VoidCallback onClose;

  const SettingsDrawer({
    Key? key,
    required this.open,
    required this.onClose,
  }) : super(key: key);

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> with SingleTickerProviderStateMixin {
  int _tabIndex = 0;
  String _llmProvider = 'openai';
  String _chatModel = 'gpt-4o';
  String _geminiModel = 'gemini-1.5-pro';
  bool _continuousPlayback = false;
  String _openAIKey = '';
  String _geminiKey = '';
  String _tmdbKey = '';
  String _rawgKey = '';

  @override
  Widget build(BuildContext context) {
    if (!widget.open) return SizedBox.shrink();
    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onClose,
          child: Container(
            color: Colors.black.withOpacity(0.4),
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 400,
            height: double.infinity,
            color: Color.fromRGBO(18, 18, 18, 0.95),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                  SettingsTabBar(
                    currentIndex: _tabIndex,
                    onChanged: (i) => setState(() => _tabIndex = i),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: _tabIndex == 0
                        ? ListView(
                            children: [
                              ContinuousPlaybackSwitch(
                                value: _continuousPlayback,
                                onChanged: (v) => setState(() => _continuousPlayback = v),
                              ),
                              const SizedBox(height: 16),
                              LLMProviderSelector(
                                value: _llmProvider,
                                onChanged: (v) => setState(() => _llmProvider = v),
                              ),
                              const SizedBox(height: 16),
                              if (_llmProvider == 'openai')
                                ModelSelector(
                                  provider: 'openai',
                                  value: _chatModel,
                                  onChanged: (v) => setState(() => _chatModel = v),
                                ),
                              if (_llmProvider == 'gemini')
                                ModelSelector(
                                  provider: 'gemini',
                                  value: _geminiModel,
                                  onChanged: (v) => setState(() => _geminiModel = v),
                                ),
                            ],
                          )
                        : ListView(
                            children: [
                              SectionContainer(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    BorderedSectionTitle('LLM APIs'),
                                    const SizedBox(height: 12),
                                    ApiCredentialsManager(
                                      label: 'OpenAI',
                                      value: _openAIKey,
                                      onChange: (v) async => setState(() => _openAIKey = v),
                                      onClear: () async => setState(() => _openAIKey = ''),
                                    ),
                                    const SizedBox(height: 12),
                                    ApiCredentialsManager(
                                      label: 'Gemini',
                                      value: _geminiKey,
                                      onChange: (v) async => setState(() => _geminiKey = v),
                                      onClear: () async => setState(() => _geminiKey = ''),
                                    ),
                                  ],
                                ),
                              ),
                              SectionContainer(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    BorderedSectionTitle('Media APIs'),
                                    const SizedBox(height: 12),
                                    ApiCredentialsManager(
                                      label: 'TMDB',
                                      value: _tmdbKey,
                                      onChange: (v) async => setState(() => _tmdbKey = v),
                                      onClear: () async => setState(() => _tmdbKey = ''),
                                    ),
                                    const SizedBox(height: 12),
                                    ApiCredentialsManager(
                                      label: 'RAWG',
                                      value: _rawgKey,
                                      onChange: (v) async => setState(() => _rawgKey = v),
                                      onClear: () async => setState(() => _rawgKey = ''),
                                      placeholderText: 'For video game information',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
} 