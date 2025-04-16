import React, { useState, useRef, useEffect, forwardRef, useImperativeHandle } from "react";
import { Box, Typography } from "@mui/material";
import { spotify } from "@wailsjs/go/models";
import { TrackCard } from "@/components/music/tracks/TrackCard";
import { LibrarySection } from "@/components/music/library/LibrarySection";
import { SuggestionDisplay } from "@/components/music/suggestions/SuggestionDisplay";

export interface MusicSectionProps {
  searchResults: spotify.Track[] | spotify.SimpleTrack[];
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
  onSearch: (query: string) => Promise<void>;
  onNextPage: () => void;
  onPrevPage: () => void;
}

export interface MusicSectionHandle {
  handleClearSearch: () => void;
}

const isTrackPlaying = (
  track: spotify.Track | spotify.SimpleTrack,
  nowPlayingTrack:
    | spotify.Track
    | spotify.SimpleTrack
    | spotify.SuggestedTrackInfo
    | null,
  isPlaybackPaused: boolean,
): boolean => {
  if (!nowPlayingTrack || isPlaybackPaused) return false;
  return track.id === nowPlayingTrack.id;
};

export const MusicSection = forwardRef<MusicSectionHandle, MusicSectionProps>((
  {
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
  },
  ref
) => {
  // State to track if search results should be visible
  const [showSearchResults, setShowSearchResults] = useState(true);
  const searchResultsRef = useRef<HTMLDivElement>(null);
  
  // Expose methods to parent component
  useImperativeHandle(ref, () => ({
    handleClearSearch: () => {
      setShowSearchResults(false);
    }
  }));
  
  // Effect to add click outside listener
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (
        searchResultsRef.current && 
        !searchResultsRef.current.contains(event.target as Node)
      ) {
        setShowSearchResults(false);
      }
    };
    
    // Add event listener
    document.addEventListener('mousedown', handleClickOutside);
    
    // Clean up
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
    };
  }, []);
  
  // Update showSearchResults when search results change
  useEffect(() => {
    if (searchResults && searchResults.length > 0) {
      setShowSearchResults(true);
    } else {
      setShowSearchResults(false);
    }
  }, [searchResults]);
  
  return (
    <Box sx={{ width: "100%" }}>
      {/* Search Results Section - Only show if there are results and showSearchResults is true */}
      {searchResults && searchResults.length > 0 && showSearchResults && (
        <Box 
          sx={{ mb: 4 }}
          ref={searchResultsRef}
        >
          <Typography variant="h5" sx={{ mb: 2 }}>
            Search Results
          </Typography>
          <Box
            sx={{
              display: "grid",
              gap: 3,
              gridTemplateColumns: {
                xs: "1fr",
                sm: "repeat(2, 1fr)",
                md: "repeat(3, 1fr)",
              },
            }}
          >
            {searchResults.map((track) => (
              <Box key={track.id}>
                <TrackCard
                  track={track}
                  isSaved={false}
                  isPlaying={isTrackPlaying(
                    track,
                    nowPlayingTrack,
                    isPlaybackPaused,
                  )}
                  onPlay={onPlay}
                  onSave={onSave}
                  onRemove={onRemove}
                />
              </Box>
            ))}
          </Box>
        </Box>
      )}

      {/* Suggestion Section - Now in the middle */}
      <Box sx={{ mb: 4 }}>
        <Typography variant="h5" sx={{ mb: 2 }}>
          Suggested for You
        </Typography>
        <SuggestionDisplay />
      </Box>

      {/* Library Section - Remains at the bottom */}
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
});
