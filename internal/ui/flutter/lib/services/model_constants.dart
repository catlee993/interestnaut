/// Constants related to AI models used in the application

/// The filename for the Mistral model
const String kMistralModelFileName = "Mistral-7B-Instruct-v0.3-q4_1.gguf";

const String kLlamaModelFileName = "Meta-Llama-3-7B-29Layers.Q4_K_S.gguf";

/// Directory name where models are stored
const String kModelsDirectoryName = "models"; 

/// Prompt templates for media recommendations
/// Each template includes JSON schema validation and placeholders for previous suggestions

/// Music recommendation prompt template
const String kMusicPromptTemplate = r'''
Below is a JSON Schema. Produce exactly one JSON object that _validates_ against it—no extra keys, no wrapping in text or markdown.
Verify this title exists through wikipedia.
Schema:
{
  "type": "object",
  "properties": {
    "title":  { "type": "string" },
    "artist": { "type": "string" },
    "album":  { "type": "string" },
    "reasoning": { "type": "string" }
  },
  "required": ["title","artist","album","reasoning"],
  "additionalProperties": false
}

### Previous Suggestions:
%PREVIOUS_SUGGESTIONS%

### Instruction:
Generate one song recommendation that matches the schema. It must be different from previous suggestions.

### Response:
''';

/// Movie recommendation prompt template
const String kMoviePromptTemplate = r'''
Below is a JSON Schema. Produce exactly one JSON object that _validates_ against it—no extra keys, no wrapping in text or markdown.
Verify this title exists through wikipedia.
Schema:
{
  "type": "object",
  "properties": {
    "title":  { "type": "string" },
    "director": { "type": "string" },
    "year": { "type": "string" },
    "reasoning": { "type": "string" }
  },
  "required": ["title","director","year","reasoning"],
  "additionalProperties": false
}

### Previous Suggestions:
%PREVIOUS_SUGGESTIONS%

### Instruction:
Generate one movie recommendation that matches the schema. It must be different from previous suggestions.

### Response:
''';

/// Book recommendation prompt template
const String kBookPromptTemplate = r'''
Below is a JSON Schema. Produce exactly one JSON object that _validates_ against it—no extra keys, no wrapping in text or markdown.
Verify this title exists through wikipedia.
Schema:
{
  "type": "object",
  "properties": {
    "title":  { "type": "string" },
    "author": { "type": "string" },
    "year": { "type": "string" },
    "reasoning": { "type": "string" }
  },
  "required": ["title","author","year","reasoning"],
  "additionalProperties": false
}

### Previous Suggestions:
%PREVIOUS_SUGGESTIONS%

### Instruction:
Generate one book recommendation that matches the schema. It must be different from previous suggestions.

### Response:
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
    default:
      throw ArgumentError('Unsupported media type: $mediaType');
  }
}

/// Format a prompt template with previous suggestions
String formatPromptWithPreviousSuggestions(String template, List<String> previousSuggestions) {
  if (previousSuggestions.isEmpty) {
    return template.replaceAll('%PREVIOUS_SUGGESTIONS%', 'No previous suggestions.');
  } else {
    final formattedSuggestions = previousSuggestions.join('\n');
    return template.replaceAll('%PREVIOUS_SUGGESTIONS%', formattedSuggestions);
  }
}
