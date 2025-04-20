import React, { useEffect, useState } from "react";
import { Box, Typography, Button } from "@mui/material";
import { TrackCard } from "@/components/music/tracks/TrackCard";
import { spotify } from "@wailsjs/go/models";
import { styled } from "@mui/material/styles";
import { usePlayer } from "@/components/music/player/PlayerContext";

interface LibrarySectionProps {
  savedTracks: spotify.SavedTracks | null;
  currentPage: number;
  totalTracks: number;
  itemsPerPage: number;
  nowPlayingTrack:
    | spotify.Track
    | spotify.SimpleTrack
    | spotify.SuggestedTrackInfo
    | null;
  isPlaybackPaused: boolean;
  onPlay: (track: spotify.Track | spotify.SimpleTrack) => Promise<void>;
  onSave: (track: spotify.SimpleTrack) => Promise<void>;
  onRemove: (track: spotify.SimpleTrack) => Promise<void>;
  onNextPage: () => void;
  onPrevPage: () => void;
}

const Grid = styled(Box)(({ theme }) => ({
  display: "grid",
  gap: theme.spacing(3),
  gridTemplateColumns: "1fr",
  [theme.breakpoints.up("sm")]: {
    gridTemplateColumns: "repeat(2, 1fr)",
  },
  [theme.breakpoints.up("md")]: {
    gridTemplateColumns: "repeat(2, 1fr)",
  },
  [theme.breakpoints.up("lg")]: {
    gridTemplateColumns: "repeat(3, 1fr)",
  },
  paddingTop: theme.spacing(3),
  paddingBottom: theme.spacing(3),
  width: "100%",
}));

const PaginationControls = styled(Box)(({ theme }) => ({
  display: "flex",
  justifyContent: "center",
  alignItems: "center",
  gap: theme.spacing(2),
  marginTop: theme.spacing(2),
  "& button": {
    color: "#A855F7",
    borderColor: "#A855F7",
    "&:hover": {
      backgroundColor: "rgba(168, 85, 247, 0.1)",
      borderColor: "#A855F7",
    },
    "&.Mui-disabled": {
      color: "rgba(168, 85, 247, 0.3)",
      borderColor: "rgba(168, 85, 247, 0.3)",
    },
  },
}));

export const LibrarySection: React.FC<LibrarySectionProps> = ({
  savedTracks,
  currentPage,
  totalTracks,
  itemsPerPage,
  nowPlayingTrack,
  isPlaybackPaused,
  onPlay,
  onSave,
  onRemove,
  onNextPage,
  onPrevPage,
}) => {
  const { updateSavedTracks } = usePlayer();

  // Add useEffect to call updateSavedTracks when savedTracks change
  useEffect(() => {
    if (savedTracks && savedTracks.items && savedTracks.items.length > 0) {
      updateSavedTracks(savedTracks, currentPage);
    }
  }, [savedTracks, currentPage, updateSavedTracks]);

  return (
    <Box sx={{ py: 3, backgroundColor: "transparent" }}>
      <Typography variant="h6" sx={{ mb: 2, color: "text.primary" }}>
        Your Library
      </Typography>
      {!savedTracks?.items || savedTracks.items.length === 0 ? (
        <Typography color="text.secondary" sx={{ textAlign: "center", py: 4 }}>
          No saved tracks yet. Search for tracks to add them to your library.
        </Typography>
      ) : (
        <>
          <Grid>
            {savedTracks.items.map(
              (item: spotify.SavedTrackItem) =>
                item.track && (
                  <Box key={item.track.id}>
                    <TrackCard
                      track={item.track}
                      isSaved={true}
                      isPlaying={
                        !isPlaybackPaused &&
                        nowPlayingTrack?.id === item.track.id
                      }
                      onPlay={onPlay}
                      onSave={onSave}
                      onRemove={onRemove}
                    />
                  </Box>
                ),
            )}
          </Grid>
          <PaginationControls>
            <Button
              variant="outlined"
              onClick={onPrevPage}
              disabled={currentPage === 1}
            >
              Previous
            </Button>
            <Typography>
              Page {currentPage} of {Math.ceil(totalTracks / itemsPerPage)}
            </Typography>
            <Button
              variant="outlined"
              onClick={onNextPage}
              disabled={currentPage * itemsPerPage >= totalTracks}
            >
              Next
            </Button>
          </PaginationControls>
        </>
      )}
    </Box>
  );
};
