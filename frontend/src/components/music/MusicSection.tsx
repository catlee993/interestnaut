import React from 'react';
import { Box, Typography, Paper } from '@mui/material';
import { spotify } from '@wailsjs/go/models';
import { TrackCard } from '@/components/music/tracks/TrackCard';
import { LibrarySection } from '@/components/music/library/LibrarySection';
import { SuggestionDisplay } from '@/components/music/suggestions/SuggestionDisplay';

export interface MusicSectionProps {
  searchResults: spotify.Track[] | spotify.SimpleTrack[];
  savedTracks: spotify.SavedTracks | null;
  currentPage: number;
  totalTracks: number;
  itemsPerPage: number;
  nowPlayingTrack: spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo | null;
  isPlaybackPaused: boolean;
  onPlay: (track: spotify.Track | spotify.SimpleTrack) => Promise<void>;
  onSave: (track: spotify.SimpleTrack) => Promise<void>;
  onRemove: (track: spotify.SimpleTrack) => Promise<void>;
  onSearch: (query: string) => Promise<void>;
  onNextPage: () => void;
  onPrevPage: () => void;
}

const isTrackPlaying = (
  track: spotify.Track | spotify.SimpleTrack,
  nowPlayingTrack: spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo | null,
  isPlaybackPaused: boolean
): boolean => {
  if (!nowPlayingTrack || isPlaybackPaused) return false;
  return track.id === nowPlayingTrack.id;
};

export const MusicSection: React.FC<MusicSectionProps> = ({
  searchResults,
  savedTracks,
  currentPage,
  totalTracks,
  itemsPerPage,
  nowPlayingTrack,
  isPlaybackPaused,
  onPlay,
  onSave,
  onRemove,
  onSearch,
  onNextPage,
  onPrevPage,
}) => {
  return (
    <Box sx={{ width: "100%" }}>
      {/* Suggestion Section */}
      <Box sx={{ mb: 4 }}>
        <Typography variant="h5" sx={{ mb: 2 }}>
          Suggested for You
        </Typography>
        <SuggestionDisplay />
      </Box>

      {/* Search Results Section */}
      {searchResults && searchResults.length > 0 && (
        <Box sx={{ mb: 4 }}>
          <Typography variant="h5" sx={{ mb: 2 }}>
            Search Results
          </Typography>
          <Box sx={{ 
            display: 'grid', 
            gap: 3,
            gridTemplateColumns: {
              xs: '1fr',
              sm: 'repeat(2, 1fr)',
              md: 'repeat(3, 1fr)'
            }
          }}>
            {searchResults.map((track) => (
              <Box key={track.id}>
                <TrackCard
                  track={track}
                  isSaved={false}
                  isPlaying={isTrackPlaying(track, nowPlayingTrack, isPlaybackPaused)}
                  onPlay={onPlay}
                  onSave={onSave}
                  onRemove={onRemove}
                />
              </Box>
            ))}
          </Box>
        </Box>
      )}

      {/* Library Section */}
      <LibrarySection
        savedTracks={savedTracks}
        currentPage={currentPage}
        totalTracks={totalTracks}
        itemsPerPage={itemsPerPage}
        nowPlayingTrack={nowPlayingTrack}
        isPlaybackPaused={isPlaybackPaused}
        onPlay={onPlay}
        onSave={onSave}
        onRemove={onRemove}
        onNextPage={onNextPage}
        onPrevPage={onPrevPage}
      />
    </Box>
  );
}; 