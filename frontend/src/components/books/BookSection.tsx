import React, {
  useRef,
  forwardRef,
  useImperativeHandle,
  useCallback,
} from "react";
import { Box, Card, CardMedia } from "@mui/material";
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

    getItemDetails: async (id: number) => {
      try {
        // Instead of passing an empty string, pass a meaningful key
        // We'll use the title and author from the book item to retrieve details
        // First, get the cached item to extract title/author
        const cachedItem = localStorage.getItem("cached_book_suggestion");
        if (!cachedItem) {
          throw new Error("No cached book found");
        }
        
        const parsedItem = JSON.parse(cachedItem) as BookItem;
        
        // Use the key if available, otherwise, the dummy key we generated
        const bookKey = parsedItem.key || `${parsedItem.title}-${parsedItem.author}`;
        
        // Get details using the key - this will validate the book still exists in the API
        const details = await GetBookDetails(bookKey);
        
        // If we get here, the book details were successfully retrieved
        return {
          ...details,
          id: generateId(details),
          key: details.key || bookKey,
          cover_path: details.cover_path || "",
        } as BookItem;
      } catch (error) {
        // If there's an error, it means the book can't be validated
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
      return {
        id: book.id,
        title: book.title,
        description: book.description || "",
        artist: `by ${book.author}`,
        imageUrl: book.cover_path || undefined,
      };
    },
    [],
  );

  // Custom renderer for book cover
  const renderBookCover = useCallback(
    (item: MediaSuggestionItem) => {
      if (!item.imageUrl) return null;

      return (
        <Card sx={{ height: "100%" }}>
          <CardMedia
            component="img"
            image={item.imageUrl}
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
        {mediaSection.searchResults.map((book) => (
          <Box
            key={`search-${book.id || book.title}`}
            sx={{ cursor: "pointer" }}
          >
            <BookCard
              book={book as BookWithSavedStatus}
              isSaved={!!book.isSaved}
              isInReadList={mediaSection.watchlistItems.some(
                (b) => b.title === book.title && b.author === book.author
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

  const renderWatchlistItems = useCallback(
    () => (
      <MediaGrid>
        {mediaSection.watchlistItems.map((book) => (
          <MediaItemWrapper
            key={`readlist-${book.id || book.title}`}
            item={book}
            view="watchlist"
            onRemoveFromWatchlist={() =>
              mediaSection.handleRemoveFromWatchlist(book)
            }
          >
            <BookCard
              book={book as BookWithSavedStatus}
              isSaved={!!book.isSaved}
              view="readlist"
              onSave={() => mediaSection.handleWatchlistToFavorites(book)}
              onRemoveFromReadList={undefined}
              onLike={() =>
                mediaSection.handleWatchlistFeedback(book, "like")
              }
              onDislike={() => {
                mediaSection.handleWatchlistFeedback(book, "dislike");
                mediaSection.handleRemoveFromWatchlist(book);
              }}
            />
          </MediaItemWrapper>
        ))}
      </MediaGrid>
    ),
    [
      mediaSection.watchlistItems,
      mediaSection.handleWatchlistToFavorites,
      mediaSection.handleWatchlistFeedback,
      mediaSection.handleRemoveFromWatchlist,
    ],
  );

  const renderSavedItems = useCallback(
    () => (
      <MediaGrid>
        {mediaSection.savedItems.map((book, index) => (
          <Box key={`saved-${book.id || index}`} sx={{ cursor: "pointer" }}>
            <BookCard
              book={{...book, isSaved: true} as BookWithSavedStatus}
              isSaved={true}
              isInReadList={mediaSection.watchlistItems.some(
                (b) => b.title === book.title && b.author === book.author
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

  return (
    <MediaSectionLayout
      type="book"
      typeName="Book"
      searchResultsRef={searchResultsRef}
      credentialsError={mediaSection.credentialsError}
      isLoadingSuggestion={mediaSection.isLoadingSuggestion}
      suggestionError={mediaSection.suggestionError}
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
        // Update the library state directly
        if (mediaSection.suggestedItem) {
          const updatedBook = {
            ...mediaSection.suggestedItem,
            isSaved: true,
          };
          // Add to savedItems if not already there
          if (!mediaSection.savedItems.some((b) => b.id === updatedBook.id)) {
            mediaSection.setSavedItems([
              ...mediaSection.savedItems,
              updatedBook,
            ]);
          }
        }
      }}
      onDislikeSuggestion={() =>
        mediaSection.handleFeedback(session.Outcome.disliked)
      }
      onSkipSuggestion={() => {
        if (mediaSection.suggestedItem && mediaSection.suggestedItem.isSaved) {
          // Get a new suggestion
          mediaSection.handleGetSuggestion();
        } else {
          mediaSection.handleFeedback(session.Outcome.skipped);
        }
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
