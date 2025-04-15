import React, { useEffect, useState } from "react";
import { Box, Typography, Paper, Stack, Button } from "@mui/material";
import { TrackCard } from "@/components/music/tracks/TrackCard";
import { spotify } from "@wailsjs/go/models";
import { styled } from "@mui/material/styles";
import { usePlayer } from "@/components/music/player/PlayerContext";
import { GetSavedTracks } from "@wailsjs/go/bindings/Music";
import { GetContinuousPlayback } from "@wailsjs/go/bindings/Settings";

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
  const {
    updateSavedTracks,
    setContinuousPlayback,
    isContinuousPlayback,
    setNextTrack,
    setNowPlayingTrack,
  } = usePlayer();
  const [isLoading, setIsLoading] = useState(false);
  const [hasMore, setHasMore] = useState(true);

  useEffect(() => {
    const loadSettings = async () => {
      try {
        console.log("[LibrarySection] Loading continuous playback setting");
        const enabled = await GetContinuousPlayback();
        console.log(
          `[LibrarySection] Continuous playback from settings: ${enabled}`,
        );

        // Don't force the setting, use the actual value
        setContinuousPlayback(enabled);
      } catch (error) {
        console.error(
          "[LibrarySection] Error loading continuous playback:",
          error,
        );
      }
    };
    loadSettings();
  }, [setContinuousPlayback]);

  // Add useEffect to call updateSavedTracks when savedTracks change
  useEffect(() => {
    if (savedTracks && savedTracks.items && savedTracks.items.length > 0) {
      console.log(`[LibrarySection] Updating player context with ${savedTracks.items.length} tracks on page ${currentPage}`);
      updateSavedTracks(savedTracks, currentPage);
    }
  }, [savedTracks, currentPage, updateSavedTracks]);

  // Log when the setting changes
  useEffect(() => {
    console.log(
      `[LibrarySection] Continuous playback changed to: ${isContinuousPlayback}`,
    );
  }, [isContinuousPlayback]);

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
