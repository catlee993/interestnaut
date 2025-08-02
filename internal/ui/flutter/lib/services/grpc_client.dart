import 'package:grpc/grpc.dart';
import '../generated/recommendation.pbgrpc.dart';
import 'recommendation_service.dart';

/// gRPC client for communicating with the Go recommendation backend
class GrpcRecommendationClient {
  static const String _host = 'localhost';
  static const int _port = 8080;
  
  late ClientChannel _channel;
  late RecommendationServiceClient _client;
  bool _initialized = false;
  
  
  static final GrpcRecommendationClient _instance = GrpcRecommendationClient._internal();
  factory GrpcRecommendationClient() => _instance;
  GrpcRecommendationClient._internal();
  
  /// Initialize the gRPC client connection
  Future<void> init() async {
    try {
      _channel = ClientChannel(
        _host,
        port: _port,
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
        ),
      );
      
      _client = RecommendationServiceClient(_channel);
      _initialized = true;
      
      // Test connection with health check
      await healthCheck();
      print('✅ gRPC client initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize gRPC client: $e');
      _initialized = false;
      rethrow;
    }
  }
  
  /// Check if the client is initialized and connected
  bool get isInitialized => _initialized;
  
  /// Health check to verify backend connection
  Future<Map<String, dynamic>> healthCheck() async {
    if (!_initialized) {
      throw Exception('gRPC client not initialized');
    }
    
    try {
      final request = HealthCheckRequest();
      final response = await _client.healthCheck(request);
      
      return {
        'healthy': response.healthy,
        'version': response.version,
        'database_status': response.databaseStatus,
      };
    } catch (e) {
      print('❌ Health check failed: $e');
      rethrow;
    }
  }
  
  /// Get personalized recommendations from the backend
  Future<List<MediaSuggestion>> getRecommendations({
    required String mediaType,
    String? userQuery,
    List<String> likedMediaIds = const [],
    List<String> favoritedMediaIds = const [],
    List<String> watchlistMediaIds = const [],
    List<String> dislikedMediaIds = const [],
    List<String> skippedMediaIds = const [],
    List<String> excludeMediaIds = const [],
    List<String> constraints = const [],
    int limit = 1,
    bool useBehavioralMatching = true,
    double similarityThreshold = 0.5, // Default to Versatile
    int attributesToMatch = 3, // Default number of themes/genres to match
    List<String> priorityTitleIds = const [],
  }) async {
    if (!_initialized) {
      throw Exception('gRPC client not initialized');
    }
    
    try {
      final request = RecommendationRequest()
        ..mediaType = mediaType
        ..userQuery = userQuery ?? ''
        ..likedMediaIds.addAll(likedMediaIds)
        ..favoritedMediaIds.addAll(favoritedMediaIds)
        ..watchlistMediaIds.addAll(watchlistMediaIds)
        ..dislikedMediaIds.addAll(dislikedMediaIds)
        ..skippedMediaIds.addAll(skippedMediaIds)
        ..excludeMediaIds.addAll(excludeMediaIds)
        ..constraints.addAll(constraints)
        ..limit = limit
        ..useBehavioralMatching = useBehavioralMatching
        ..similarityThreshold = similarityThreshold
        ..attributesToMatch = attributesToMatch
        ..priorityTitleIds.addAll(priorityTitleIds);
      
      print('🔄 Requesting recommendations for $mediaType with ${likedMediaIds.length} liked, ${dislikedMediaIds.length} disliked, ${excludeMediaIds.length} excluded');
      
      final response = await _client.getRecommendations(request);
      
      if (response.error.isNotEmpty) {
        throw Exception('Backend error: ${response.error}');
      }
      
      print('✅ Received ${response.recommendations.length} recommendations using ${response.metadata.algorithmUsed}');
      
      return response.recommendations.map((item) => _convertToMediaSuggestion(item, mediaType)).toList();
    } catch (e) {
      print('❌ Failed to get recommendations: $e');
      rethrow;
    }
  }
  
  /// Search for media with constraints
  Future<List<MediaSuggestion>> searchMedia({
    required String mediaType,
    List<String> constraints = const [],
    List<String> excludeMediaIds = const [],
    int limit = 10,
    int offset = 0,
  }) async {
    if (!_initialized) {
      throw Exception('gRPC client not initialized');
    }
    
    try {
      final request = SearchRequest()
        ..mediaType = mediaType
        ..constraints.addAll(constraints)
        ..excludeMediaIds.addAll(excludeMediaIds)
        ..limit = limit
        ..offset = offset;
      
      final response = await _client.searchMedia(request);
      
      if (response.error.isNotEmpty) {
        throw Exception('Backend error: ${response.error}');
      }
      
      return response.results.map((item) => _convertToMediaSuggestion(item, mediaType)).toList();
    } catch (e) {
      print('❌ Failed to search media: $e');
      rethrow;
    }
  }
  
  /// Get similar items to a reference media item
  Future<List<MediaSuggestion>> getSimilarItems({
    required String referenceMediaId,
    required String mediaType,
    List<String> excludeMediaIds = const [],
    int limit = 5,
  }) async {
    if (!_initialized) {
      throw Exception('gRPC client not initialized');
    }
    
    try {
      final request = SimilarItemsRequest()
        ..referenceMediaId = referenceMediaId
        ..mediaType = mediaType
        ..excludeMediaIds.addAll(excludeMediaIds)
        ..limit = limit;
      
      final response = await _client.getSimilarItems(request);
      
      if (response.error.isNotEmpty) {
        throw Exception('Backend error: ${response.error}');
      }
      
      return response.similarItems.map((item) => _convertToMediaSuggestion(item, mediaType)).toList();
    } catch (e) {
      print('❌ Failed to get similar items: $e');
      rethrow;
    }
  }
  
  /// Get random media items for exploration
  Future<List<MediaSuggestion>> getRandomMedia({
    required String mediaType,
    List<String> excludeMediaIds = const [],
    int limit = 1,
  }) async {
    if (!_initialized) {
      throw Exception('gRPC client not initialized');
    }
    
    try {
      final request = RandomMediaRequest()
        ..mediaType = mediaType
        ..excludeMediaIds.addAll(excludeMediaIds)
        ..limit = limit;
      
      final response = await _client.getRandomMedia(request);
      
      if (response.error.isNotEmpty) {
        throw Exception('Backend error: ${response.error}');
      }
      
      return response.items.map((item) => _convertToMediaSuggestion(item, mediaType)).toList();
    } catch (e) {
      print('❌ Failed to get random media: $e');
      rethrow;
    }
  }
  
  /// Search themes by query with limit
  Future<Map<String, dynamic>> searchThemes({
    required String mediaType,
    required String query,
    int limit = 50,
  }) async {
    if (!_initialized) {
      throw Exception('gRPC client not initialized');
    }
    
    try {
      final request = SearchThemesRequest()
        ..mediaType = mediaType
        ..query = query
        ..limit = limit;
      
      final response = await _client.searchThemes(request);
      
      if (response.error.isNotEmpty) {
        throw Exception('Backend error: ${response.error}');
      }
      
      return {
        'themes': response.themes,
        'totalCount': response.totalCount,
      };
    } catch (e) {
      print('❌ Failed to search themes: $e');
      rethrow;
    }
  }
  
  /// Search genres by query with limit
  Future<Map<String, dynamic>> searchGenres({
    required String mediaType,
    required String query,
    int limit = 50,
  }) async {
    if (!_initialized) {
      throw Exception('gRPC client not initialized');
    }
    
    try {
      final request = SearchGenresRequest()
        ..mediaType = mediaType
        ..query = query
        ..limit = limit;
      
      final response = await _client.searchGenres(request);
      
      if (response.error.isNotEmpty) {
        throw Exception('Backend error: ${response.error}');
      }
      
      return {
        'genres': response.genres,
        'totalCount': response.totalCount,
      };
    } catch (e) {
      print('❌ Failed to search genres: $e');
      rethrow;
    }
  }
  
  /// Get media details by media ID
  Future<MediaSuggestion?> getMediaDetails({
    required String mediaId,
    required String mediaType,
  }) async {
    if (!_initialized) {
      throw Exception('gRPC client not initialized');
    }
    
    try {
      final request = MediaDetailsRequest()
        ..mediaId = mediaId
        ..mediaType = mediaType;
      
      final response = await _client.getMediaDetails(request);
      
      if (response.error.isNotEmpty) {
        throw Exception('Backend error: ${response.error}');
      }
      
      if (response.hasMedia()) {
        return _convertToMediaSuggestion(response.media, mediaType);
      }
      
      return null;
    } catch (e) {
      print('❌ Failed to get media details: $e');
      rethrow;
    }
  }
  
  /// Convert gRPC MediaItem to Flutter MediaSuggestion
  MediaSuggestion _convertToMediaSuggestion(MediaItem item, String mediaType) {
    return MediaSuggestion(
      id: -1, // Will be set when saved to local database
      query: 'gRPC recommendation', // Not needed for gRPC responses
      mediaType: mediaType,
      title: item.title,
      artist: item.primaryCreator,
      album: item.album.isEmpty ? null : item.album,
      coverArtUrl: item.coverArtUrl.isEmpty ? null : item.coverArtUrl,
      description: item.description.isEmpty ? null : item.description,
      wikiUrl: item.wikiUrl.isEmpty ? null : item.wikiUrl,
      wikidataId: item.wikidataId.isEmpty ? null : item.wikidataId,
      themes: item.themes.isEmpty ? null : item.themes,
      botReasoning: item.reasoning.isEmpty ? 'Recommended based on your preferences' : item.reasoning,
      mediaId: item.mediaId, // Store the vector database media ID
      youtubeId: item.youtubeId.isEmpty ? null : item.youtubeId,
      spotifyId: item.spotifyId.isEmpty ? null : item.spotifyId,
      status: SuggestionStatus.pending,
    );
  }
  
  /// Dispose of the gRPC client
  Future<void> dispose() async {
    if (_initialized) {
      await _channel.shutdown();
      _initialized = false;
    }
  }
} 