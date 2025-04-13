import { useState } from "react";
import { spotify } from "../../../wailsjs/go/models";
import { TrackCard } from "../tracks/TrackCard";

interface LibrarySectionProps {
  savedTracks: spotify.SavedTracks | null;
  currentPage: number;
  totalTracks: number;
  itemsPerPage: number;
  nowPlayingTrack: spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo | null;
  isPlaybackPaused: boolean;
  onPlay: (track: spotify.Track | spotify.SimpleTrack) => Promise<void>;
  onSave: (trackId: string) => Promise<void>;
  onRemove: (trackId: string) => Promise<void>;
  onNextPage: () => void;
  onPrevPage: () => void;
}

export function LibrarySection({
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
}: LibrarySectionProps) {
  const [isFavoritesCollapsed, setIsFavoritesCollapsed] = useState(false);

  return (
    <div className="saved-tracks">
      <div className="saved-tracks-header">
        <h2>Your Library</h2>
        <button
          className="collapse-button"
          onClick={() => setIsFavoritesCollapsed(!isFavoritesCollapsed)}
        >
          {isFavoritesCollapsed ? "▼" : "▲"}
        </button>
      </div>
      
      {!isFavoritesCollapsed && (
        <>
          {!savedTracks?.items || savedTracks.items.length === 0 ? (
            <div className="no-results">
              No saved tracks yet. Search for tracks to add them to your library.
            </div>
          ) : (
            <>
              <div className="track-grid">
                {savedTracks.items.map(
                  (item) =>
                    item.track && (
                      <TrackCard
                        key={item.track.id}
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
                    ),
                )}
              </div>
              <div className="pagination">
                <button onClick={onPrevPage} disabled={currentPage === 1}>
                  Previous
                </button>
                <span>
                  Page {currentPage} of {Math.ceil(totalTracks / itemsPerPage)}
                </span>
                <button
                  onClick={onNextPage}
                  disabled={currentPage * itemsPerPage >= totalTracks}
                >
                  Next
                </button>
              </div>
            </>
          )}
        </>
      )}
    </div>
  );
} 