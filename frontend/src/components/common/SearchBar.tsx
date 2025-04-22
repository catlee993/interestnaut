import { Box, TextField, IconButton } from "@mui/material";
import { FaTimes } from "react-icons/fa";
import { useState, useEffect, useRef, useCallback } from "react";

interface SearchBarProps {
  placeholder: string;
  onSearch: (query: string) => void;
  onClear?: () => void;
  debounceTime?: number;
}

export function SearchBar({ 
  placeholder, 
  onSearch, 
  onClear,
  debounceTime = 500 
}: SearchBarProps) {
  const [searchQuery, setSearchQuery] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const onSearchRef = useRef(onSearch);
  const lastSearchRef = useRef(""); // Track last search to prevent duplicates

  // Update the ref when onSearch changes
  useEffect(() => {
    onSearchRef.current = onSearch;
  }, [onSearch]);

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
      onSearchRef.current("");
      if (onClear) onClear();
      return;
    }

    timerRef.current = setTimeout(() => {
      if (query !== lastSearchRef.current) {
        lastSearchRef.current = query;
        onSearchRef.current(query);
      }
    }, debounceTime);
  }, [debounceTime, onClear]);

  // Cleanup timer on unmount
  useEffect(() => {
    return () => {
      if (timerRef.current) {
        clearTimeout(timerRef.current);
      }
    };
  }, []);

  const handleClearSearch = () => {
    setSearchQuery("");
    if (timerRef.current) {
      clearTimeout(timerRef.current);
    }
    lastSearchRef.current = "";
    onSearchRef.current("");
    if (onClear) onClear();
    inputRef.current?.focus();
  };

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
        onSearchRef.current(searchQuery);
      }
      // Blur the input when Enter is pressed
      inputRef.current?.blur();
    }
  };

  // Add click outside event listener to blur the input
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      // Prevent triggering blur when user is trying to scroll results
      if (event.target && 
         (event.target as Element).closest('.search-results-container')) {
        return;
      }
      
      if (inputRef.current && !inputRef.current.contains(event.target as Node)) {
        inputRef.current.blur();
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  // Modify the mouseout behavior to not blur on scroll attempts
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
    <Box sx={{ position: "relative" }} ref={containerRef}>
      <TextField
        fullWidth
        placeholder={placeholder}
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
      {searchQuery && (
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
  );
} 