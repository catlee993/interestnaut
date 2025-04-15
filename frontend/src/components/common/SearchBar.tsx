import { Box, TextField, IconButton } from "@mui/material";
import { FaTimes } from "react-icons/fa";
import { useState } from "react";

interface SearchBarProps {
  placeholder: string;
  onSearch: (query: string) => void;
}

export function SearchBar({ placeholder, onSearch }: SearchBarProps) {
  const [searchQuery, setSearchQuery] = useState("");

  const handleClearSearch = () => {
    setSearchQuery("");
    onSearch("");
  };

  return (
    <Box sx={{ position: "relative", mb: 2 }}>
      <TextField
        fullWidth
        placeholder={placeholder}
        size="small"
        value={searchQuery}
        onChange={(e) => {
          setSearchQuery(e.target.value);
          onSearch(e.target.value);
        }}
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