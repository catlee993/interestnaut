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
  updated_at TEXT,
  UNIQUE(title, artist, media_type)
);
''';

// Create watchlist table if it doesn't exist
const String createWatchlistTableQuery = '''
CREATE TABLE IF NOT EXISTS watchlist (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  recommendation_id INTEGER NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (recommendation_id) REFERENCES recommendations (id) ON DELETE CASCADE,
  UNIQUE(recommendation_id)
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

/// Watchlist Queries

// Add recommendation to watchlist
const String addToWatchlistQuery = '''
INSERT OR IGNORE INTO watchlist (recommendation_id, created_at)
VALUES (?, ?);
''';

// Remove from watchlist
const String removeFromWatchlistQuery = '''
DELETE FROM watchlist
WHERE recommendation_id = ?;
''';

// Get all watchlist items
const String getWatchlistQuery = '''
SELECT 
  r.id,
  r.query,
  r.media_type,
  r.title,
  r.artist,
  r.album,
  r.cover_art_url,
  r.description,
  r.wiki_url,
  r.wikidata_id,
  r.bot_reasoning,
  r.status,
  r.created_at,
  r.updated_at,
  w.created_at as watchlist_added_at
FROM recommendations r
INNER JOIN watchlist w ON r.id = w.recommendation_id
WHERE r.media_type = ?
ORDER BY w.created_at DESC;
''';

// Get pending suggestions that are NOT in watchlist (for main suggestions)
const String getPendingSuggestionsNotInWatchlistQuery = '''
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
FROM recommendations r
WHERE media_type = ? 
  AND status = 'pending' 
  AND NOT EXISTS (
    SELECT 1 FROM watchlist w WHERE w.recommendation_id = r.id
  )
ORDER BY created_at DESC;
''';

// Check if recommendation is in watchlist
const String isInWatchlistQuery = '''
SELECT COUNT(*) 
FROM watchlist 
WHERE recommendation_id = ?;
''';

// Delete suggestions with invalid titles (cleanup query)
const String deleteBadSuggestionsQuery = '''
DELETE FROM recommendations 
WHERE title IS NULL 
   OR title = '' 
   OR title LIKE '%Why%' 
   OR title LIKE '%What%'
   OR title LIKE '%How%'
   OR title LIKE '%Because%'
   OR title LIKE 'http%'
   OR artist IS NULL 
   OR artist = ''
   OR artist LIKE '%Why%'
   OR artist LIKE '%What%'
   OR artist LIKE '%How%'
   OR artist LIKE '%Because%';
''';