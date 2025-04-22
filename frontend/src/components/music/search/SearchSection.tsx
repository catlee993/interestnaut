import { Box, TextField, IconButton, Paper } from "@mui/material";
import { TrackCard } from "@/components/music/tracks/TrackCard";
import { useTracks } from "@/components/music/hooks/useTracks";
import { usePlayer } from "@/components/music/player/PlayerContext";
import { FaTimes } from "react-icons/fa";
import { useState, useRef, useEffect } from "react";

export function SearchSection() {
  const { searchResults, handleSearch, handleSave, handleRemove } = useTracks();
  const { handlePlay } = usePlayer();
  const [showResults, setShowResults] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [debouncedQuery, setDebouncedQuery] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const debounceTime = 500; // 500ms debounce time

  const handleClearSearch = () => {
    setSearchQuery("");
    setDebouncedQuery("");
    handleSearch("");
    setShowResults(false);
  };

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
  }, [searchQuery]);

  // Trigger search when debounced query changes
  useEffect(() => {
    if (debouncedQuery !== "") {
      handleSearch(debouncedQuery);
      setShowResults(true);
    }
  }, [debouncedQuery, handleSearch]);

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

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      handleClearSearch();
    } else if (e.key === 'Enter') {
      // Immediately perform search without waiting for debounce
      handleSearch(searchQuery);
      // Blur the input
      inputRef.current?.blur();
    }
  };

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
            if (value === "") {
              // Clear search immediately when field is emptied
              setDebouncedQuery("");
              handleSearch("");
              setShowResults(false);
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
