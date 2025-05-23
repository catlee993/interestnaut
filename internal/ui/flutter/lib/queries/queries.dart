/// SQL queries for the Interestnaut app
/// This file contains all the SQL queries used in the app

/// Schema creation

// Create recommendations table if it doesn't exist
const String createRecommendationsTableQuery = '''
CREATE TABLE IF NOT EXISTS recommendations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  query TEXT NOT NULL,
  media_type TEXT NOT NULL,
  title TEXT,
  artist TEXT,
  album TEXT,
  cover_art_url TEXT,
  description TEXT,
  wiki_url TEXT,
  wikidata_id TEXT,
  bot_reasoning TEXT,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TEXT NOT NULL,
  updated_at TEXT
);
''';

/// Media Suggestion Queries

// Insert a new media suggestion
const String insertMediaSuggestionQuery = '''
INSERT INTO recommendations (
  query,
  media_type,
  title,
  artist,
  album,
  cover_art_url,
  description,
  wiki_url,
  wikidata_id,
  bot_reasoning,
  status,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
''';

// Update an existing media suggestion
const String updateMediaSuggestionQuery = '''
UPDATE recommendations SET
  query = ?,
  media_type = ?,
  title = ?,
  artist = ?,
  album = ?,
  cover_art_url = ?,
  description = ?,
  wiki_url = ?,
  wikidata_id = ?,
  bot_reasoning = ?,
  status = ?,
  updated_at = ?
WHERE id = ?;
''';

// Get a media suggestion by ID
const String getMediaSuggestionByIdQuery = '''
SELECT
  id,
  query,
  media_type,
  title,
  artist,
  album,
  cover_art_url,
  description,
  wiki_url,
  wikidata_id,
  bot_reasoning,
  status,
  created_at,
  updated_at
FROM recommendations
WHERE id = ?;
''';

// Get all media suggestions with optional filters
const String getAllMediaSuggestionsBaseQuery = '''
SELECT
  id,
  query,
  media_type,
  title,
  artist,
  album,
  cover_art_url,
  description,
  wiki_url,
  wikidata_id,
  bot_reasoning,
  status,
  created_at,
  updated_at
FROM recommendations
''';

// Get all media suggestions for a specific media type with status filter
const String getAllMediaSuggestionsWithStatusQuery = '''
SELECT
  id,
  query,
  media_type,
  title,
  artist,
  album,
  cover_art_url,
  description,
  wiki_url,
  wikidata_id,
  bot_reasoning,
  status,
  created_at,
  updated_at
FROM recommendations
WHERE media_type = ? AND status = ?
ORDER BY created_at DESC
LIMIT ?;
''';

// Get all media suggestions for a specific media type
const String getAllMediaSuggestionsQuery = '''
SELECT
  id,
  query,
  media_type,
  title,
  artist,
  album,
  cover_art_url,
  description,
  wiki_url,
  wikidata_id,
  bot_reasoning,
  status,
  created_at,
  updated_at
FROM recommendations
WHERE media_type = ?
ORDER BY created_at DESC
LIMIT ?;
''';

// Get pending media suggestions for a specific media type
const String getPendingMediaSuggestionsQuery = '''
SELECT
  id,
  query,
  media_type,
  title,
  artist,
  album,
  cover_art_url,
  description,
  wiki_url,
  wikidata_id,
  bot_reasoning,
  status,
  created_at,
  updated_at
FROM recommendations
WHERE media_type = ? AND status = 'pending'
ORDER BY created_at DESC;
''';

// Update media suggestion status
const String updateMediaSuggestionStatusQuery = '''
UPDATE recommendations
SET status = ?, updated_at = ?
WHERE id = ?;
''';

// Delete media suggestion
const String deleteMediaSuggestionQuery = '''
DELETE FROM recommendations
WHERE id = ?;
''';

// Count pending media suggestions
const String countPendingMediaSuggestionsQuery = '''
SELECT COUNT(*)
FROM recommendations
WHERE media_type = ? AND status = ?;
''';