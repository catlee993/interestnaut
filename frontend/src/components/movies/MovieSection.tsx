import { useState } from "react";
import { Box, TextField, Grid } from "@mui/material";
import { MovieCard } from "@/components/movies/MovieCard";
import { SearchMovies } from "@wailsjs/go/bindings/Movies";
import { MovieWithSavedStatus } from "@wailsjs/go/models";

export function MovieSection() {
  const [searchResults, setSearchResults] = useState<MovieWithSavedStatus[]>(
    [],
  );
  const [savedMovies, setSavedMovies] = useState<Set<number>>(new Set());

  const handleSearch = async (query: string) => {
    if (!query.trim()) {
      setSearchResults([]);
      return;
    }

    try {
      const response = await SearchMovies(query);
      setSearchResults(response);
    } catch (error) {
      console.error("Failed to search movies:", error);
    }
  };

  const handleSave = (movieId: number) => {
    setSavedMovies((prev) => {
      const next = new Set(prev);
      if (next.has(movieId)) {
        next.delete(movieId);
      } else {
        next.add(movieId);
      }
      return next;
    });
  };

  return (
    <Box sx={{ p: 3 }}>
      <Box
        sx={{
          display: "grid",
          gridTemplateColumns: {
            xs: "1fr",
            sm: "repeat(2, 1fr)",
            md: "repeat(3, 1fr)",
          },
          gap: 3,
        }}
      >
        {searchResults.map((movie) => (
          <MovieCard
            key={movie.id}
            movie={movie}
            isSaved={savedMovies.has(movie.id)}
            onSave={handleSave}
          />
        ))}
      </Box>
    </Box>
  );
}
