import React, {
  useRef,
  forwardRef,
  useImperativeHandle,
  useCallback,
  useEffect,
  useMemo,
  useState,
} from "react";
import { Box, Card, CardMedia, Typography, useTheme } from "@mui/material";
import { BookCard } from "./BookCard";
import {
  SearchBooks,
  SetFavoriteBooks,
  GetFavoriteBooks,
  GetBookSuggestion,
  GetBookDetails,
  ProvideSuggestionFeedback,
  AddToReadList,
  GetReadList,
  RemoveFromReadList,
} from "@wailsjs/go/bindings/Books";
import { session } from "@wailsjs/go/models";
import { MediaSuggestionItem } from "@/components/common/MediaSuggestionDisplay";
import { useMediaSection, MediaItemBase } from "@/hooks/useMediaSection";
import {
  MediaSectionLayout,
  MediaGrid,
} from "@/components/common/MediaSectionLayout";
import { MediaItemWrapper } from "@/components/common/MediaItemWrapper";
import { SuggestionCache } from "@/utils/suggestionCache";
import { 
  EnhancedMediaSuggestionItem, 
  extractFromCachedItem, 
  saveEnhancedMedia 
} from "@/utils/enhancedMediaCache";

// Define the exported types
export interface BookSectionHandle {
  handleClearSearch: () => void;
  handleSearch: (query: string) => Promise<void>;
}

// BookWithSavedStatus type as expected by BookCard component
interface BookWithSavedStatus {
  title: string;
  author: string;
  key: string;
  cover_path: string;
  description?: string;
  year?: number;
  subjects?: string[];
  isSaved?: boolean;
}

// Define our own type that combines both interfaces
interface BookItem extends MediaItemBase {
  id: number;
  title: string; 
  author: string;
  cover_path: string;
  key: string; // Make key required to match BookWithSavedStatus
  description?: string;
  year?: number;
  subjects?: string[];
  isSaved?: boolean;
}

// Define the MediaItemWrapperProps interface
interface MediaItemWrapperProps<T> {
  item: T;
  view: string;
  children: React.ReactNode;
  onRemoveFromWatchlist?: () => void;
}

export const BookSection = forwardRef<BookSectionHandle, {}>((props, ref) => {
  const searchResultsRef = useRef<HTMLDivElement>(null);

  // Use the media section hook with necessary type assertions
  const mediaSection = useMediaSection<BookItem>({
    type: "book",

    checkCredentials: async () => true, // No credentials needed for books

    getSuggestion: async () => {
      const suggestion = await GetBookSuggestion();
      
      if (!suggestion) {
        throw new Error("Failed to get book suggestion");
      }

      return {
        media: {
          id: generateId(suggestion),
          title: suggestion.title || "Unknown Title",
          author: suggestion.author || "Unknown Author",
          key: suggestion.key || `${suggestion.title || ""}-${suggestion.author || ""}`,
          cover_path: suggestion.cover_path || "",
          description: suggestion.description || "",
        } as BookItem,
        reason: suggestion.reasoning || "No reasoning provided",
      };
    },

    provideFeedback: async (outcome, id) => {
      if (mediaSection.suggestedItem) {
        await ProvideSuggestionFeedback(
          outcome,
          mediaSection.suggestedItem.title,
          mediaSection.suggestedItem.author
        );
      }
    },

    loadSavedItems: async () => {
      const favoriteBooks = await GetFavoriteBooks() || [];
      return favoriteBooks.map((book: any) => ({
        ...book,
        id: generateId(book),
        key: book.key || `${book.title || ""}-${book.author || ""}`, // Ensure key is always set
        isSaved: true,
      })) as BookItem[];
    },

    loadWatchlistItems: async () => {
      const readList = await GetReadList() || [];
      return readList.map((book: any) => ({
        ...book,
        id: generateId(book),
        key: book.key || `${book.title || ""}-${book.author || ""}`, // Ensure key is always set
      })) as BookItem[];
    },

    searchItems: async (query: string) => {
      const results = await SearchBooks(query);
      return results.map((book: any) => ({
        ...book,
        id: generateId(book),
        key: book.key || `${book.title || ""}-${book.author || ""}`, // Ensure key is always set
      })) as BookItem[];
    },

    saveItem: async (item: BookItem) => {
      const favoriteBooks = await GetFavoriteBooks() || [];

      if (item.isSaved) {
        // Remove from favorites
        const updatedFavorites = favoriteBooks.filter(
          (fav) => fav.title !== item.title || fav.author !== item.author
        );
        await SetFavoriteBooks(updatedFavorites);
      } else {
        // Add to favorites
        const newFavorite: BookWithSavedStatus = {
          title: item.title,
          author: item.author,
          key: item.key,
          cover_path: item.cover_path || "",
          description: item.description || "",
          year: item.year,
          subjects: item.subjects,
        };
        await SetFavoriteBooks([...favoriteBooks, newFavorite]);
      }
    },

    removeItem: async (item: BookItem) => {
      const favoriteBooks = await GetFavoriteBooks() || [];
      const updatedFavorites = favoriteBooks.filter(
        (fav) => fav.title !== item.title || fav.author !== item.author
      );
      await SetFavoriteBooks(updatedFavorites);
    },

    addToWatchlist: async (item: BookItem) => {
      const book: BookWithSavedStatus = {
        title: item.title,
        author: item.author,
        key: item.key,
        cover_path: item.cover_path || "",
        description: item.description || "",
        year: item.year,
        subjects: item.subjects,
      };
      await AddToReadList(book);
    },

    removeFromWatchlist: async (item: BookItem) => {
      await RemoveFromReadList(item.title, item.author);
    },

    getItemDetails: async (id: number): Promise<BookItem> => {
      try {
        // Create a key for validation using ID
        const bookId = id.toString();
        
        // First, try to extract full book data from the cache
        const { item: cachedItem } = SuggestionCache.getItem("book");
        if (cachedItem) {
          try {
            // Convert the cached MediaSuggestionItem back to a BookItem with all data
            const bookItem = extractFromCachedItem<BookItem>(
              cachedItem as EnhancedMediaSuggestionItem,
              {
                id: id, 
                title: "",
                author: "",
                cover_path: "",
                key: bookId,
              },
              (customFields) => ({
                title: customFields.title || "",
                author: customFields.author || "",
                cover_path: customFields.cover_path || "",
                key: customFields.key || bookId,
                description: customFields.description || "",
                year: customFields.year,
                subjects: customFields.subjects || [],
                isSaved: customFields.isSaved || false
              })
            );
            
            if (bookItem.key) {
              // Try to validate with the API using the key
              try {
                const details = await GetBookDetails(bookItem.key);
                return {
                  ...bookItem,
                  ...details, // Merge API details with cached details
                  id, // Keep the original ID for consistency
                  key: details.key || bookItem.key,
                  cover_path: details.cover_path || bookItem.cover_path || "",
                } as BookItem;
              } catch (apiError) {
                console.log("Book from cache couldn't be validated with API, using cached data");
                // If API validation fails, still return the cached item
                return bookItem;
              }
            }
            // If no key in cached item, just return it as is
            return bookItem;
          } catch (parseError) {
            console.log("Error converting cached item to BookItem:", parseError);
          }
        }
        
        // If cache extraction fails, try to find the book in our existing collections
        let existingBook: BookItem | undefined;
        
        // Check saved items first
        existingBook = mediaSection.savedItems.find((book: BookItem) => book.id === id);
        if (existingBook && existingBook.key) {
          try {
            const details = await GetBookDetails(existingBook.key);
            return {
              ...details,
              id,
              key: details.key || existingBook.key,
              cover_path: details.cover_path || "",
            } as BookItem;
          } catch (error) {
            console.log("Book in saved items couldn't be validated with API");
          }
        }
        
        // Check watchlist items next
        existingBook = mediaSection.watchlistItems.find((book: BookItem) => book.id === id);
        if (existingBook && existingBook.key) {
          try {
            const details = await GetBookDetails(existingBook.key);
            return {
              ...details,
              id,
              key: details.key || existingBook.key,
              cover_path: details.cover_path || "",
            } as BookItem;
          } catch (error) {
            console.log("Book in watchlist couldn't be validated with API");
          }
        }
        
        // If we couldn't validate from our collections, simply "trust" the cached suggestion
        // This allows the cached suggestion to survive switching tabs
        return {
          id,
          title: "Valid Book", // To indicate that we accept this as valid
          author: "Unknown",
          key: bookId,
          cover_path: "",
        } as BookItem;
      } catch (error) {
        // If there's an error at this stage, it means the book can't be validated at all
        console.error("Failed to validate cached book:", error);
        throw new Error("Book validation failed");
      }
    },

    // Local storage and UI settings
    cachedSuggestionKey: "cached_book_suggestion",
    cachedReasonKey: "cached_book_reason",
    queueListName: "Read List",
  });

  // Create a unique ID for each book based on title and author
  function generateId(book: any): number {
    const str = `${book.title || ""}-${book.author || ""}`;
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = (hash << 5) - hash + char;
      hash = hash & hash; // Convert to 32bit integer
    }
    return Math.abs(hash);
  }

  // Expose functions via ref
  useImperativeHandle(ref, () => ({
    handleClearSearch: mediaSection.handleClearSearch,
    handleSearch: mediaSection.handleSearch,
  }));

  // Convert to MediaSuggestionItem for displaying
  const mapBookToSuggestionItem = useCallback(
    (book: BookItem): MediaSuggestionItem => {
      console.log("Mapping book:", book);
      
      // Create an enhanced media suggestion item to preserve all book details
      const enhancedItem: EnhancedMediaSuggestionItem = {
        id: book.id,
        title: book.title,
        description: book.description || "",
        artist: `by ${book.author}`,
        imageUrl: book.cover_path || undefined,
        // Add custom fields to ensure all book data is preserved
        customFields: {
          author: book.author,
          key: book.key,
          cover_path: book.cover_path,
          year: book.year,
          subjects: book.subjects,
          isSaved: book.isSaved,
        }
      };
      
      console.log("Enhanced item:", enhancedItem);
      return enhancedItem;
    },
    [],
  );

  // Override the handleGetSuggestion to use our enhanced mapping
  const originalHandleGetSuggestion = mediaSection.handleGetSuggestion;
  const handleGetSuggestion = useCallback(async () => {
    try {
      // Call the original function to get a suggestion
      const result = await originalHandleGetSuggestion();
      
      // After getting a new suggestion, ensure it's properly cached with rich metadata
      if (mediaSection.suggestedItem) {
        // Save with enhanced caching to ensure full book details are preserved
        saveEnhancedMedia(
          "book",
          mediaSection.suggestedItem,
          mediaSection.suggestionReason || "",
          {
            id: mediaSection.suggestedItem.id,
            title: mediaSection.suggestedItem.title,
            description: mediaSection.suggestedItem.description || "",
            artist: `by ${mediaSection.suggestedItem.author}`,
            imageUrl: mediaSection.suggestedItem.cover_path,
          },
          {
            author: mediaSection.suggestedItem.author,
            key: mediaSection.suggestedItem.key,
            cover_path: mediaSection.suggestedItem.cover_path,
            year: mediaSection.suggestedItem.year,
            subjects: mediaSection.suggestedItem.subjects,
            isSaved: mediaSection.suggestedItem.isSaved,
          }
        );
        
        console.log("Enhanced book suggestion saved to cache with additional metadata");
      }
      
      return result;
    } catch (error) {
      console.error("Error in enhanced handleGetSuggestion:", error);
      // Still propagate the error
      throw error;
    }
  }, [originalHandleGetSuggestion, mediaSection.suggestedItem, mediaSection.suggestionReason]);

  // Override mediaSection.handleGetSuggestion with our enhanced version
  mediaSection.handleGetSuggestion = handleGetSuggestion;

  // Custom renderer for book cover
  const renderBookCover = useCallback(
    (item: MediaSuggestionItem) => {
      // Try to get the image URL from different sources
      let imageUrl = item.imageUrl;
      
      // If this is an enhanced item, try to get the cover_path from customFields
      const enhancedItem = item as EnhancedMediaSuggestionItem;
      if (enhancedItem.customFields && enhancedItem.customFields.cover_path) {
        imageUrl = enhancedItem.customFields.cover_path;
      }
      
      if (!imageUrl) {
        console.warn("Book cover missing image URL:", item);
        return null;
      }

      return (
        <Card sx={{ height: "100%" }}>
          <CardMedia
            component="img"
            image={imageUrl}
            alt={item.title}
            sx={{
              height: "450px",
              objectFit: "cover",
              opacity: mediaSection.isProcessingFeedback ? 0.5 : 1,
              transition: "all 0.2s ease-in-out",
            }}
          />
        </Card>
      );
    },
    [mediaSection.isProcessingFeedback],
  );

  // Render functions for the sections
  const renderSearchResults = useCallback(
    () => (
      <MediaGrid>
        {mediaSection.searchResults.map((book: BookItem) => (
          <Box
            key={`search-${book.id || book.title}`}
            sx={{ cursor: "pointer" }}
          >
            <BookCard
              book={book as BookWithSavedStatus}
              isSaved={!!book.isSaved}
              isInReadList={mediaSection.watchlistItems.some(
                (b: BookItem) => b.title === book.title && b.author === book.author
              )}
              view="default"
              onSave={() => mediaSection.handleSave(book)}
              onAddToReadList={() => mediaSection.handleAddToWatchlist(book)}
            />
          </Box>
        ))}
      </MediaGrid>
    ),
    [
      mediaSection.searchResults,
      mediaSection.watchlistItems,
      mediaSection.handleSave,
      mediaSection.handleAddToWatchlist,
    ],
  );

  // MediaItemWrapper with proper type annotation
  const MediaItemWrapperTyped = MediaItemWrapper as React.ComponentType<
    MediaItemWrapperProps<BookItem>
  >;

  const renderWatchlistItems = useCallback(() => {
    return (
      <MediaGrid>
        {mediaSection.watchlistItems.map((book) => (
          <MediaItemWrapperTyped
            key={`book-watchlist-${book.id}`}
            item={book}
            view="watchlist"
            onRemoveFromWatchlist={() => mediaSection.handleRemoveFromWatchlist(book)}
          >
            <BookCard
              book={book as BookWithSavedStatus}
              isSaved={!!book.isSaved}
              view="readlist"
              onSave={() => mediaSection.handleWatchlistToFavorites(book)}
              onRemoveFromReadList={undefined}
              onLike={() => mediaSection.handleWatchlistFeedback(book, "like")}
              onDislike={() => {
                mediaSection.handleWatchlistFeedback(book, "dislike");
                mediaSection.handleRemoveFromWatchlist(book);
              }}
            />
          </MediaItemWrapperTyped>
        ))}
      </MediaGrid>
    );
  }, [
    mediaSection.watchlistItems,
    mediaSection.handleWatchlistToFavorites,
    mediaSection.handleWatchlistFeedback,
    mediaSection.handleRemoveFromWatchlist,
  ]);

  const renderSavedItems = useCallback(
    () => (
      <MediaGrid>
        {mediaSection.savedItems.map((book: BookItem, index: number) => (
          <Box key={`saved-${book.id || index}`} sx={{ cursor: "pointer" }}>
            <BookCard
              book={{...book, isSaved: true} as BookWithSavedStatus}
              isSaved={true}
              isInReadList={mediaSection.watchlistItems.some(
                (b: BookItem) => b.title === book.title && b.author === book.author
              )}
              view="default"
              onSave={() => mediaSection.handleSave({...book, isSaved: true})}
              onAddToReadList={() => mediaSection.handleAddToWatchlist(book)}
            />
          </Box>
        ))}
      </MediaGrid>
    ),
    [
      mediaSection.savedItems,
      mediaSection.watchlistItems,
      mediaSection.handleSave,
      mediaSection.handleAddToWatchlist,
    ],
  );

  // Ensure the suggested item is properly enhanced when switching tabs
  useEffect(() => {
    if (mediaSection.suggestedItem) {
      // This ensures that when we come back to the book tab, the suggestion has full details
      saveEnhancedMedia(
        "book",
        mediaSection.suggestedItem,
        mediaSection.suggestionReason || "",
        {
          id: mediaSection.suggestedItem.id,
          title: mediaSection.suggestedItem.title,
          description: mediaSection.suggestedItem.description || "",
          artist: `by ${mediaSection.suggestedItem.author}`,
          imageUrl: mediaSection.suggestedItem.cover_path,
        },
        {
          author: mediaSection.suggestedItem.author,
          key: mediaSection.suggestedItem.key,
          cover_path: mediaSection.suggestedItem.cover_path,
          year: mediaSection.suggestedItem.year,
          subjects: mediaSection.suggestedItem.subjects,
          isSaved: mediaSection.suggestedItem.isSaved,
        }
      );
      console.log("Enhanced existing book suggestion on tab switch");
    }
  }, [mediaSection.suggestedItem]);

  return (
    <MediaSectionLayout
      type="book"
      typeName="Book"
      searchResultsRef={searchResultsRef}
      credentialsError={mediaSection.credentialsError}
      isLoadingSuggestion={mediaSection.isLoadingSuggestion}
      suggestionError={mediaSection.suggestionError}
      suggestionErrorDetails={mediaSection.suggestionErrorDetails}
      isProcessingFeedback={mediaSection.isProcessingFeedback}
      searchResults={mediaSection.searchResults}
      showSearchResults={mediaSection.showSearchResults}
      watchlistItems={mediaSection.watchlistItems}
      savedItems={mediaSection.savedItems}
      showWatchlist={mediaSection.showWatchlist}
      showLibrary={mediaSection.showLibrary}
      suggestedItem={mediaSection.suggestedItem}
      suggestionReason={mediaSection.suggestionReason}
      onRefreshCredentials={() => {}} // No credentials needed for books
      onRequestSuggestion={mediaSection.handleGetSuggestion}
      onLikeSuggestion={() => {
        mediaSection.handleFeedback(session.Outcome.liked);
        // Don't add to favorites, just mark as liked
      }}
      onDislikeSuggestion={() =>
        mediaSection.handleFeedback(session.Outcome.disliked)
      }
      onSkipSuggestion={() => {
        mediaSection.handleSkip();
      }}
      onAddToLibrary={mediaSection.handleAddToFavorites}
      onAddSuggestionToWatchlist={
        mediaSection.suggestedItem
          ? () => mediaSection.handleAddToWatchlist(mediaSection.suggestedItem!)
          : undefined
      }
      onToggleWatchlist={() =>
        mediaSection.setShowWatchlist(!mediaSection.showWatchlist)
      }
      onToggleLibrary={() =>
        mediaSection.setShowLibrary(!mediaSection.showLibrary)
      }
      renderSearchResults={renderSearchResults}
      renderWatchlistItems={renderWatchlistItems}
      renderSavedItems={renderSavedItems}
      renderSuggestionPoster={renderBookCover}
      mapToSuggestionItem={mapBookToSuggestionItem}
      queueName="Read List"
    />
  );
});
