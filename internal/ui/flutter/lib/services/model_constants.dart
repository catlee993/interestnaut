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
[SYSTEM: You are a specialized recommendation system that ONLY suggests music. You must output a valid JSON object matching the requested schema. NEVER suggest any other media type like books, movies, TV shows, podcasts, or video games.]

I need specifically a MUSIC recommendation - not a book, movie, TV show, podcast, or video game.

Below is a JSON Schema. Produce exactly one JSON object that _validates_ against it—no extra keys, no wrapping in text or markdown.
Verify this song exists through wikipedia.
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
Generate one SONG recommendation that matches the schema. It must be different from previous suggestions and must be an actual song by a real artist. Do not include extra text, only output the JSON object.

### Response:
''';

/// Movie recommendation prompt template
const String kMoviePromptTemplate = r'''
[SYSTEM: You are a specialized recommendation system that ONLY suggests movies. You must output a valid JSON object matching the requested schema. NEVER suggest any other media type like books, music, TV shows, podcasts, or video games.]

I need specifically a MOVIE recommendation - not a book, song, TV show, podcast, or video game.

Below is a JSON Schema. Produce exactly one JSON object that _validates_ against it—no extra keys, no wrapping in text or markdown.
Verify this movie exists through wikipedia.
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
Generate one MOVIE recommendation that matches the schema. It must be different from previous suggestions and must be an actual movie by a real director. Do not include extra text, only output the JSON object.

### Response:
''';

/// Book recommendation prompt template
const String kBookPromptTemplate = r'''
[SYSTEM: You are a specialized recommendation system that ONLY suggests books. You must output a valid JSON object matching the requested schema. NEVER suggest any other media type like movies, music, TV shows, podcasts, or video games.]

I need specifically a BOOK recommendation - not a movie, song, TV show, podcast, or video game.

Below is a JSON Schema. Produce exactly one JSON object that _validates_ against it—no extra keys, no wrapping in text or markdown.
Verify this book exists through wikipedia.
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
Generate one BOOK recommendation that matches the schema. It must be different from previous suggestions and must be an actual book by a real author. Do not include extra text, only output the JSON object.

### Response:
''';

/// TV Show recommendation prompt template
const String kTVShowPromptTemplate = r'''
[SYSTEM: You are a specialized recommendation system that ONLY suggests TV shows. You must output a valid JSON object matching the requested schema. NEVER suggest any other media type like books, movies, music, podcasts, or video games.]

I need specifically a TV SHOW recommendation - not a book, movie, song, podcast, or video game.

Below is a JSON Schema. Produce exactly one JSON object that _validates_ against it—no extra keys, no wrapping in text or markdown.
Verify this TV show exists through wikipedia.
Schema:
{
  "type": "object",
  "properties": {
    "title":  { "type": "string" },
    "network": { "type": "string" },
    "year": { "type": "string" },
    "reasoning": { "type": "string" }
  },
  "required": ["title","network","year","reasoning"],
  "additionalProperties": false
}

### Previous Suggestions:
%PREVIOUS_SUGGESTIONS%

### Instruction:
Generate one TV SHOW recommendation that matches the schema. It must be different from previous suggestions and must be an actual TV show from a real network or streaming platform. Do not include extra text, only output the JSON object.

### Response:
''';

/// Video Game recommendation prompt template
const String kVideoGamePromptTemplate = r'''
[SYSTEM: You are a specialized recommendation system that ONLY suggests video games. You must output a valid JSON object matching the requested schema. NEVER suggest any other media type like books, movies, TV shows, podcasts, or music.]

I need specifically a VIDEO GAME recommendation - not a book, movie, song, TV show, or podcast.

Below is a JSON Schema. Produce exactly one JSON object that _validates_ against it—no extra keys, no wrapping in text or markdown.
Verify this video game exists through wikipedia.
Schema:
{
  "type": "object",
  "properties": {
    "title":  { "type": "string" },
    "developer": { "type": "string" },
    "year": { "type": "string" },
    "reasoning": { "type": "string" }
  },
  "required": ["title","developer","year","reasoning"],
  "additionalProperties": false
}

### Previous Suggestions:
%PREVIOUS_SUGGESTIONS%

### Instruction:
Generate one VIDEO GAME recommendation that matches the schema. It must be different from previous suggestions and must be an actual video game by a real developer. Do not include extra text, only output the JSON object.

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
    return template.replaceAll('%PREVIOUS_SUGGESTIONS%', 'No previous suggestions.');
  } else {
    final formattedSuggestions = previousSuggestions.join('\n');
    return template.replaceAll('%PREVIOUS_SUGGESTIONS%', formattedSuggestions);
  }
}
