import { FaPause, FaPlay } from "react-icons/fa";
import { spotify } from "../../../../wailsjs/go/models";
import { Box, Card, Typography, IconButton, Button } from "@mui/material";
import { styled } from "@mui/material/styles";

interface TrackCardProps {
  track: spotify.Track | spotify.SimpleTrack;
  isSaved?: boolean;
  isPlaying?: boolean;
  onPlay: (track: spotify.Track | spotify.SimpleTrack) => Promise<void>;
  onSave?: (track: spotify.SimpleTrack) => Promise<void>;
  onRemove?: (track: spotify.SimpleTrack) => Promise<void>;
}

const StyledCard = styled(Card, {
  shouldForwardProp: (prop) => prop !== "isPlaying",
})<{ isPlaying?: boolean }>(({ theme, isPlaying }) => ({
  height: "100%",
  position: "relative",
  overflow: "hidden",
  backgroundColor: theme.palette.grey[800],
  transition: "all 0.2s ease-in-out",
  aspectRatio: "1",
  border: `2px solid ${theme.palette.grey[900]}`,
  "&:hover": {
    transform: "translateY(-4px)",
    "&::before": {
      backgroundColor: theme.palette.primary.main,
    },
  },
  "&::before": {
    content: '""',
    position: "absolute",
    top: 0,
    left: 0,
    right: 0,
    height: "4px",
    backgroundColor: isPlaying ? theme.palette.primary.main : "transparent",
    transition: "background-color 0.2s ease-in-out",
    zIndex: 2,
  },
}));

const PlayButton = styled(IconButton)(({ theme }) => ({
  backgroundColor: theme.palette.primary.main,
  color: theme.palette.primary.contrastText,
  width: "42px",
  height: "42px",
  "& svg": {
    width: "20px",
    height: "20px",
  },
  "&:hover": {
    backgroundColor: theme.palette.primary.dark,
    transform: "scale(1.1)",
  },
  "&.Mui-disabled": {
    backgroundColor: theme.palette.action.disabledBackground,
  },
  transition: "all 0.2s ease-in-out",
}));

const Overlay = styled(Box)(({ theme }) => ({
  position: "absolute",
  bottom: 0,
  left: 0,
  right: 0,
  background:
    "linear-gradient(to top, rgba(0,0,0,0.95) 0%, rgba(0,0,0,0.7) 40%, transparent 100%)",
  padding: theme.spacing(2),
  color: theme.palette.common.white,
}));

const Controls = styled(Box)(({ theme }) => ({
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
}));

export function TrackCard({
  track,
  isSaved = false,
  isPlaying = false,
  onPlay,
  onSave,
  onRemove,
}: TrackCardProps) {
  const info = getTrackInfo(track);
  const hasUri = "uri" in track && track.uri;
  const canPlay = hasUri || info.previewUrl;

  return (
    <StyledCard isPlaying={isPlaying}>
      <Box
        sx={{
          position: "relative",
          width: "100%",
          height: "100%",
          backgroundColor: "background.paper",
          backgroundImage: `url(${info.albumArtUrl})`,
          backgroundSize: "cover",
          backgroundPosition: "center",
        }}
      />
      <Overlay>
        <Controls>
          <PlayButton
            onClick={() => onPlay(track)}
            disabled={!canPlay}
            title={
              !canPlay
                ? "Playback unavailable"
                : hasUri
                  ? "Play full song"
                  : "Play preview"
            }
          >
            {isPlaying ? <FaPause /> : <FaPlay />}
          </PlayButton>
          <Box sx={{ flex: 1, mx: 2, overflow: "hidden" }}>
            <Typography
              variant="subtitle1"
              noWrap
              sx={{ color: "common.white", fontWeight: 500 }}
            >
              {info.name}
            </Typography>
            <Typography
              variant="body2"
              noWrap
              sx={{ color: "common.white", opacity: 0.8 }}
            >
              {info.artist}
            </Typography>
            {!canPlay && (
              <Typography
                variant="caption"
                color="error"
                sx={{ display: "block" }}
              >
                Playback unavailable
              </Typography>
            )}
          </Box>
          {isSaved ? (
            <Button
              variant="text"
              color="error"
              size="small"
              onClick={() => onRemove?.(track as spotify.SimpleTrack)}
              sx={{
                color: "error.light",
                minWidth: "auto",
                px: 1,
                "&:hover": {
                  backgroundColor: "rgba(244, 67, 54, 0.08)",
                },
              }}
            >
              Remove
            </Button>
          ) : (
            <Button
              variant="text"
              size="small"
              onClick={() => onSave?.(track as spotify.SimpleTrack)}
              sx={{
                color: "common.white",
                minWidth: "auto",
                px: 1,
                "&:hover": {
                  backgroundColor: "rgba(255, 255, 255, 0.08)",
                },
              }}
            >
              Save
            </Button>
          )}
        </Controls>
      </Overlay>
    </StyledCard>
  );
}

function getTrackInfo(track: spotify.Track | spotify.SimpleTrack) {
  if (!track) {
    return {
      name: "Unknown Track",
      artist: "Unknown Artist",
      album: "",
      albumArtUrl: "",
      previewUrl: null,
    };
  }

  // Handle full Track type
  if (
    "artists" in track &&
    Array.isArray(track.artists) &&
    "album" in track &&
    track.album &&
    "images" in track.album
  ) {
    return {
      name: track.name,
      artist: track.artists[0]?.name || "Unknown Artist",
      album: track.album.name,
      albumArtUrl: track.album.images[0]?.url || "",
      previewUrl: track.preview_url || null,
    };
  }

  // Handle SimpleTrack type
  if ("artist" in track && "albumArtUrl" in track) {
    return {
      name: track.name,
      artist: track.artist,
      album: track.album || "",
      albumArtUrl: track.albumArtUrl || "",
      previewUrl: track.previewUrl || null,
    };
  }

  // Fallback for unknown types
  console.warn("Unknown track type:", track);
  return {
    name: track.name || "Unknown Track",
    artist: "Unknown Artist",
    album: "",
    albumArtUrl: "",
    previewUrl: null,
  };
}
