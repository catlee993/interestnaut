/// Constants related to AI models used in the application

const String kLlamaModelFileName = "Meta-Llama-3-7B-29Layers.Q4_K_S.gguf";

/// Directory name where models are stored
const String kModelsDirectoryName = "models"; 

/// Prompt templates for media recommendations
/// Each template includes JSON schema validation and placeholders for previous suggestions

/// Music recommendation prompt template
const String kMusicPromptTemplate = r'''
<|begin_of_text|><|start_header_id|>system<|end_header_id|>

You are a knowledgeable music curator. Your task is to recommend REAL songs that actually exist. You must respond with valid JSON containing exactly one song recommendation.

<|eot_id|><|start_header_id|>user<|end_header_id|>

Generate exactly one song recommendation in this JSON format:
{
  "title": "actual song title",
  "artist": "actual artist name", 
  "reasoning": "brief explanation under 80 characters"
}

Requirements:
- Must be a REAL song that exists
- Include actual artist and song title
- Keep reasoning under 80 characters
- No additional text or markdown
- Respond only with valid JSON

### Instruction:
Recommend one real song that exists. Focus on quality tracks from well-known or critically acclaimed artists.

<|eot_id|><|start_header_id|>assistant<|end_header_id|>

''';

/// Movie recommendation prompt template
const String kMoviePromptTemplate = r'''
<|begin_of_text|><|start_header_id|>system<|end_header_id|>

You are a knowledgeable movie critic. Your task is to recommend REAL movies that actually exist. You must respond with valid JSON containing exactly one movie recommendation.

<|eot_id|><|start_header_id|>user<|end_header_id|>

Generate exactly one movie recommendation in this JSON format:
{
  "title": "actual movie title",
  "director": "actual director name",
  "reasoning": "brief explanation under 80 characters"
}

Requirements:
- Must be a REAL movie that exists
- Include actual director and movie title
- Keep reasoning under 80 characters
- No additional text or markdown
- Respond only with valid JSON

### Instruction:
Recommend one real movie that exists. Focus on quality films from well-known or critically acclaimed directors.

<|eot_id|><|start_header_id|>assistant<|end_header_id|>

''';

/// Book recommendation prompt template
const String kBookPromptTemplate = r'''
<|begin_of_text|><|start_header_id|>system<|end_header_id|>

You are a knowledgeable librarian. Your task is to recommend REAL books that actually exist. You must respond with valid JSON containing exactly one book recommendation.

<|eot_id|><|start_header_id|>user<|end_header_id|>

Generate exactly one book recommendation in this JSON format:
{
  "title": "actual book title",
  "author": "actual author name",
  "reasoning": "brief explanation under 80 characters"
}

Requirements:
- Must be a REAL book that exists
- Include actual author and book title
- Keep reasoning under 80 characters
- No additional text or markdown
- Respond only with valid JSON

### Instruction:
Recommend one real book that exists. Focus on quality books from well-known or critically acclaimed authors.

<|eot_id|><|start_header_id|>assistant<|end_header_id|>

''';

/// TV Show recommendation prompt template
const String kTVShowPromptTemplate = r'''
<|begin_of_text|><|start_header_id|>system<|end_header_id|>

You are a knowledgeable TV critic. Your task is to recommend REAL TV shows that actually exist. You must respond with valid JSON containing exactly one TV show recommendation.

<|eot_id|><|start_header_id|>user<|end_header_id|>

Generate exactly one TV show recommendation in this JSON format:
{
  "title": "actual TV show title",
  "network": "actual network or streaming service",
  "reasoning": "brief explanation under 80 characters"
}

Requirements:
- Must be a REAL TV show that exists
- Include actual network/streaming service and show title
- Keep reasoning under 80 characters
- No additional text or markdown
- Respond only with valid JSON

### Instruction:
Recommend one real TV show that exists. Focus on quality shows from well-known networks or streaming services.

<|eot_id|><|start_header_id|>assistant<|end_header_id|>

''';

/// Video Game recommendation prompt template
const String kVideoGamePromptTemplate = r'''
<|begin_of_text|><|start_header_id|>system<|end_header_id|>

You are a knowledgeable gaming expert. Your task is to recommend REAL video games that actually exist. You must respond with valid JSON containing exactly one video game recommendation.

<|eot_id|><|start_header_id|>user<|end_header_id|>

Generate exactly one video game recommendation in this JSON format:
{
  "title": "actual game title",
  "developer": "actual developer name",
  "reasoning": "brief explanation under 80 characters"
}

Requirements:
- Must be a REAL video game that exists
- Include actual developer and game title
- Keep reasoning under 80 characters
- No additional text or markdown
- Respond only with valid JSON

### Instruction:
Recommend one real video game that exists. Focus on quality games from well-known or critically acclaimed developers.

<|eot_id|><|start_header_id|>assistant<|end_header_id|>

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
