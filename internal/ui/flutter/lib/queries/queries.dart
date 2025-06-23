/// SQL queries for the Interestnaut app
/// This file contains all the SQL queries used in the app

/// Schema creation

// Create media types lookup table
const String createMediaTypesTableQuery = '''
CREATE TABLE IF NOT EXISTS media_types (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name VARCHAR NOT NULL UNIQUE
);
''';

// Create recommendation status lookup table
const String createRecommendationStatusTableQuery = '''
CREATE TABLE IF NOT EXISTS recommendation_status (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name VARCHAR NOT NULL UNIQUE
);
''';

// Insert default media types
const String insertDefaultMediaTypesQuery = '''
INSERT OR IGNORE INTO media_types (name) VALUES 
  ('book'),
  ('music'), 
  ('movie'),
  ('tv_show'),
  ('video_game');
''';

// Insert default recommendation statuses
const String insertDefaultRecommendationStatusQuery = '''
INSERT OR IGNORE INTO recommendation_status (name) VALUES 
  ('pending'),
  ('liked'),
  ('disliked'),
  ('skipped'),
  ('favorited'),
  ('added'),
  ('watchlist');
''';

// Create recommendations table with proper foreign keys
const String createRecommendationsTableQuery = '''
CREATE TABLE IF NOT EXISTS recommendations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  query TEXT NOT NULL,
  media_type_id INTEGER NOT NULL,
  vector_media_id TEXT,
  title TEXT,
  primary_creator TEXT,
  cover_art_url TEXT,
  description TEXT,
  wiki_url TEXT,
  wikidata_id TEXT,
  bot_reasoning TEXT,
  status_id INTEGER NOT NULL DEFAULT 1,
  themes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT,
  FOREIGN KEY (media_type_id) REFERENCES media_types (id),
  FOREIGN KEY (status_id) REFERENCES recommendation_status (id),
  UNIQUE(title, primary_creator, media_type_id)
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
  media_type_id INTEGER NOT NULL,
  value VARCHAR NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (media_type_id) REFERENCES media_types (id) ON DELETE CASCADE
);
''';

// Create user-added favorites table with vector ID linking
const String createUserAddedFavoritesTableQuery = '''
CREATE TABLE IF NOT EXISTS user_added_favorites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title VARCHAR NOT NULL,
  media_type_id INTEGER NOT NULL,
  vector_media_id TEXT,
  primary_creator VARCHAR,
  cover_art_url VARCHAR,
  themes TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (media_type_id) REFERENCES media_types (id) ON DELETE CASCADE,
  UNIQUE(vector_media_id, media_type_id)
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

// Add media_id column to recommendations table if it doesn't exist
const String addMediaIdToRecommendationsQuery = '''
ALTER TABLE recommendations ADD COLUMN media_id TEXT;
''';

/// Media Type Queries

// Get media type ID by name
const String getMediaTypeIdQuery = '''
SELECT id FROM media_types WHERE name = ?;
''';

// Get all media types
const String getAllMediaTypesQuery = '''
SELECT id, name FROM media_types ORDER BY name;
''';

/// User Constraints Queries

// Insert user constraint
const String insertUserConstraintQuery = '''
INSERT INTO user_constraints (media_type_id, value) VALUES (?, ?);
''';

// Get user constraints for a media type
const String getUserConstraintsForMediaQuery = '''
SELECT uc.value 
FROM user_constraints uc
JOIN media_types mt ON uc.media_type_id = mt.id
WHERE mt.name = ?;
''';

// Get all user constraints
const String getAllUserConstraintsQuery = '''
SELECT mt.name as media_type, uc.value, uc.id
FROM user_constraints uc
JOIN media_types mt ON uc.media_type_id = mt.id
ORDER BY mt.name, uc.value;
''';

// Delete user constraint
const String deleteUserConstraintQuery = '''
DELETE FROM user_constraints WHERE id = ?;
''';

/// User Added Favorites Queries

// Insert user-added favorite
const String insertUserAddedFavoriteQuery = '''
INSERT INTO user_added_favorites (title, media_type_id, vector_media_id, primary_creator, cover_art_url, themes) 
VALUES (?, ?, ?, ?, ?, ?);
''';

// Get user-added favorites for a media type
const String getUserAddedFavoritesForMediaQuery = '''
SELECT uaf.id, uaf.title, uaf.primary_creator, uaf.vector_media_id, uaf.cover_art_url, uaf.themes, uaf.created_at
FROM user_added_favorites uaf
JOIN media_types mt ON uaf.media_type_id = mt.id
WHERE mt.name = ?
ORDER BY uaf.created_at DESC;
''';

// Get all user-added favorites
const String getAllUserAddedFavoritesQuery = '''
SELECT uaf.id, uaf.title, uaf.primary_creator, uaf.vector_media_id, uaf.cover_art_url, uaf.themes, uaf.created_at, mt.name as media_type
FROM user_added_favorites uaf
JOIN media_types mt ON uaf.media_type_id = mt.id
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
  media_type_id,
  vector_media_id,
  title,
  primary_creator,
  cover_art_url,
  description,
  wiki_url,
  wikidata_id,
  bot_reasoning,
  status_id,
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
  r.id,
  r.query,
  mt.name as media_type,
  r.title,
  r.primary_creator,
  r.vector_media_id,
  r.cover_art_url,
  r.description,
  r.wiki_url,
  r.wikidata_id,
  r.bot_reasoning,
  rs.name as status,
  r.themes,
  r.created_at,
  r.updated_at
FROM recommendations r
JOIN media_types mt ON r.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE r.id = ?;
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
  media_id,
  created_at,
  updated_at
FROM recommendations
''';

// Get all media suggestions for a specific media type with status filter
const String getAllMediaSuggestionsWithStatusQuery = '''
SELECT
  r.id,
  r.query,
  mt.name as media_type,
  r.title,
  r.primary_creator,
  r.vector_media_id,
  r.cover_art_url,
  r.description,
  r.wiki_url,
  r.wikidata_id,
  r.bot_reasoning,
  rs.name as status,
  r.themes,
  r.created_at,
  r.updated_at
FROM recommendations r
JOIN media_types mt ON r.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name = ?
ORDER BY r.created_at DESC
LIMIT ?;
''';

// Get all media suggestions for a specific media type
const String getAllMediaSuggestionsQuery = '''
SELECT
  r.id,
  r.query,
  mt.name as media_type,
  r.title,
  r.primary_creator,
  r.vector_media_id,
  r.cover_art_url,
  r.description,
  r.wiki_url,
  r.wikidata_id,
  r.bot_reasoning,
  rs.name as status,
  r.themes,
  r.created_at,
  r.updated_at
FROM recommendations r
JOIN media_types mt ON r.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ?
ORDER BY r.created_at DESC
LIMIT ?;
''';

// Get pending media suggestions for a specific media type
const String getPendingMediaSuggestionsQuery = '''
SELECT
  r.id,
  r.query,
  mt.name as media_type,
  r.title,
  r.primary_creator,
  r.vector_media_id,
  r.cover_art_url,
  r.description,
  r.wiki_url,
  r.wikidata_id,
  r.bot_reasoning,
  rs.name as status,
  r.themes,
  r.created_at,
  r.updated_at
FROM recommendations r
JOIN media_types mt ON r.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name = 'pending'
ORDER BY r.created_at DESC;
''';

// Get pending media suggestions that are NOT in watchlist (for main suggestions)
const String getPendingSuggestionsNotInWatchlistQuery = '''
SELECT
  r.id,
  r.query,
  mt.name as media_type,
  r.title,
  r.primary_creator,
  r.vector_media_id,
  r.cover_art_url,
  r.description,
  r.wiki_url,
  r.wikidata_id,
  r.bot_reasoning,
  rs.name as status,
  r.themes,
  r.created_at,
  r.updated_at
FROM recommendations r
JOIN media_types mt ON r.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
LEFT JOIN watchlist w ON r.id = w.recommendation_id
WHERE mt.name = ? AND rs.name = 'pending' AND w.recommendation_id IS NULL
ORDER BY r.created_at DESC;
''';

// Update media suggestion status
const String updateMediaSuggestionStatusQuery = '''
UPDATE recommendations
SET status_id = (SELECT id FROM recommendation_status WHERE name = ?), updated_at = ?
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
FROM recommendations r
JOIN media_types mt ON r.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name = 'pending';
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
  mt.name as media_type,
  r.title,
  r.primary_creator,
  r.vector_media_id,
  r.cover_art_url,
  r.description,
  r.wiki_url,
  r.wikidata_id,
  r.bot_reasoning,
  rs.name as status,
  r.themes,
  r.created_at,
  r.updated_at,
  w.created_at as watchlist_added_at
FROM recommendations r
JOIN media_types mt ON r.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
JOIN watchlist w ON r.id = w.recommendation_id
WHERE mt.name = ?
ORDER BY w.created_at DESC;
''';

/// Advanced Recommendation Queries

// Get liked recommendations for a media type (for learning user preferences)
const String getLikedRecommendationsQuery = '''
SELECT
  r.id,
  r.query,
  mt.name as media_type,
  r.title,
  r.primary_creator as artist,
  '' as album,
  r.cover_art_url,
  r.description,
  r.wiki_url,
  r.wikidata_id,
  r.bot_reasoning,
  rs.name as status,
  r.themes,
  r.vector_media_id as media_id,
  r.created_at,
  r.updated_at
FROM recommendations r
JOIN media_types mt ON r.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name = 'liked'
ORDER BY r.updated_at DESC;
''';

// Get disliked recommendations for a media type (for avoiding similar content)
const String getDislikedRecommendationsQuery = '''
SELECT
  r.id,
  r.query,
  mt.name as media_type,
  r.title,
  r.primary_creator as artist,
  '' as album,
  r.cover_art_url,
  r.description,
  r.wiki_url,
  r.wikidata_id,
  r.bot_reasoning,
  rs.name as status,
  r.themes,
  r.created_at,
  r.updated_at
FROM recommendations r
JOIN media_types mt ON r.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name = 'disliked'
ORDER BY r.updated_at DESC;
''';

// Get favorited recommendations for a media type (for learning user preferences)
const String getFavoritedRecommendationsQuery = '''
SELECT
  r.id,
  r.query,
  mt.name as media_type,
  r.title,
  r.primary_creator as artist,
  '' as album,
  r.cover_art_url,
  r.description,
  r.wiki_url,
  r.wikidata_id,
  r.bot_reasoning,
  rs.name as status,
  r.themes,
  r.vector_media_id as media_id,
  r.created_at,
  r.updated_at
FROM recommendations r
JOIN media_types mt ON r.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name = 'added'
ORDER BY r.updated_at DESC;
''';

// Get watchlisted recommendations for a media type (for learning user preferences)
const String getWatchlistedRecommendationsQuery = '''
SELECT
  r.id,
  r.query,
  mt.name as media_type,
  r.title,
  r.primary_creator as artist,
  '' as album,
  r.cover_art_url,
  r.description,
  r.wiki_url,
  r.wikidata_id,
  r.bot_reasoning,
  rs.name as status,
  r.themes,
  r.vector_media_id as media_id,
  r.created_at,
  r.updated_at
FROM recommendations r
JOIN media_types mt ON r.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name = 'watchlist'
ORDER BY r.updated_at DESC;
''';

// Get skipped recommendations for a media type (for learning user preferences)
const String getSkippedRecommendationsQuery = '''
SELECT
  r.id,
  r.query,
  mt.name as media_type,
  r.title,
  r.primary_creator as artist,
  '' as album,
  r.cover_art_url,
  r.description,
  r.wiki_url,
  r.wikidata_id,
  r.bot_reasoning,
  rs.name as status,
  r.themes,
  r.vector_media_id as media_id,
  r.created_at,
  r.updated_at
FROM recommendations r
JOIN media_types mt ON r.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name = 'skipped'
ORDER BY r.updated_at DESC;
''';

// Get user preference summary for a media type
const String getUserPreferenceSummaryQuery = '''
SELECT 
  rs.name as status,
  COUNT(*) as count,
  GROUP_CONCAT(DISTINCT r.themes) as all_themes,
  GROUP_CONCAT(DISTINCT r.primary_creator) as all_artists
FROM recommendations r
JOIN media_types mt ON r.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name IN ('liked', 'disliked', 'added')
GROUP BY rs.name;
''';