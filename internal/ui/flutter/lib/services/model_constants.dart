/// Constants related to AI models used in the application

const String kLlamaModelFileName = "Meta-Llama-3-7B-29Layers.Q4_K_S.gguf";

/// TinyLlama model filename for mobile inference
const String kTinyLlamaModelFileName = "tinyllama-1.1b-chat-q4_0.gguf";

/// Directory name where models are stored
const String kModelsDirectoryName = "models"; 

/// Prompt templates for media recommendations
/// Each template includes JSON schema validation and placeholders for previous suggestions

/// Music recommendation prompt template
const String kMusicPromptTemplate = r'''
Task: Recommend a song.

Format:
[Song Title]
[Artist Name]
[Why this song is worth listening to - complete sentence]

Example:
Wonderwall
Oasis
A timeless britpop anthem with memorable lyrics and acoustic guitar that became a generational anthem.

Your recommendation:
''';

/// Movie recommendation prompt template
const String kMoviePromptTemplate = r'''
Task: Recommend a movie.

Format:
[Movie Title]
[Director Name]
[Why this movie is worth watching - complete sentence]

Example:
Inception
Christopher Nolan
A mind-bending sci-fi thriller that explores dreams within dreams with stunning visual effects and a complex narrative.

Your recommendation:
''';

/// Book recommendation prompt template
const String kBookPromptTemplate = r'''
Task: Recommend a book.

Format:
[Book Title]
[Author Name]
[Why this book is worth reading - complete sentence]

Example:
1984
George Orwell
A dystopian masterpiece that explores totalitarian control and remains eerily relevant to modern surveillance society.

Your recommendation:
''';

/// TV Show recommendation prompt template
const String kTVShowPromptTemplate = r'''
Task: Recommend a TV show.

Format:
[Show Title]
[Network/Platform Name]
[Why this show is worth watching - complete sentence]

Example:
Breaking Bad
AMC
A gripping crime drama that chronicles one man's transformation from high school teacher to drug kingpin.

Your recommendation:
''';

/// Video Game recommendation prompt template
const String kVideoGamePromptTemplate = r'''
Task: Recommend a video game.

Format:
[Game Title]
[Developer Studio]
[Why this game is worth playing - complete sentence]

Example:
The Witcher 3
CD Projekt RED
An epic open-world RPG with rich storytelling, memorable characters, and hundreds of hours of engaging content.

Your recommendation:
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
