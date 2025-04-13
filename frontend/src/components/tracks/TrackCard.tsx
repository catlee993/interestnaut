import { FaPause, FaPlay } from "react-icons/fa";
import { spotify } from "../../../wailsjs/go/models";

interface TrackCardProps {
  track: spotify.Track | spotify.SimpleTrack;
  isSaved?: boolean;
  isPlaying?: boolean;
  onPlay: (track: spotify.Track | spotify.SimpleTrack) => Promise<void>;
  onSave?: (trackId: string) => Promise<void>;
  onRemove?: (trackId: string) => Promise<void>;
}

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
    <div className="track-card">
      {info.albumArtUrl && (
        <img src={info.albumArtUrl} alt={info.album} className="album-art" />
      )}
      <div className="track-info">
        <h3>{info.name}</h3>
        <p>{info.artist}</p>
        <p className="album-name">{info.album}</p>
        {!canPlay && (
          <p className="preview-unavailable">Playback unavailable</p>
        )}
      </div>
      <div className="track-controls">
        <button
          className={`play-button ${isPlaying ? "playing" : ""} ${!canPlay ? "no-preview" : ""}`}
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
          {!canPlay && <span className="no-preview-icon">🚫</span>}
        </button>
        {isSaved ? (
          <button
            className="remove-button"
            onClick={() => onRemove?.(track.id)}
          >
            Remove
          </button>
        ) : (
          <button className="save-button" onClick={() => onSave?.(track.id)}>
            Save
          </button>
        )}
      </div>
    </div>
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
