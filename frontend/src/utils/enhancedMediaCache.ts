import { MediaSuggestionItem } from "@/components/common/MediaSuggestionDisplay";
import { SuggestionCache } from "@/utils/suggestionCache";

/**
 * Enhanced MediaSuggestionItem with customFields for extra metadata
 */
export interface EnhancedMediaSuggestionItem extends MediaSuggestionItem {
  customFields?: {
    [key: string]: any; // Any additional media-specific fields
  };
}

/**
 * Creates an enhanced media suggestion item from a source object
 * @param sourceItem The source media item
 * @param standardMapping Standard field mappings
 * @param customFields Custom media-specific fields to preserve
 * @returns Enhanced media suggestion item ready for caching
 */
export function createEnhancedMediaItem<T>(
  sourceItem: T,
  standardMapping: {
    id: number | string;
    title: string;
    description?: string;
    artist?: string;
    imageUrl?: string;
  },
  customFields: Record<string, any>
): EnhancedMediaSuggestionItem {
  return {
    ...standardMapping,
    customFields: {
      ...customFields
    }
  };
}

/**
 * Extracts a media-specific item from a cached suggestion
 * @param cachedItem The cached enhanced media suggestion item
 * @param defaultValues Default values for required fields
 * @param customFieldsMapping Function to map custom fields back to the target type
 * @returns Media-specific item restored from cache
 */
export function extractFromCachedItem<T>(
  cachedItem: EnhancedMediaSuggestionItem,
  defaultValues: Partial<T>,
  customFieldsMapping: (customFields: Record<string, any>) => Partial<T>
): T {
  const customFields = cachedItem.customFields || {};
  
  // Extract standard fields
  const standardFields = {
    id: typeof cachedItem.id === 'number' ? cachedItem.id : parseInt(cachedItem.id as string, 10) || 0,
    title: cachedItem.title || "",
    description: cachedItem.description || "",
    // Add other standard field mappings
  };
  
  // Get custom field mappings
  const customMappings = customFieldsMapping(customFields);
  
  // Combine everything with defaults
  return {
    ...defaultValues,
    ...standardFields,
    ...customMappings
  } as T;
}

/**
 * Save an enhanced media item to cache
 * @param mediaType The type of media (movie, book, tv, etc.)
 * @param sourceItem The source media item
 * @param reason The reason for the suggestion
 * @param standardMapping Standard field mappings
 * @param customFields Custom media-specific fields to preserve
 */
export function saveEnhancedMedia<T>(
  mediaType: string,
  sourceItem: T,
  reason: string,
  standardMapping: {
    id: number | string;
    title: string;
    description?: string;
    artist?: string;
    imageUrl?: string;
  },
  customFields: Record<string, any>
): void {
  const enhancedItem = createEnhancedMediaItem(
    sourceItem,
    standardMapping,
    customFields
  );
  
  SuggestionCache.saveItem(mediaType, enhancedItem, reason);
}

/**
 * Gets the best available image URL from a media suggestion item
 * @param item The media suggestion item with possible customFields
 * @param mediaType The media type (book, movie, tv, game)
 * @returns Best available image URL
 */
export function getBestImageUrl(
  item: EnhancedMediaSuggestionItem | MediaSuggestionItem,
  mediaType: string
): string | undefined {
  // First try the standard imageUrl
  let imageUrl = item.imageUrl;
  const enhancedItem = item as EnhancedMediaSuggestionItem;
  
  // If this is an enhanced item with customFields
  if (enhancedItem.customFields) {
    // Get type-specific image property
    if (mediaType === "book" && enhancedItem.customFields.cover_path) {
      imageUrl = enhancedItem.customFields.cover_path;
    }
    else if (mediaType === "movie" && enhancedItem.customFields.poster_path) {
      imageUrl = enhancedItem.customFields.poster_path;
    }
    else if (mediaType === "tv" && enhancedItem.customFields.poster_path) {
      imageUrl = enhancedItem.customFields.poster_path;
    }
    else if (mediaType === "game" && enhancedItem.customFields.background_image) {
      imageUrl = enhancedItem.customFields.background_image;
    }
  }
  
  return imageUrl;
}

/**
 * Creates a useEffect hook that can be used in any media component to enhance caching
 * @param mediaType The type of media (movie, book, tv, game)
 * @param suggestedItem The current suggested item
 * @param suggestionReason The reason for the suggestion 
 * @returns A function to add to a component to ensure proper caching
 */
export function createEnhancedCachingEffect(
  mediaType: string, 
  suggestedItem: any, 
  suggestionReason: string | null
): () => void {
  return () => {
    if (!suggestedItem || !suggestionReason) return;
    
    console.log(`Enhancing cached ${mediaType} suggestion on tab switch`);
    
    // Create standard mapping for all media types
    const standardMapping = {
      id: suggestedItem.id,
      title: suggestedItem.title || suggestedItem.name || '',
      description: suggestedItem.description || suggestedItem.overview || '',
      imageUrl: suggestedItem.cover_path || suggestedItem.poster_path || suggestedItem.background_image || '',
    };
    
    // Create custom fields based on media type
    let customFields: Record<string, any> = {
      // Common fields
      isSaved: suggestedItem.isSaved,
      isInWatchlist: suggestedItem.isInWatchlist,
    };
    
    // Add media-specific fields
    if (mediaType === 'book') {
      customFields = {
        ...customFields,
        author: suggestedItem.author,
        key: suggestedItem.key,
        cover_path: suggestedItem.cover_path,
        year: suggestedItem.year,
        subjects: suggestedItem.subjects,
      };
    }
    else if (mediaType === 'movie') {
      customFields = {
        ...customFields,
        poster_path: suggestedItem.poster_path,
        backdrop_path: suggestedItem.backdrop_path,
        overview: suggestedItem.overview,
        release_date: suggestedItem.release_date,
        vote_average: suggestedItem.vote_average,
        vote_count: suggestedItem.vote_count,
        genres: suggestedItem.genres,
      };
    }
    else if (mediaType === 'tv') {
      customFields = {
        ...customFields,
        name: suggestedItem.name,
        poster_path: suggestedItem.poster_path,
        backdrop_path: suggestedItem.backdrop_path,
        overview: suggestedItem.overview,
        first_air_date: suggestedItem.first_air_date,
        vote_average: suggestedItem.vote_average,
        vote_count: suggestedItem.vote_count,
        genres: suggestedItem.genres,
        number_of_seasons: suggestedItem.number_of_seasons,
      };
    }
    else if (mediaType === 'game') {
      customFields = {
        ...customFields,
        name: suggestedItem.name,
        background_image: suggestedItem.background_image,
        description_raw: suggestedItem.description_raw,
        released: suggestedItem.released,
        rating: suggestedItem.rating,
        ratings_count: suggestedItem.ratings_count,
        genres: suggestedItem.genres,
        platforms: suggestedItem.platforms,
        developers: suggestedItem.developers,
        publishers: suggestedItem.publishers,
      };
    }
    
    // Save to cache
    saveEnhancedMedia(
      mediaType,
      suggestedItem,
      suggestionReason,
      standardMapping,
      customFields
    );
  };
} 