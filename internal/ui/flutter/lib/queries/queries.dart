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

// Create central media_items table (single source of truth for all media data)
const String createMediaItemsTableQuery = '''
CREATE TABLE IF NOT EXISTS media_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  media_type_id INTEGER NOT NULL,
  vector_media_id TEXT,
  title TEXT NOT NULL,
  primary_creator TEXT,
  cover_art_url TEXT,
  description TEXT,
  wiki_url TEXT,
  wikidata_id TEXT,
  themes TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT,
  FOREIGN KEY (media_type_id) REFERENCES media_types (id),
  UNIQUE(title, primary_creator, media_type_id)
);
''';

// Create recommendations table (references media_items)
const String createRecommendationsTableQuery = '''
CREATE TABLE IF NOT EXISTS recommendations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  media_item_id INTEGER NOT NULL,
  query TEXT NOT NULL,
  bot_reasoning TEXT,
  status_id INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT,
  FOREIGN KEY (media_item_id) REFERENCES media_items (id) ON DELETE CASCADE,
  FOREIGN KEY (status_id) REFERENCES recommendation_status (id),
  UNIQUE(media_item_id, query)
);
''';

// Create user_favorites table (references media_items, can be recommendation-based or user-added)
const String createUserFavoritesTableQuery = '''
CREATE TABLE IF NOT EXISTS user_favorites (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  media_item_id INTEGER NOT NULL,
  recommendation_id INTEGER,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (media_item_id) REFERENCES media_items (id) ON DELETE CASCADE,
  FOREIGN KEY (recommendation_id) REFERENCES recommendations (id) ON DELETE SET NULL,
  UNIQUE(media_item_id)
);
''';

// Create watchlist table (references media_items, can be recommendation-based or user-added)
const String createWatchlistTableQuery = '''
CREATE TABLE IF NOT EXISTS watchlist (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  media_item_id INTEGER NOT NULL,
  recommendation_id INTEGER,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (media_item_id) REFERENCES media_items (id) ON DELETE CASCADE,
  FOREIGN KEY (recommendation_id) REFERENCES recommendations (id) ON DELETE SET NULL,
  UNIQUE(media_item_id)
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

/// Media Items Queries

// Insert or get existing media item
const String insertOrGetMediaItemQuery = '''
INSERT OR IGNORE INTO media_items (
  media_type_id, vector_media_id, title, primary_creator, cover_art_url, 
  description, wiki_url, wikidata_id, themes, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
''';

// Get media item by title and creator
const String getMediaItemByTitleCreatorQuery = '''
SELECT mi.id, mi.media_type_id, mi.vector_media_id, mi.title, mi.primary_creator,
       mi.cover_art_url, mi.description, mi.wiki_url, mi.wikidata_id, mi.themes,
       mi.created_at, mi.updated_at, mt.name as media_type
FROM media_items mi
JOIN media_types mt ON mi.media_type_id = mt.id
WHERE mi.title = ? AND mi.primary_creator = ? AND mt.name = ?;
''';

// Get media item by ID
const String getMediaItemByIdQuery = '''
SELECT mi.id, mi.media_type_id, mi.vector_media_id, mi.title, mi.primary_creator,
       mi.cover_art_url, mi.description, mi.wiki_url, mi.wikidata_id, mi.themes,
       mi.created_at, mi.updated_at, mt.name as media_type
FROM media_items mi
JOIN media_types mt ON mi.media_type_id = mt.id
WHERE mi.id = ?;
''';

// Update media item
const String updateMediaItemQuery = '''
UPDATE media_items SET
  vector_media_id = ?, title = ?, primary_creator = ?, cover_art_url = ?,
  description = ?, wiki_url = ?, wikidata_id = ?, themes = ?, updated_at = ?
WHERE id = ?;
''';

/// Recommendation Queries

// Insert a new recommendation
const String insertRecommendationQuery = '''
INSERT INTO recommendations (
  media_item_id, query, bot_reasoning, status_id, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?);
''';

// Update recommendation status
const String updateRecommendationStatusQuery = '''
UPDATE recommendations
SET status_id = (SELECT id FROM recommendation_status WHERE name = ?), updated_at = ?
WHERE id = ?;
''';

// Get recommendation by ID
const String getRecommendationByIdQuery = '''
SELECT r.id, r.media_item_id, r.query, r.bot_reasoning, rs.name as status,
       r.created_at, r.updated_at,
       mi.vector_media_id, mi.title, mi.primary_creator, mi.cover_art_url,
       mi.description, mi.wiki_url, mi.wikidata_id, mi.themes,
       mt.name as media_type
FROM recommendations r
JOIN media_items mi ON r.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE r.id = ?;
''';

// Get pending recommendations not in watchlist
const String getPendingRecommendationsNotInWatchlistQuery = '''
SELECT r.id, r.media_item_id, r.query, r.bot_reasoning, rs.name as status,
       r.created_at, r.updated_at,
       mi.vector_media_id, mi.title, mi.primary_creator, mi.cover_art_url,
       mi.description, mi.wiki_url, mi.wikidata_id, mi.themes,
       mt.name as media_type
FROM recommendations r
JOIN media_items mi ON r.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
LEFT JOIN watchlist w ON mi.id = w.media_item_id
WHERE mt.name = ? AND rs.name = 'pending' AND w.media_item_id IS NULL
ORDER BY r.created_at DESC;
''';

// Get recommendations by status
const String getRecommendationsByStatusQuery = '''
SELECT r.id, r.media_item_id, r.query, r.bot_reasoning, rs.name as status,
       r.created_at, r.updated_at,
       mi.vector_media_id, mi.title, mi.primary_creator, mi.cover_art_url,
       mi.description, mi.wiki_url, mi.wikidata_id, mi.themes,
       mt.name as media_type
FROM recommendations r
JOIN media_items mi ON r.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name = ?
ORDER BY r.updated_at DESC;
''';

// Count pending recommendations
const String countPendingRecommendationsQuery = '''
SELECT COUNT(*) as count
FROM recommendations r
JOIN media_items mi ON r.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name = 'pending';
''';

// Delete recommendation
const String deleteRecommendationQuery = '''
DELETE FROM recommendations WHERE id = ?;
''';

/// User Favorites Queries

// Add to favorites (from recommendation)
const String addRecommendationToFavoritesQuery = '''
INSERT OR IGNORE INTO user_favorites (media_item_id, recommendation_id, created_at)
VALUES (?, ?, ?);
''';

// Add to favorites (user-added, no recommendation)
const String addUserFavoriteQuery = '''
INSERT OR IGNORE INTO user_favorites (media_item_id, created_at)
VALUES (?, ?);
''';

// Remove from favorites
const String removeFromFavoritesQuery = '''
DELETE FROM user_favorites WHERE media_item_id = ?;
''';

// Check if in favorites
const String isInFavoritesQuery = '''
SELECT COUNT(*) as count FROM user_favorites WHERE media_item_id = ?;
''';

// Get favorites for a media type
const String getFavoritesQuery = '''
SELECT uf.id, uf.recommendation_id, uf.created_at as favorited_at,
       mi.id as media_item_id, mi.vector_media_id, mi.title, mi.primary_creator,
       mi.cover_art_url, mi.description, mi.wiki_url, mi.wikidata_id, mi.themes,
       mt.name as media_type
FROM user_favorites uf
JOIN media_items mi ON uf.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
WHERE mt.name = ?
ORDER BY uf.created_at DESC;
''';

/// Watchlist Queries

// Add to watchlist (from recommendation)
const String addRecommendationToWatchlistQuery = '''
INSERT OR IGNORE INTO watchlist (media_item_id, recommendation_id, created_at)
VALUES (?, ?, ?);
''';

// Add to watchlist (user-added, no recommendation)
const String addUserWatchlistQuery = '''
INSERT OR IGNORE INTO watchlist (media_item_id, created_at)
VALUES (?, ?);
''';

// Remove from watchlist
const String removeFromWatchlistQuery = '''
DELETE FROM watchlist WHERE media_item_id = ?;
''';

// Check if in watchlist
const String isInWatchlistQuery = '''
SELECT COUNT(*) as count FROM watchlist WHERE media_item_id = ?;
''';

// Get watchlist for a media type
const String getWatchlistQuery = '''
SELECT w.id, w.recommendation_id, w.created_at as watchlist_added_at,
       mi.id as media_item_id, mi.vector_media_id, mi.title, mi.primary_creator,
       mi.cover_art_url, mi.description, mi.wiki_url, mi.wikidata_id, mi.themes,
       mt.name as media_type
FROM watchlist w
JOIN media_items mi ON w.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
WHERE mt.name = ?
ORDER BY w.created_at DESC;
''';

/// Advanced Behavioral Queries (for LLM learning)

// Get liked recommendations for behavioral analysis
const String getLikedRecommendationsQuery = '''
SELECT r.id, r.media_item_id, r.query, r.bot_reasoning,
       mi.vector_media_id as media_id, mi.title, mi.primary_creator as artist,
       '' as album, mi.cover_art_url, mi.description, mi.wiki_url, mi.wikidata_id,
       mi.themes, mt.name as media_type, r.created_at, r.updated_at
FROM recommendations r
JOIN media_items mi ON r.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name = 'liked'
ORDER BY r.updated_at DESC;
''';

// Get disliked recommendations for behavioral analysis
const String getDislikedRecommendationsQuery = '''
SELECT r.id, r.media_item_id, r.query, r.bot_reasoning,
       mi.vector_media_id as media_id, mi.title, mi.primary_creator as artist,
       '' as album, mi.cover_art_url, mi.description, mi.wiki_url, mi.wikidata_id,
       mi.themes, mt.name as media_type, r.created_at, r.updated_at
FROM recommendations r
JOIN media_items mi ON r.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name = 'disliked'
ORDER BY r.updated_at DESC;
''';

// Get favorited recommendations for behavioral analysis
const String getFavoritedRecommendationsQuery = '''
SELECT r.id, r.media_item_id, 
       COALESCE(r.query, 'Unknown') as query, 
       COALESCE(r.bot_reasoning, 'No reasoning') as bot_reasoning,
       mi.vector_media_id as media_id, 
       COALESCE(mi.title, 'Unknown Title') as title, 
       mi.primary_creator as artist,
       '' as album, mi.cover_art_url, mi.description, mi.wiki_url, mi.wikidata_id,
       mi.themes, mt.name as media_type, 
       COALESCE(r.created_at, mi.created_at) as created_at, 
       COALESCE(r.updated_at, mi.updated_at) as updated_at
FROM recommendations r
JOIN media_items mi ON r.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name = 'added'
ORDER BY r.updated_at DESC;
''';

// Get watchlisted recommendations for behavioral analysis
const String getWatchlistedRecommendationsQuery = '''
SELECT r.id, r.media_item_id, r.query, r.bot_reasoning,
       mi.vector_media_id as media_id, mi.title, mi.primary_creator as artist,
       '' as album, mi.cover_art_url, mi.description, mi.wiki_url, mi.wikidata_id,
       mi.themes, mt.name as media_type, r.created_at, r.updated_at
FROM recommendations r
JOIN media_items mi ON r.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name = 'watchlist'
ORDER BY r.updated_at DESC;
''';

// Get skipped recommendations for behavioral analysis
const String getSkippedRecommendationsQuery = '''
SELECT r.id, r.media_item_id, r.query, r.bot_reasoning,
       mi.vector_media_id as media_id, mi.title, mi.primary_creator as artist,
       '' as album, mi.cover_art_url, mi.description, mi.wiki_url, mi.wikidata_id,
       mi.themes, mt.name as media_type, r.created_at, r.updated_at
FROM recommendations r
JOIN media_items mi ON r.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name = 'skipped'
ORDER BY r.updated_at DESC;
''';

// Get user preference summary for behavioral analysis
const String getUserPreferenceSummaryQuery = '''
SELECT 
  rs.name as status,
  COUNT(*) as count,
  GROUP_CONCAT(DISTINCT mi.themes) as all_themes,
  GROUP_CONCAT(DISTINCT mi.primary_creator) as all_artists
FROM recommendations r
JOIN media_items mi ON r.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name IN ('liked', 'disliked', 'added')
GROUP BY rs.name;
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

/// Search Queries

// Search media items by title or creator
const String searchMediaItemsQuery = '''
SELECT mi.id as media_item_id, mi.vector_media_id, mi.title, mi.primary_creator,
       mi.cover_art_url, mi.description, mi.wiki_url, mi.wikidata_id, mi.themes,
       mt.name as media_type, mi.created_at, mi.updated_at
FROM media_items mi
JOIN media_types mt ON mi.media_type_id = mt.id
WHERE mt.name = ? AND (mi.title LIKE ? OR mi.primary_creator LIKE ?)
ORDER BY mi.title ASC;
''';

/// Legacy compatibility queries (for gradual migration)

// These queries maintain compatibility with the old MediaSuggestion structure
// They can be removed once all code is updated to use the new normalized structure

// Get media suggestion by ID (legacy compatibility)
const String getMediaSuggestionByIdQuery = '''
SELECT r.id, r.media_item_id, r.query, r.bot_reasoning,
       mi.vector_media_id, mi.title, mi.primary_creator, mi.cover_art_url,
       mi.description, mi.wiki_url, mi.wikidata_id, mi.themes,
       mt.name as media_type, rs.name as status,
       r.created_at, r.updated_at
FROM recommendations r
JOIN media_items mi ON r.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE r.id = ?;
''';

// Insert media suggestion (legacy compatibility)
const String insertMediaSuggestionQuery = '''
INSERT INTO recommendations (
  media_item_id, query, bot_reasoning, status_id, created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?);
''';

// Update media suggestion status (legacy compatibility)
const String updateMediaSuggestionStatusQuery = '''
UPDATE recommendations
SET status_id = (SELECT id FROM recommendation_status WHERE name = ?), updated_at = ?
WHERE id = ?;
''';

// Delete media suggestion (legacy compatibility)
const String deleteMediaSuggestionQuery = '''
DELETE FROM recommendations WHERE id = ?;
''';

// Count pending media suggestions (legacy compatibility)
const String countPendingMediaSuggestionsQuery = '''
SELECT COUNT(*) as count
FROM recommendations r
JOIN media_items mi ON r.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ? AND rs.name = 'pending';
''';

// Get pending suggestions not in watchlist (legacy compatibility)
const String getPendingSuggestionsNotInWatchlistQuery = '''
SELECT r.id, r.media_item_id, r.query, r.bot_reasoning,
       mi.vector_media_id, mi.title, mi.primary_creator, mi.cover_art_url,
       mi.description, mi.wiki_url, mi.wikidata_id, mi.themes,
       mt.name as media_type, rs.name as status,
       r.created_at, r.updated_at
FROM recommendations r
JOIN media_items mi ON r.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
JOIN recommendation_status rs ON r.status_id = rs.id
LEFT JOIN watchlist w ON mi.id = w.media_item_id
WHERE mt.name = ? AND rs.name = 'pending' AND w.media_item_id IS NULL
ORDER BY r.created_at DESC;
''';

// Get watchlist items (legacy compatibility)
const String getWatchlistItemsQuery = '''
SELECT 
  COALESCE(r.id, -mi.id) as id, -- Use negative media_item_id for user-added items to ensure unique IDs
  mi.id as media_item_id, 
  COALESCE(r.query, 'User Added') as query, 
  COALESCE(r.bot_reasoning, 'Added from search') as bot_reasoning,
  mi.vector_media_id, mi.title, mi.primary_creator, mi.cover_art_url,
  mi.description, mi.wiki_url, mi.wikidata_id, mi.themes,
  mt.name as media_type, 
  COALESCE(rs.name, 'added') as status, -- Default status for user-added items
  COALESCE(r.created_at, w.created_at) as created_at, 
  COALESCE(r.updated_at, w.created_at) as updated_at, 
  w.created_at as watchlist_added_at
FROM watchlist w
JOIN media_items mi ON w.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
LEFT JOIN recommendations r ON w.recommendation_id = r.id
LEFT JOIN recommendation_status rs ON r.status_id = rs.id
WHERE mt.name = ?
ORDER BY w.created_at DESC;
''';

// Add to watchlist (legacy compatibility - by recommendation ID)
const String addToWatchlistQuery = '''
INSERT OR IGNORE INTO watchlist (media_item_id, recommendation_id, created_at)
SELECT r.media_item_id, ?, ?
FROM recommendations r
WHERE r.id = ?;
''';

// Remove from watchlist (legacy compatibility - by recommendation ID)
const String removeFromWatchlistByRecommendationQuery = '''
DELETE FROM watchlist 
WHERE recommendation_id = ?;
''';

// Check if recommendation is in watchlist (legacy compatibility)
const String isInWatchlistByRecommendationQuery = '''
SELECT COUNT(*) as count FROM watchlist WHERE recommendation_id = ?;
''';

// Get user added favorites (legacy compatibility)
const String getUserAddedFavoritesForMediaQuery = '''
SELECT mi.id, mi.title, mi.primary_creator, mi.vector_media_id,
       mi.cover_art_url, mi.themes, uf.created_at
FROM user_favorites uf
JOIN media_items mi ON uf.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
WHERE mt.name = ? AND uf.recommendation_id IS NULL
ORDER BY uf.created_at DESC;
''';

// Get all user added favorites (legacy compatibility)
const String getAllUserAddedFavoritesQuery = '''
SELECT mi.id, mi.title, mi.primary_creator, mi.vector_media_id,
       mi.cover_art_url, mi.themes, uf.created_at, mt.name as media_type
FROM user_favorites uf
JOIN media_items mi ON uf.media_item_id = mi.id
JOIN media_types mt ON mi.media_type_id = mt.id
WHERE uf.recommendation_id IS NULL
ORDER BY uf.created_at DESC;
''';

// Delete user added favorite (legacy compatibility)
const String deleteUserAddedFavoriteQuery = '''
DELETE FROM user_favorites WHERE id = ?;
''';

// Insert user added favorite (legacy compatibility)
const String insertUserAddedFavoriteQuery = '''
INSERT INTO user_favorites (media_item_id, created_at)
SELECT mi.id, ?
FROM media_items mi
JOIN media_types mt ON mi.media_type_id = mt.id
WHERE mi.title = ? AND mi.primary_creator = ? AND mt.name = ?;
''';