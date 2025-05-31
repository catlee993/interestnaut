/// Constants related to AI models used in the application

const String kLlamaModelFileName = "Meta-Llama-3-7B-29Layers.Q4_K_S.gguf";

/// Directory name where models are stored
const String kModelsDirectoryName = "models"; 

/// Prompt templates for media recommendations
/// Each template includes JSON schema validation and placeholders for previous suggestions

/// Music recommendation prompt template
const String kMusicPromptTemplate = r'''
Previous songs: {PREVIOUS_RECOMMENDATIONS}

New song:
Song Title
Artist Name
Why good
''';

/// Movie recommendation prompt template
const String kMoviePromptTemplate = r'''
Previous movies: {PREVIOUS_RECOMMENDATIONS}

New movie:
Movie Title
Director Name
Why good
''';

/// Book recommendation prompt template
const String kBookPromptTemplate = r'''
Previous books: {PREVIOUS_RECOMMENDATIONS}

New book:
Book Title
Author Name
Why good
''';

/// TV Show recommendation prompt template
const String kTVShowPromptTemplate = r'''
Name a great TV show. Format as JSON:
{"title":"Show Title","network":"Network","reasoning":"Why it's good"}
''';

/// Video Game recommendation prompt template
const String kVideoGamePromptTemplate = r'''
Name a great video game. Format as JSON:
{"title":"Game Title","developer":"Developer","reasoning":"Why it's good"}
''';

/// Get the appropriate prompt template for a specific media type
String getPromptTemplateForMediaType(String mediaType) {
  switch (mediaType.toLowerCase()) {
    case 'music':
      return kMusicPromptTemplate;
    case 'movie':
      return kMoviePromptTemplate;
    case 'book':
      return kBookPromptTemplate;
    case 'tv_show':
    case 'tvshow':
    case 'tv show':
    case 'show':
      return kTVShowPromptTemplate;
    case 'video_game':
    case 'videogame':
    case 'video game':
    case 'game':
      return kVideoGamePromptTemplate;
    default:
      throw ArgumentError('Unsupported media type: $mediaType');
  }
}

/// Format a prompt template with previous suggestions
String formatPromptWithPreviousSuggestions(String template, List<String> previousSuggestions) {
  if (previousSuggestions.isEmpty) {
    return template;
  } else {
    final formattedSuggestions = previousSuggestions.join('\n\n');
    final previousSuggestionsSection = '''
### Previous Suggestions:
$formattedSuggestions

''';
    // Insert before the Instruction section
    return template.replaceFirst('### Instruction:', '$previousSuggestionsSection### Instruction:');
  }
}
