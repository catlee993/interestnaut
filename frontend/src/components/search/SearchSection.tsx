import { useState } from "react";
import { spotify } from "../../../wailsjs/go/models";
import { TrackCard } from "../tracks/TrackCard";

interface SearchSectionProps {
  onSearch: (query: string) => Promise<void>;
  searchResults: spotify.SimpleTrack[];
  savedTracks: spotify.SavedTracks | null;
  isLoading: boolean;
  nowPlayingTrack: spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo | null;
  isPlaybackPaused: boolean;
  onPlay: (track: spotify.Track | spotify.SimpleTrack) => Promise<void>;
  onSave: (trackId: string) => Promise<void>;
  onRemove: (trackId: string) => Promise<void>;
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
    <div className="search-section">
      <div className="search-input-container">
        <span className="search-icon">🔍</span>
        <input
          type="text"
          placeholder="Search tracks..."
          value={searchQuery}
          onChange={(e) => handleSearchInput(e.target.value)}
          className="search-input"
        />
      </div>

      {searchQuery && (
        <div className="search-results">
          <h2>Search Results</h2>
          {searchResults.length === 0 ? (
            <div className="no-results">
              No tracks found for "{searchQuery}"
            </div>
          ) : (
            <div className="track-grid">
              {searchResults.map((track) => (
                <TrackCard
                  key={track.id}
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
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
} 