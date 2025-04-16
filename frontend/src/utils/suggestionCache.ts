import { MediaSuggestionItem } from "@/components/common/MediaSuggestionDisplay";

/**
 * A utility for caching and retrieving media suggestions
 * to provide a consistent experience across different media types
 */
export class SuggestionCache {
  /**
   * Checks if localStorage is available
   * @returns True if localStorage is available, false otherwise
   */
  private static isLocalStorageAvailable(): boolean {
    try {
      const testKey = '__test_storage__';
      localStorage.setItem(testKey, testKey);
      localStorage.removeItem(testKey);
      return true;
    } catch (e) {
      console.error('[SuggestionCache] localStorage is not available:', e);
      return false;
    }
  }

  /**
   * Saves a media item and its reason to localStorage
   * @param mediaType The type of media (movie, music, book, etc.)
   * @param item The suggestion item to cache
   * @param reason The reason for the suggestion
   */
  static saveItem(mediaType: string, item: MediaSuggestionItem, reason: string): void {
    if (!this.isLocalStorageAvailable()) {
      console.error('[SuggestionCache] Cannot save - localStorage not available');
      return;
    }

    if (!item || !reason) {
      console.log(`[SuggestionCache] Not saving ${mediaType} - missing item or reason`);
      return;
    }
    
    try {
      const itemKey = `cached_${mediaType}_suggestion`;
      const reasonKey = `cached_${mediaType}_reason`;
      
      const itemJson = JSON.stringify(item);
      
      console.log(`[SuggestionCache] Saving to localStorage: ${itemKey}`, { item, itemJson });
      localStorage.setItem(itemKey, itemJson);
      localStorage.setItem(reasonKey, reason);
      
      // Verify the save worked
      const savedItem = localStorage.getItem(itemKey);
      const savedReason = localStorage.getItem(reasonKey);
      console.log(`[SuggestionCache] Verification after save:`, { 
        savedItem, 
        savedReason,
        success: !!savedItem && !!savedReason 
      });
    } catch (error) {
      console.error(`[SuggestionCache] Error saving ${mediaType} suggestion:`, error);
    }
  }

  /**
   * Retrieves a cached suggestion for the specified media type
   * @param mediaType The type of media (movie, music, book, etc.)
   * @returns Object containing the cached item and reason, or null if not found
   */
  static getItem(mediaType: string): { item: MediaSuggestionItem | null, reason: string | null } {
    if (!this.isLocalStorageAvailable()) {
      console.error('[SuggestionCache] Cannot get item - localStorage not available');
      return { item: null, reason: null };
    }

    try {
      const itemKey = `cached_${mediaType}_suggestion`;
      const reasonKey = `cached_${mediaType}_reason`;
      
      const itemJson = localStorage.getItem(itemKey);
      const reason = localStorage.getItem(reasonKey);
      
      console.log(`[SuggestionCache] Retrieved from localStorage: ${itemKey}`, { itemJson, reason });
      
      if (!itemJson || !reason) {
        console.log(`[SuggestionCache] No cached ${mediaType} suggestion found`);
        return { item: null, reason: null };
      }
      
      try {
        const item = JSON.parse(itemJson);
        console.log(`[SuggestionCache] Successfully parsed ${mediaType} suggestion:`, item);
        return { item, reason };
      } catch (parseError) {
        console.error(`[SuggestionCache] Error parsing ${mediaType} suggestion JSON:`, parseError);
        return { item: null, reason: null };
      }
    } catch (error) {
      console.error(`[SuggestionCache] Error retrieving cached ${mediaType} suggestion:`, error);
      return { item: null, reason: null };
    }
  }

  /**
   * Clears the cached suggestion for the specified media type
   * @param mediaType The type of media (movie, music, book, etc.)
   */
  static clearItem(mediaType: string): void {
    if (!this.isLocalStorageAvailable()) {
      console.error('[SuggestionCache] Cannot clear item - localStorage not available');
      return;
    }

    try {
      const itemKey = `cached_${mediaType}_suggestion`;
      const reasonKey = `cached_${mediaType}_reason`;
      
      console.log(`[SuggestionCache] Clearing ${mediaType} suggestion from localStorage`);
      localStorage.removeItem(itemKey);
      localStorage.removeItem(reasonKey);
      
      // Verify the clear worked
      const itemGone = !localStorage.getItem(itemKey);
      const reasonGone = !localStorage.getItem(reasonKey);
      console.log(`[SuggestionCache] Verification after clear:`, { 
        itemGone, 
        reasonGone,
        success: itemGone && reasonGone 
      });
    } catch (error) {
      console.error(`[SuggestionCache] Error clearing ${mediaType} suggestion:`, error);
    }
  }

  /**
   * Validates if a cached item is still valid by executing the provided validation function
   * @param mediaType The type of media (movie, music, book, etc.)
   * @param validationFn A function that validates if the item is still valid
   * @returns Promise that resolves to true if valid, false otherwise
   */
  static async validateItem(
    mediaType: string, 
    validationFn: (item: MediaSuggestionItem) => Promise<boolean>
  ): Promise<boolean> {
    const { item } = this.getItem(mediaType);
    
    if (!item) {
      console.log(`[SuggestionCache] No cached ${mediaType} suggestion to validate`);
      return false;
    }
    
    try {
      console.log(`[SuggestionCache] Validating ${mediaType} suggestion:`, item);
      const isValid = await validationFn(item);
      console.log(`[SuggestionCache] Validation result for ${mediaType}:`, isValid);
      
      if (!isValid) {
        console.log(`[SuggestionCache] ${mediaType} suggestion invalid, clearing cache`);
        this.clearItem(mediaType);
      }
      
      return isValid;
    } catch (error) {
      console.error(`[SuggestionCache] Error validating ${mediaType} suggestion:`, error);
      this.clearItem(mediaType);
      return false;
    }
  }
} 