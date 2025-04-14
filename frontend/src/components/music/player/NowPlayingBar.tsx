import { FaPause, FaPlay } from "react-icons/fa";
import { spotify } from "../../../../wailsjs/go/models";
import { styled } from "@mui/material/styles";
import { IconButton, Slider, Box, Typography } from "@mui/material";
import { usePlayer } from "./PlayerContext";

interface NowPlayingBarProps {
  track: spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo;
  isPlaybackPaused: boolean;
  onPlayPause: () => void;
}

const PlayPauseButton = styled(IconButton)(({ theme }) => ({
  backgroundColor: 'transparent',
  color: theme.palette.primary.main,
  padding: theme.spacing(1),
  '&:hover': {
    backgroundColor: 'rgba(255, 255, 255, 0.1)',
  },
  '&.playing': {
    color: theme.palette.primary.main,
  },
  transition: 'all 0.2s ease',
}));

const Scrubber = styled(Slider)(({ theme }) => ({
  color: theme.palette.primary.main,
  height: 4,
  padding: '3px 0',
  '& .MuiSlider-thumb': {
    width: 8,
    height: 8,
    transition: '0.3s cubic-bezier(.47,1.64,.41,.8)',
    '&:before': {
      boxShadow: '0 2px 12px 0 rgba(0,0,0,0.4)',
    },
    '&:hover, &.Mui-focusVisible': {
      boxShadow: `0px 0px 0px 8px ${theme.palette.primary.main}22`,
    },
    '&.Mui-active': {
      width: 12,
      height: 12,
    },
  },
  '& .MuiSlider-rail': {
    opacity: 0.3,
  },
  margin: '3px 0',
}));

const NowPlayingContainer = styled('div')(({ theme }) => ({
  display: 'flex',
  alignItems: 'center',
  gap: theme.spacing(2),
  padding: theme.spacing(1),
  backgroundColor: theme.palette.background.paper,
  borderRadius: theme.shape.borderRadius,
  width: '100%',
  position: 'fixed',
  bottom: 0,
  left: 0,
  right: 0,
  zIndex: 1000,
  borderTop: `1px solid ${theme.palette.divider}`,
}));

const TrackInfo = styled('div')(({ theme }) => ({
  display: 'flex',
  flexDirection: 'column',
  gap: theme.spacing(0.5),
  minWidth: '200px',
  '& p': {
    margin: 0,
    fontSize: '0.875rem',
  },
  '& strong': {
    color: theme.palette.text.primary,
  },
}));

const ScrubberContainer = styled(Box)(({ theme }) => ({
  flex: 1,
  minWidth: 0,
  padding: `0 ${theme.spacing(2)}`,
  display: 'flex',
  flexDirection: 'column',
  gap: '3px',
}));

export function NowPlayingBar(): JSX.Element | null {
  const {
    nowPlayingTrack,
    isPlaybackPaused,
    currentPosition,
    duration,
    handlePlayPause,
    seekTo,
  } = usePlayer();

  if (!nowPlayingTrack) {
    return null;
  }

  const info = getTrackInfo(nowPlayingTrack);
  // A track is playable if it has either a preview URL or a Spotify URI
  const hasPlayback = info.previewUrl || ("uri" in nowPlayingTrack && nowPlayingTrack.uri);

  const formatTime = (ms: number) => {
    const seconds = Math.floor(ms / 1000);
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = seconds % 60;
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`;
  };

  const handleSeek = (_event: Event, newValue: number | number[]) => {
    seekTo(newValue as number);
  };

  return (
    <NowPlayingContainer>
      <img 
        src={info.albumArtUrl} 
        alt={info.name} 
        style={{ 
          width: '48px', 
          height: '48px', 
          borderRadius: '4px',
          objectFit: 'cover'
        }} 
      />
      <TrackInfo>
        <Typography variant="subtitle2" color="text.primary">
          <strong>{info.name}</strong>
        </Typography>
        <Typography variant="subtitle2" color="text.secondary">
          {info.artist} - {info.album}
        </Typography>
      </TrackInfo>
      <ScrubberContainer>
        <Scrubber
          value={currentPosition}
          max={duration}
          onChange={handleSeek}
          disabled={!hasPlayback}
          valueLabelDisplay="auto"
          valueLabelFormat={formatTime}
          step={1000}
          marks={false}
        />
        <Box sx={{ 
          display: 'flex', 
          justifyContent: 'space-between', 
          mt: 0,
          mb: 0.35,
          fontSize: '0.72rem',
          color: 'rgba(255,255,255,0.7)',
          lineHeight: 1.1
        }}>
          <span>{formatTime(currentPosition)}</span>
          <span>{formatTime(duration)}</span>
        </Box>
      </ScrubberContainer>
      <PlayPauseButton
        onClick={handlePlayPause}
        className={!isPlaybackPaused ? "playing" : ""}
        sx={{
          '&:not(:disabled):hover': {
            backgroundColor: 'rgba(255, 255, 255, 0.1)',
          }
        }}
      >
        {isPlaybackPaused ? <FaPlay /> : <FaPause />}
      </PlayPauseButton>
    </NowPlayingContainer>
  );
}

function getTrackInfo(
  track: spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo,
) {
  if (!track) {
    return {
      name: "Unknown Track",
      artist: "Unknown Artist",
      album: "",
      albumArtUrl: "",
      previewUrl: null,
      uri: null,
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
      uri: track.uri || null,
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
      uri: track.uri || null,
    };
  }

  // Handle SuggestedTrackInfo type
  if ("artist" in track) {
    return {
      name: track.name,
      artist: track.artist,
      album: "",
      albumArtUrl: "albumArtUrl" in track ? track.albumArtUrl || "" : "",
      previewUrl: "previewUrl" in track ? track.previewUrl || null : null,
      uri: "uri" in track ? track.uri || null : null,
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
    uri: null,
  };
}
