import { Box, TextField, IconButton } from "@mui/material";
import { FaTimes } from "react-icons/fa";
import { useState, useEffect, useRef } from "react";

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
  const [debouncedQuery, setDebouncedQuery] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Debounce search query
  useEffect(() => {
    // Clear any existing timer
    if (timerRef.current) {
      clearTimeout(timerRef.current);
    }

    // Set a new timer
    timerRef.current = setTimeout(() => {
      setDebouncedQuery(searchQuery);
    }, debounceTime);

    // Cleanup function
    return () => {
      if (timerRef.current) {
        clearTimeout(timerRef.current);
      }
    };
  }, [searchQuery, debounceTime]);

  // Trigger search when debounced query changes
  useEffect(() => {
    if (debouncedQuery !== "") {
      onSearch(debouncedQuery);
    }
  }, [debouncedQuery, onSearch]);

  const handleClearSearch = () => {
    setSearchQuery("");
    setDebouncedQuery("");
    onSearch("");
    if (onClear) onClear();
    inputRef.current?.focus();
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      handleClearSearch();
    } else if (e.key === 'Enter') {
      // Immediately perform search without waiting for debounce
      onSearch(searchQuery);
      // Blur the input when Enter is pressed
      inputRef.current?.blur();
    }
  };

  // Add click outside event listener to blur the input
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (inputRef.current && !inputRef.current.contains(event.target as Node)) {
        inputRef.current.blur();
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);

  // Add mouseout event listener to blur the input when moving away
  useEffect(() => {
    const handleMouseLeave = () => {
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
          if (value === "") {
            // Clear search immediately when field is emptied
            setDebouncedQuery("");
            onSearch("");
            if (onClear) onClear();
          }
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