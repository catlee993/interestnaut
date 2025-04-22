import { Box, TextField, IconButton, Paper } from "@mui/material";
import { TrackCard } from "@/components/music/tracks/TrackCard";
import { useTracks } from "@/components/music/hooks/useTracks";
import { usePlayer } from "@/components/music/player/PlayerContext";
import { FaTimes } from "react-icons/fa";
import { useState, useRef, useEffect, useCallback } from "react";

export function SearchSection() {
  const { searchResults, handleSearch, handleSave, handleRemove } = useTracks();
  const { handlePlay } = usePlayer();
  const [showResults, setShowResults] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const handleSearchRef = useRef(handleSearch);
  const lastSearchRef = useRef(""); // Track last search to prevent duplicates
  const debounceTime = 500; // 500ms debounce time

  // Update the ref when handleSearch changes
  useEffect(() => {
    handleSearchRef.current = handleSearch;
  }, [handleSearch]);

  const handleClearSearch = () => {
    setSearchQuery("");
    if (timerRef.current) {
      clearTimeout(timerRef.current);
    }
    lastSearchRef.current = "";
    handleSearchRef.current("");
    setShowResults(false);
  };

  // Debounce search query
  const debouncedSearch = useCallback((query: string) => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
    }

    // Don't search again if query hasn't changed
    if (query === lastSearchRef.current) {
      return;
    }

    if (query === "") {
      // Handle empty query immediately
      lastSearchRef.current = "";
      handleSearchRef.current("");
      setShowResults(false);
      return;
    }

    timerRef.current = setTimeout(() => {
      if (query !== lastSearchRef.current) {
        lastSearchRef.current = query;
        handleSearchRef.current(query);
        setShowResults(true);
      }
    }, debounceTime);
  }, [debounceTime]);

  // Cleanup timer on unmount
  useEffect(() => {
    return () => {
      if (timerRef.current) {
        clearTimeout(timerRef.current);
      }
    };
  }, []);

  // Add mouseout event listener to blur the input when moving away
  useEffect(() => {
    const handleMouseLeave = (event: MouseEvent) => {
      // Don't blur if moving to search results
      if (event.relatedTarget && 
         (event.relatedTarget as Element).closest('.search-results-container')) {
        return;
      }
      
      if (document.activeElement === inputRef.current) {
        inputRef.current?.blur();
      }
    };

    const container = containerRef.current;
    if (container) {
      container.addEventListener('mouseleave', handleMouseLeave);
    }
    
    return () => {
      if (container) {
        container.removeEventListener('mouseleave', handleMouseLeave);
      }
    };
  }, []);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      handleClearSearch();
    } else if (e.key === 'Enter') {
      // Immediately perform search without waiting for debounce
      if (timerRef.current) {
        clearTimeout(timerRef.current);
      }
      if (searchQuery !== lastSearchRef.current) {
        lastSearchRef.current = searchQuery;
        handleSearchRef.current(searchQuery);
        setShowResults(true);
      }
      // Blur the input
      inputRef.current?.blur();
    }
  };

  // Prevent search bar from regaining focus during scrolling
  useEffect(() => {
    const preventFocusOnScroll = (event: Event) => {
      if (document.activeElement !== inputRef.current) {
        // Don't do anything if input isn't focused
        return;
      }
      
      // Blur input if user is scrolling the results
      if (event.target &&
         (event.target as Element).closest('.search-results-container')) {
        inputRef.current?.blur();
      }
    };
    
    document.addEventListener('wheel', preventFocusOnScroll, { passive: true });
    
    return () => {
      document.removeEventListener('wheel', preventFocusOnScroll);
    };
  }, []);

  return (
    <Box sx={{ p: 2 }}>
      <Box sx={{ position: "relative", mb: 2 }} ref={containerRef}>
        <TextField
          fullWidth
          placeholder="Search tracks..."
          size="small"
          value={searchQuery}
          onChange={(e) => {
            const value = e.target.value;
            setSearchQuery(value);
            debouncedSearch(value);
          }}
          onKeyDown={handleKeyDown}
          inputRef={inputRef}
          sx={{
            "& .MuiOutlinedInput-root": {
              "& fieldset": {
                borderColor: "rgba(123, 104, 238, 0.5)",
              },
              "&:hover fieldset": {
                borderColor: "rgba(123, 104, 238, 0.7)",
              },
              "&.Mui-focused fieldset": {
                borderColor: "rgba(123, 104, 238, 0.9)",
              },
            },
            "& .MuiInputBase-input": {
              color: "white",
              fontSize: "0.875rem",
            },
            "& .MuiInputBase-input::placeholder": {
              color: "rgba(255, 255, 255, 0.75)",
            },
          }}
        />
        {(searchResults.length > 0 || searchQuery) && (
          <IconButton
            onClick={handleClearSearch}
            size="small"
            sx={{
              position: "absolute",
              right: 4,
              top: "50%",
              transform: "translateY(-50%)",
              color: "rgba(123, 104, 238, 0.7)",
              "&:hover": {
                color: "rgba(123, 104, 238, 1)",
                backgroundColor: "rgba(123, 104, 238, 0.1)",
              },
            }}
          >
            <FaTimes />
          </IconButton>
        )}
      </Box>
      {showResults && searchResults.length > 0 && (
        <Paper
          elevation={3}
          className="search-results-container"
          sx={{
            position: "absolute",
            left: 0,
            right: 0,
            zIndex: 1000,
            backgroundColor: "rgba(18, 18, 18, 0.95)",
            backdropFilter: "blur(10px)",
            maxHeight: "60vh",
            overflowY: "auto",
            "&::-webkit-scrollbar": {
              width: "8px",
            },
            "&::-webkit-scrollbar-track": {
              background: "rgba(255, 255, 255, 0.1)",
            },
            "&::-webkit-scrollbar-thumb": {
              background: "rgba(123, 104, 238, 0.5)",
              borderRadius: "4px",
              "&:hover": {
                background: "rgba(123, 104, 238, 0.7)",
              },
            },
          }}
        >
          <Box
            sx={{
              display: "grid",
              gridTemplateColumns: {
                xs: "1fr",
                sm: "repeat(2, 1fr)",
                md: "repeat(3, 1fr)",
              },
              gap: 2,
              p: 2,
            }}
          >
            {searchResults.map((track) => (
              <TrackCard
                key={track.id}
                track={track}
                isSaved={false}
                onPlay={handlePlay}
                onSave={handleSave}
                onRemove={handleRemove}
              />
            ))}
          </Box>
        </Paper>
      )}
    </Box>
  );
}
