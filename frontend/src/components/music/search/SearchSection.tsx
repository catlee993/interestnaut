import { useState } from "react";
import { spotify } from "../../../../wailsjs/go/models";
import { TrackCard } from "../tracks/TrackCard";
import { Box, TextField, Typography, Paper } from "@mui/material";
import SearchIcon from "@mui/icons-material/Search";

interface SearchSectionProps {
  onSearch: (query: string) => Promise<void>;
  searchResults: spotify.SimpleTrack[];
  savedTracks: spotify.SavedTracks | null;
  isLoading: boolean;
  nowPlayingTrack:
    | spotify.Track
    | spotify.SimpleTrack
    | spotify.SuggestedTrackInfo
    | null;
  isPlaybackPaused: boolean;
  onPlay: (track: spotify.Track | spotify.SimpleTrack) => Promise<void>;
  onSave: (track: spotify.SimpleTrack) => Promise<void>;
  onRemove: (track: spotify.SimpleTrack) => Promise<void>;
}

export function SearchSection({
  onSearch,
  searchResults,
  savedTracks,
  isLoading,
  nowPlayingTrack,
  isPlaybackPaused,
  onPlay,
  onSave,
  onRemove,
}: SearchSectionProps) {
  const [searchQuery, setSearchQuery] = useState("");

  const handleSearchInput = (query: string) => {
    setSearchQuery(query);
    onSearch(query);
  };

  return (
    <Box sx={{ width: "100%" }}>
      <Box sx={{ position: "relative", mb: 3 }}>
        <SearchIcon sx={{ position: "absolute", left: 12, top: 12 }} />
        <TextField
          fullWidth
          placeholder="Search tracks..."
          value={searchQuery}
          onChange={(e) => handleSearchInput(e.target.value)}
          sx={{
            "& .MuiOutlinedInput-root": {
              pl: 3,
              "& fieldset": {
                borderRadius: 2,
              },
            },
          }}
        />
      </Box>

      {searchQuery && (
        <Paper sx={{ p: 3, mb: 3 }}>
          <Typography variant="h6" sx={{ mb: 2 }}>
            Search Results
          </Typography>
          {searchResults.length === 0 ? (
            <Typography color="text.secondary">
              No tracks found for "{searchQuery}"
            </Typography>
          ) : (
            <Box
              sx={{
                display: "grid",
                gridTemplateColumns: {
                  xs: "1fr",
                  sm: "1fr 1fr",
                  md: "1fr 1fr 1fr",
                  lg: "repeat(4, 1fr)",
                },
                gap: 2,
              }}
            >
              {searchResults.map((track) => (
                <Box key={track.id}>
                  <TrackCard
                    track={track}
                    isSaved={savedTracks?.items?.some(
                      (item) => item.track?.id === track.id,
                    )}
                    isPlaying={
                      !isPlaybackPaused && nowPlayingTrack?.id === track.id
                    }
                    onPlay={onPlay}
                    onSave={onSave}
                    onRemove={onRemove}
                  />
                </Box>
              ))}
            </Box>
          )}
        </Paper>
      )}
    </Box>
  );
}
