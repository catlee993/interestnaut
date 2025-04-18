import { useState, useEffect, useCallback } from 'react';
import { MediaSuggestionItem } from '@/components/common/MediaSuggestionDisplay';
import { SuggestionCache } from '@/utils/suggestionCache';

type ValidationFunction = (item: MediaSuggestionItem) => Promise<boolean>;

/**
 * Hook for managing suggestion caching for any media type
 * @param mediaType The type of media (movies, music, etc.)
 * @param validationFn Optional function to validate if a cached suggestion is still valid
 * @returns Functions and state for managing cached suggestions
 */
export function useSuggestionCache(
  mediaType: string, 
  validationFn?: ValidationFunction
) {
  const [cachedItem, setCachedItem] = useState<MediaSuggestionItem | null>(null);
  const [cachedReason, setCachedReason] = useState<string | null>(null);
  const [isValidating, setIsValidating] = useState(false);

  // Load cached suggestion on mount
  useEffect(() => {
    console.log(`[useSuggestionCache] Initializing for ${mediaType}`);
    loadCachedSuggestion();
  }, [mediaType]);

  // Load the cached suggestion
  const loadCachedSuggestion = useCallback(async () => {
    console.log(`[useSuggestionCache] Loading cached ${mediaType} suggestion`);
    const { item, reason } = SuggestionCache.getItem(mediaType);
    console.log(`[useSuggestionCache] Cache result for ${mediaType}:`, { item, reason });
    
    if (item && reason) {
      // If validation function is provided, validate the item
      if (validationFn) {
        setIsValidating(true);
        try {
          const isValid = await SuggestionCache.validateItem(mediaType, validationFn);
          if (isValid) {
            console.log(`[useSuggestionCache] ${mediaType} cached item is valid, setting state`);
            setCachedItem(item);
            setCachedReason(reason);
          } else {
            console.log(`[useSuggestionCache] Cached ${mediaType} suggestion is no longer valid`);
          }
        } catch (error) {
          console.error(`[useSuggestionCache] Error validating ${mediaType} suggestion:`, error);
        } finally {
          setIsValidating(false);
        }
      } else {
        // No validation needed, just use the cached item
        console.log(`[useSuggestionCache] No validation needed for ${mediaType}, using cached data`);
        setCachedItem(item);
        setCachedReason(reason);
      }
    } else {
      console.log(`[useSuggestionCache] No cached ${mediaType} suggestion found`);
    }
  }, [mediaType, validationFn]);

  // Save a suggestion to cache
  const saveSuggestion = useCallback((item: MediaSuggestionItem, reason: string) => {
    if (!item || !reason) return;
    
    console.log(`[useSuggestionCache] Saving ${mediaType} suggestion to cache:`, { item, reason });
    SuggestionCache.saveItem(mediaType, item, reason);
    setCachedItem(item);
    setCachedReason(reason);
  }, [mediaType]);

  // Clear the cached suggestion
  const clearSuggestion = useCallback(() => {
    console.log(`[useSuggestionCache] Clearing ${mediaType} suggestion cache`);
    SuggestionCache.clearItem(mediaType);
    setCachedItem(null);
    setCachedReason(null);
  }, [mediaType]);

  return {
    cachedItem,
    cachedReason,
    isValidating,
    saveSuggestion,
    clearSuggestion,
    loadCachedSuggestion
  };
} 