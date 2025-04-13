import { FaPause, FaPlay } from "react-icons/fa";
import { spotify } from "../../../wailsjs/go/models";

interface NowPlayingBarProps {
  track: spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo;
  isPlaybackPaused: boolean;
  onPlayPause: () => void;
}

export function NowPlayingBar({
  track,
  isPlaybackPaused,
  onPlayPause,
}: NowPlayingBarProps) {
  const info = getTrackInfo(track);

  return (
    <div className="now-playing">
      <img src={info.albumArtUrl} alt={info.name} className="now-playing-art" />
      <div className="now-playing-details">
        <p>
          <strong>{info.name}</strong>
        </p>
        <p>{info.artist}</p>
        <p className="playback-type">
          {info.previewUrl ? "(Preview)" : "(Full Song)"}
        </p>
      </div>
      <button
        className={`play-pause-button ${isPlaybackPaused ? "" : "playing"}`}
        onClick={onPlayPause}
      >
        {isPlaybackPaused ? <FaPlay /> : <FaPause />}
      </button>
    </div>
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
  if (
    "artist" in track &&
    typeof track.artist === "string" &&
    "albumArtUrl" in track
  ) {
    return {
      name: track.name,
      artist: track.artist,
      album: track.album || "",
      albumArtUrl: track.albumArtUrl || "",
      previewUrl: track.previewUrl || null,
    };
  }

  // Handle SuggestedTrackInfo type
  if ("artist" in track && typeof track.artist === "string") {
    return {
      name: track.name,
      artist: track.artist,
      album: "",
      albumArtUrl: "albumArtUrl" in track ? track.albumArtUrl || "" : "",
      previewUrl: "previewUrl" in track ? track.previewUrl || null : null,
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
