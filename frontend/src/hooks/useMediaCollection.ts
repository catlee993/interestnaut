import { useState, useEffect } from 'react';
import { useSnackbar } from 'notistack';
import { MediaItem } from '@/components/common/MediaCard';

// Generic interface for API functions
interface MediaAPI<T, S> {
  getFavorites: () => Promise<S[] | null>;
  setFavorites: (items: S[]) => Promise<void>;
  search: (query: string) => Promise<T[]>;
  getDetails: (id: number) => Promise<T | null>;
  getWatchlist: () => Promise<S[] | null>;
  addToWatchlist: (item: S) => Promise<void>;
  removeFromWatchlist: (title: string) => Promise<void>;
}

// Mapper function type to convert between API types and MediaItem
type ItemMapper<T, S> = {
  toMediaItem: (item: T, isSaved: boolean) => MediaItem;
  fromMediaItem: (item: MediaItem) => S;
  isItemEqual: (item1: MediaItem, item2: MediaItem) => boolean;
  fromApiItem: (item: S) => Partial<MediaItem>; // For saved items from the API
}

export function useMediaCollection<T, S>(
  api: MediaAPI<T, S>,
  mapper: ItemMapper<T, S>,
  mediaType: 'movie' | 'tv',
) {
  const { enqueueSnackbar } = useSnackbar();
  const [savedItems, setSavedItems] = useState<MediaItem[]>([]);
  const [watchlistItems, setWatchlistItems] = useState<MediaItem[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  // Load saved items
  const loadSavedItems = async () => {
    try {
      const favorites = await api.getFavorites();
      const items = favorites || [];
      
      const itemsWithDetails: MediaItem[] = [];

      let apiCallCount = 0;
      const MAX_API_CALLS = 5;

      for (const item of items) {
        const basicItemData = mapper.fromApiItem(item);
        
        // If we have the poster path, create a basic item
        if (basicItemData.poster_path) {
          itemsWithDetails.push({
            id: 0,
            title: basicItemData.title || '',
            overview: '',
            poster_path: basicItemData.poster_path,
            vote_average: 0,
            vote_count: 0,
            isSaved: true,
            director: basicItemData.director || '',
            writer: basicItemData.writer || '',
            mediaType
          });
        } else if (apiCallCount >= MAX_API_CALLS) {
          // If we've hit API call limit, create a basic item
          itemsWithDetails.push({
            id: 0,
            title: basicItemData.title || '',
            overview: '',
            poster_path: '',
            vote_average: 0,
            vote_count: 0,
            isSaved: true,
            director: basicItemData.director || '',
            writer: basicItemData.writer || '',
            mediaType
          });
        } else {
          try {
            // Try to search for detailed info
            const searchResults = await api.search(basicItemData.title || '');
            apiCallCount++;

            if (searchResults && searchResults.length > 0) {
              // Use first result
              const matchedItem = searchResults[0];
              const mediaItem = mapper.toMediaItem(matchedItem, true);
              
              // Preserve additional data from saved item
              itemsWithDetails.push({
                ...mediaItem,
                director: basicItemData.director || mediaItem.director || '',
                writer: basicItemData.writer || mediaItem.writer || ''
              });
            } else {
              // No match found, create basic item
              itemsWithDetails.push({
                id: 0,
                title: basicItemData.title || '',
                overview: '',
                poster_path: '',
                vote_average: 0,
                vote_count: 0,
                isSaved: true,
                director: basicItemData.director || '',
                writer: basicItemData.writer || '',
                mediaType
              });
            }
          } catch (error) {
            console.error(`Failed to fetch details for "${basicItemData.title}":`, error);
            // Add basic entry
            itemsWithDetails.push({
              id: 0,
              title: basicItemData.title || '',
              overview: '',
              poster_path: '',
              vote_average: 0,
              vote_count: 0,
              isSaved: true,
              director: basicItemData.director || '',
              writer: basicItemData.writer || '',
              mediaType
            });
          }
        }
      }

      setSavedItems(itemsWithDetails);
      return itemsWithDetails;
    } catch (error) {
      console.error(`Failed to load saved ${mediaType}s:`, error);
      enqueueSnackbar(`Failed to load your ${mediaType} library`, {
        variant: "error",
      });
      return [];
    }
  };

  // Load watchlist items
  const loadWatchlistItems = async () => {
    try {
      const watchlist = await api.getWatchlist();
      
      if (!watchlist || watchlist.length === 0) {
        setWatchlistItems([]);
        return;
      }
      
      const itemsWithDetails: MediaItem[] = [];
      
      let apiCallCount = 0;
      const MAX_API_CALLS = 5;

      for (const item of watchlist) {
        const basicItemData = mapper.fromApiItem(item);
        
        // Check if this item is in favorites by comparing titles
        const isSaved = savedItems.some(saved => saved.title === (basicItemData.title || ''));
        
        // If we have the poster path, create a basic item
        if (basicItemData.poster_path) {
          itemsWithDetails.push({
            id: 0,
            title: basicItemData.title || '',
            overview: '',
            poster_path: basicItemData.poster_path,
            vote_average: 0,
            vote_count: 0,
            isSaved,
            director: basicItemData.director || '',
            writer: basicItemData.writer || '',
            mediaType
          });
        } else if (apiCallCount >= MAX_API_CALLS) {
          // If we've hit API call limit, create a basic item
          itemsWithDetails.push({
            id: 0,
            title: basicItemData.title || '',
            overview: '',
            poster_path: '',
            vote_average: 0,
            vote_count: 0,
            isSaved,
            director: basicItemData.director || '',
            writer: basicItemData.writer || '',
            mediaType
          });
        } else {
          try {
            // Try to search for detailed info
            const searchResults = await api.search(basicItemData.title || '');
            apiCallCount++;

            if (searchResults && searchResults.length > 0) {
              // Use first result
              const matchedItem = searchResults[0];
              const mediaItem = mapper.toMediaItem(matchedItem, isSaved);
              
              // Preserve additional data from watchlist item
              itemsWithDetails.push({
                ...mediaItem,
                director: basicItemData.director || mediaItem.director || '',
                writer: basicItemData.writer || mediaItem.writer || ''
              });
            } else {
              // No match found, create basic item
              itemsWithDetails.push({
                id: 0,
                title: basicItemData.title || '',
                overview: '',
                poster_path: '',
                vote_average: 0,
                vote_count: 0,
                isSaved,
                director: basicItemData.director || '',
                writer: basicItemData.writer || '',
                mediaType
              });
            }
          } catch (error) {
            console.error(`Failed to fetch details for "${basicItemData.title}":`, error);
            // Add basic entry
            itemsWithDetails.push({
              id: 0,
              title: basicItemData.title || '',
              overview: '',
              poster_path: '',
              vote_average: 0,
              vote_count: 0,
              isSaved,
              director: basicItemData.director || '',
              writer: basicItemData.writer || '',
              mediaType
            });
          }
        }
      }
      
      setWatchlistItems(itemsWithDetails);
    } catch (error) {
      console.error(`Failed to load ${mediaType} watchlist:`, error);
      enqueueSnackbar(`Failed to load your ${mediaType} watchlist`, { 
        variant: "error" 
      });
    }
  };

  // Toggle saved status (add/remove from library)
  const toggleSaved = async (item: MediaItem) => {
    try {
      setIsLoading(true);
      
      const favorites = await api.getFavorites();
      const items = favorites || [];

      if (item.isSaved) {
        // Remove from saved items
        const updatedFavorites = items.filter(
          (fav) => mapper.fromApiItem(fav).title !== item.title
        );

        // Update backend
        await api.setFavorites(updatedFavorites);

        // Update local state
        setSavedItems((prev) => prev.filter((i) => i.title !== item.title));
        enqueueSnackbar(`Removed "${item.title}" from your library`, {
          variant: "success",
        });
      } else {
        // Check for duplicates
        const exists = items.some(i => mapper.fromApiItem(i).title === item.title);
        if (exists) {
          enqueueSnackbar(`"${item.title}" is already in your library`, {
            variant: "info",
          });
          return;
        }
        
        // Get additional details if needed and ID > 0
        let directorName = item.director || '';
        if (item.id > 0 && !directorName) {
          try {
            const details = await api.getDetails(item.id);
            if (details) {
              const detailedItem = mapper.toMediaItem(details, false);
              directorName = detailedItem.director || '';
            }
          } catch (error) {
            console.error(`Failed to fetch details for "${item.title}":`, error);
          }
        }
        
        // Create API item from MediaItem
        const itemToAdd = mapper.fromMediaItem({
          ...item,
          director: directorName,
          isSaved: true
        });
        
        // Update backend
        await api.setFavorites([...items, itemToAdd]);

        // Update local state
        setSavedItems((prev) => [...prev, { 
          ...item, 
          isSaved: true,
          director: directorName 
        }]);
        
        enqueueSnackbar(`Added "${item.title}" to your library`, {
          variant: "success",
        });
      }
    } catch (error) {
      console.error(`Failed to update ${mediaType}:`, error);
      enqueueSnackbar("Failed to update library status", { variant: "error" });
    } finally {
      setIsLoading(false);
    }
  };

  // Add to watchlist
  const addToWatchlist = async (item: MediaItem) => {
    try {
      setIsLoading(true);
      
      // Check if already in watchlist
      const isInWatchlist = watchlistItems.some(i => i.title === item.title);
      if (isInWatchlist) {
        enqueueSnackbar(`"${item.title}" is already in your watchlist`, {
          variant: "info",
        });
        return;
      }
      
      // Get additional details if needed and ID > 0
      let directorName = item.director || '';
      if (item.id > 0 && !directorName) {
        try {
          const details = await api.getDetails(item.id);
          if (details) {
            const detailedItem = mapper.toMediaItem(details, false);
            directorName = detailedItem.director || '';
          }
        } catch (error) {
          console.error(`Failed to fetch details for "${item.title}":`, error);
        }
      }
      
      // Create API item from MediaItem
      const itemToAdd = mapper.fromMediaItem({
        ...item,
        director: directorName
      });
      
      // Add to watchlist
      await api.addToWatchlist(itemToAdd);
      
      // Update local state
      setWatchlistItems(prev => [
        ...prev, 
        { 
          ...item, 
          director: directorName 
        }
      ]);
      
      enqueueSnackbar(`Added "${item.title}" to your watchlist`, {
        variant: "success",
      });
    } catch (error) {
      console.error(`Failed to add ${mediaType} to watchlist:`, error);
      enqueueSnackbar("Failed to add to watchlist", { variant: "error" });
    } finally {
      setIsLoading(false);
    }
  };

  // Remove from watchlist
  const removeFromWatchlist = async (item: MediaItem) => {
    try {
      setIsLoading(true);
      
      // Remove from watchlist
      await api.removeFromWatchlist(item.title);
      
      // Update local state
      setWatchlistItems(prev => prev.filter(i => i.title !== item.title));
      
      enqueueSnackbar(`Removed "${item.title}" from your watchlist`, {
        variant: "success",
      });
    } catch (error) {
      console.error(`Failed to remove ${mediaType} from watchlist:`, error);
      enqueueSnackbar("Failed to remove from watchlist", { variant: "error" });
    } finally {
      setIsLoading(false);
    }
  };

  // Check if an item is in the watchlist
  const isInWatchlist = (item: MediaItem) => {
    return watchlistItems.some(i => mapper.isItemEqual(i, item));
  };

  // Check if an item is saved
  const isSaved = (item: MediaItem) => {
    return savedItems.some(i => mapper.isItemEqual(i, item));
  };

  return {
    savedItems,
    watchlistItems,
    isLoading,
    loadSavedItems,
    loadWatchlistItems,
    toggleSaved,
    addToWatchlist,
    removeFromWatchlist,
    isInWatchlist,
    isSaved
  };
} 