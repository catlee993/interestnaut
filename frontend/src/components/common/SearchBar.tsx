import { Box, TextField, IconButton } from "@mui/material";
import { FaTimes } from "react-icons/fa";
import { useState, useEffect, useRef } from "react";

interface SearchBarProps {
  placeholder: string;
  onSearch: (query: string) => void;
  onClear?: () => void;
}

export function SearchBar({ placeholder, onSearch, onClear }: SearchBarProps) {
  const [searchQuery, setSearchQuery] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  const handleClearSearch = () => {
    setSearchQuery("");
    onSearch("");
    if (onClear) onClear();
    inputRef.current?.focus();
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      handleClearSearch();
    } else if (e.key === 'Enter') {
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

  return (
    <Box sx={{ position: "relative", mb: 2 }}>
      <TextField
        fullWidth
        placeholder={placeholder}
        size="small"
        value={searchQuery}
        onChange={(e) => {
          const value = e.target.value;
          setSearchQuery(value);
          onSearch(value);
          if (value === "" && onClear) {
            onClear();
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