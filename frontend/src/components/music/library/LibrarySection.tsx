import React from "react";
import { Box, Typography, Paper, Stack, Button } from "@mui/material";
import { TrackCard } from "@/components/music/tracks/TrackCard";
import { spotify } from "../../../../wailsjs/go/models";
import { styled } from "@mui/material/styles";

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
          <Stack
            direction="row"
            spacing={2}
            justifyContent="center"
            alignItems="center"
            sx={{ mt: 3 }}
          >
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
          </Stack>
        </>
      )}
    </Box>
  );
};
