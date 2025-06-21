/// SQL queries for the Interestnaut app
/// This file contains all the SQL queries used in the app

/// Schema creation

// Create media types table
const String createMediaTableQuery = '''
CREATE TABLE IF NOT EXISTS media (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name VARCHAR NOT NULL UNIQUE
);
''';

// Insert default media types
const String insertDefaultMediaTypesQuery = '''
INSERT OR IGNORE INTO media (name) VALUES 
  ('book'),
  ('music'), 
  ('movie'),
  ('tv_show'),
  ('video_game');
''';

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
  themes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  UNIQUE(title, artist, media_type)
);
''';

// Create recommendation metadata table for flexible key-value storage
const String createRecommendationMetadataTableQuery = '''
CREATE TABLE IF NOT EXISTS recommendation_metadata (
  recommendation_id INTEGER NOT NULL,
  key VARCHAR NOT NULL,
  value VARCHAR NOT NULL,
  PRIMARY KEY (recommendation_id, key),
  FOREIGN KEY (recommendation_id) REFERENCES recommendations (id) ON DELETE CASCADE
);
''';

// Create user constraints table
const String createUserConstraintsTableQuery = '''
CREATE TABLE IF NOT EXISTS user_constraints (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  media_id INTEGER NOT NULL,
  value VARCHAR NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (media_id) REFERENCES media (id) ON DELETE CASCADE
);
''';

// Create user-added favorites table
const String createUserAddedFavoritesTableQuery = '''
CREATE TABLE IF NOT EXISTS user_added_favorites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title VARCHAR NOT NULL,
  media_id INTEGER NOT NULL,
  artist VARCHAR,
  cover_art_url VARCHAR,
  themes TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (media_id) REFERENCES media (id) ON DELETE CASCADE
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

/// Migration queries

// Add themes column to recommendations table if it doesn't exist
const String addThemesToRecommendationsQuery = '''
ALTER TABLE recommendations ADD COLUMN themes TEXT;
''';

/// Media Type Queries

// Get media type ID by name
const String getMediaTypeIdQuery = '''
SELECT id FROM media WHERE name = ?;
''';

// Get all media types
const String getAllMediaTypesQuery = '''
SELECT id, name FROM media ORDER BY name;
''';

/// User Constraints Queries

// Insert user constraint
const String insertUserConstraintQuery = '''
INSERT INTO user_constraints (media_id, value) VALUES (?, ?);
''';

// Get user constraints for a media type
const String getUserConstraintsForMediaQuery = '''
SELECT uc.value 
FROM user_constraints uc
JOIN media m ON uc.media_id = m.id
WHERE m.name = ?;
''';

// Get all user constraints
const String getAllUserConstraintsQuery = '''
SELECT m.name as media_type, uc.value, uc.id
FROM user_constraints uc
JOIN media m ON uc.media_id = m.id
ORDER BY m.name, uc.value;
''';

// Delete user constraint
const String deleteUserConstraintQuery = '''
DELETE FROM user_constraints WHERE id = ?;
''';

/// User Added Favorites Queries

// Insert user-added favorite
const String insertUserAddedFavoriteQuery = '''
INSERT INTO user_added_favorites (title, media_id, artist, cover_art_url, themes) 
VALUES (?, ?, ?, ?, ?);
''';

// Get user-added favorites for a media type
const String getUserAddedFavoritesForMediaQuery = '''
SELECT uaf.id, uaf.title, uaf.artist, uaf.cover_art_url, uaf.themes, uaf.created_at
FROM user_added_favorites uaf
JOIN media m ON uaf.media_id = m.id
WHERE m.name = ?
ORDER BY uaf.created_at DESC;
''';

// Get all user-added favorites
const String getAllUserAddedFavoritesQuery = '''
SELECT uaf.id, uaf.title, uaf.artist, uaf.cover_art_url, uaf.themes, uaf.created_at, m.name as media_type
FROM user_added_favorites uaf
JOIN media m ON uaf.media_id = m.id
ORDER BY uaf.created_at DESC;
''';

// Delete user-added favorite
const String deleteUserAddedFavoriteQuery = '''
DELETE FROM user_added_favorites WHERE id = ?;
''';

/// Recommendation Metadata Queries

// Insert recommendation metadata
const String insertRecommendationMetadataQuery = '''
INSERT OR REPLACE INTO recommendation_metadata (recommendation_id, key, value) 
VALUES (?, ?, ?);
''';

// Get recommendation metadata
const String getRecommendationMetadataQuery = '''
SELECT key, value 
FROM recommendation_metadata 
WHERE recommendation_id = ?;
''';

// Get specific metadata value
const String getRecommendationMetadataValueQuery = '''
SELECT value 
FROM recommendation_metadata 
WHERE recommendation_id = ? AND key = ?;
''';

// Delete recommendation metadata
const String deleteRecommendationMetadataQuery = '''
DELETE FROM recommendation_metadata WHERE recommendation_id = ?;
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
  themes,
  created_at,
  updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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
  themes = ?,
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
  themes,
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
  themes,
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
  themes,
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
  themes,
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
  themes,
  created_at,
  updated_at
FROM recommendations
WHERE media_type = ? AND status = 'pending'
ORDER BY created_at DESC;
''';

// Get pending media suggestions that are NOT in watchlist (for main suggestions)
const String getPendingSuggestionsNotInWatchlistQuery = '''
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
  r.themes,
  r.created_at,
  r.updated_at
FROM recommendations r
LEFT JOIN watchlist w ON r.id = w.recommendation_id
WHERE r.media_type = ? AND r.status = 'pending' AND w.recommendation_id IS NULL
ORDER BY r.created_at DESC;
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
SELECT COUNT(*) as count
FROM recommendations
WHERE media_type = ? AND status = 'pending';
''';

/// Watchlist Queries

// Add to watchlist
const String addToWatchlistQuery = '''
INSERT OR IGNORE INTO watchlist (recommendation_id, created_at)
VALUES (?, ?);
''';

// Remove from watchlist
const String removeFromWatchlistQuery = '''
DELETE FROM watchlist
WHERE recommendation_id = ?;
''';

// Check if in watchlist
const String isInWatchlistQuery = '''
SELECT COUNT(*) as count
FROM watchlist
WHERE recommendation_id = ?;
''';

// Get watchlist items for a media type
const String getWatchlistItemsQuery = '''
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
  r.themes,
  r.created_at,
  r.updated_at,
  w.created_at as watchlist_added_at
FROM recommendations r
JOIN watchlist w ON r.id = w.recommendation_id
WHERE r.media_type = ?
ORDER BY w.created_at DESC;
''';

/// Advanced Recommendation Queries

// Get liked recommendations for a media type (for learning user preferences)
const String getLikedRecommendationsQuery = '''
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
  themes,
  created_at,
  updated_at
FROM recommendations
WHERE media_type = ? AND status = 'liked'
ORDER BY updated_at DESC;
''';

// Get disliked recommendations for a media type (for avoiding similar content)
const String getDislikedRecommendationsQuery = '''
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
  themes,
  created_at,
  updated_at
FROM recommendations
WHERE media_type = ? AND status = 'disliked'
ORDER BY updated_at DESC;
''';

// Get user preference summary for a media type
const String getUserPreferenceSummaryQuery = '''
SELECT 
  status,
  COUNT(*) as count,
  GROUP_CONCAT(DISTINCT themes) as all_themes,
  GROUP_CONCAT(DISTINCT artist) as all_artists
FROM recommendations 
WHERE media_type = ? AND status IN ('liked', 'disliked', 'added')
GROUP BY status;
''';