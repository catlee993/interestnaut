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

Schema:
{
  "type": "object",
  "properties": {
    "title":     { "type": "string", "maxLength": 80 },
    "artist":    { "type": "string", "maxLength": 80 },
    "album":     { "type": "string", "maxLength": 80 },
    "reasoning": { "type": "string", "maxLength": 80 }
  },
  "required": ["title","artist","album","reasoning"],
  "additionalProperties": false
}

### Instruction:
Generate one song recommendation that matches the schema.
IMPORTANT: Keep all string fields under 80 characters - especially the reasoning field.
80 characters is the maximum length for all string fields, THIS IS CRITICAL.

### Response:
''';

/// Movie recommendation prompt template
const String kMoviePromptTemplate = r'''
Below is a JSON Schema. Produce exactly one JSON object that _validates_ against it—no extra keys, no wrapping in text or markdown.

Schema:
{
  "type": "object",
  "properties": {
    "title":     { "type": "string", "maxLength": 80 },
    "director":  { "type": "string", "maxLength": 80 },
    "year":      { "type": "string" },
    "reasoning": { "type": "string", "maxLength": 80 }
  },
  "required": ["title","director","year","reasoning"],
  "additionalProperties": false
}

### Instruction:
Generate one movie recommendation that matches the schema.
IMPORTANT: Keep all string fields under 80 characters - especially the reasoning field.
80 characters is the maximum length for all string fields, THIS IS CRITICAL.

### Response:
''';

/// Book recommendation prompt template
const String kBookPromptTemplate = r'''
Below is a JSON Schema. Produce exactly one JSON object that _validates_ against it—no extra keys, no wrapping in text or markdown.

Schema:
{
  "type": "object",
  "properties": {
    "title":     { "type": "string", "maxLength": 80 },
    "author":    { "type": "string", "maxLength": 80 },
    "year":      { "type": "string" },
    "reasoning": { "type": "string", "maxLength": 80 }
  },
  "required": ["title","author","year","reasoning"],
  "additionalProperties": false
}

### Instruction:
Generate one book recommendation that matches the schema.
IMPORTANT: Keep all string fields under 80 characters - especially the reasoning field.
80 characters is the maximum length for all string fields, THIS IS CRITICAL.

### Response:
''';

/// TV Show recommendation prompt template
const String kTVShowPromptTemplate = r'''
Below is a JSON Schema. Produce exactly one JSON object that _validates_ against it—no extra keys, no wrapping in text or markdown.

Schema:
{
  "type": "object",
  "properties": {
    "title":     { "type": "string", "maxLength": 80 },
    "network":   { "type": "string", "maxLength": 80 },
    "year":      { "type": "string" },
    "reasoning": { "type": "string", "maxLength": 80 }
  },
  "required": ["title","network","year","reasoning"],
  "additionalProperties": false
}

### Instruction:
Generate one TV show recommendation that matches the schema.
IMPORTANT: Keep all string fields under 80 characters - especially the reasoning field.
80 characters is the maximum length for all string fields, THIS IS CRITICAL.

### Response:
''';

/// Video Game recommendation prompt template
const String kVideoGamePromptTemplate = r'''
Below is a JSON Schema. Produce exactly one JSON object that _validates_ against it—no extra keys, no wrapping in text or markdown.

Schema:
{
  "type": "object",
  "properties": {
    "title":     { "type": "string", "maxLength": 80 },
    "developer": { "type": "string", "maxLength": 80 },
    "year":      { "type": "string" },
    "reasoning": { "type": "string", "maxLength": 80 }
  },
  "required": ["title","developer","year","reasoning"],
  "additionalProperties": false
}

### Instruction:
Generate one video game recommendation that matches the schema.
IMPORTANT: Keep all string fields under 80 characters - especially the reasoning field.
80 characters is the maximum length for all string fields, THIS IS CRITICAL.

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
