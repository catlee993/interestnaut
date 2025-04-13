import {
  createContext,
  useContext,
  useState,
  ReactNode,
  useEffect,
  useRef,
} from "react";
import { spotify } from "../../wailsjs/go/models";
import {
  PausePlaybackOnDevice,
  PlayTrackOnDevice,
  GetValidToken,
} from "../../wailsjs/go/bindings/Music";

interface PlayerContextType {
  nowPlayingTrack:
    | spotify.Track
    | spotify.SimpleTrack
    | spotify.SuggestedTrackInfo
    | null;
  isPlaybackPaused: boolean;
  isUsingPreview: boolean;
  spotifyPlayer: any;
  spotifyDeviceId: string | null;
  handlePlay: (
    track: spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo,
  ) => Promise<void>;
  stopPlayback: () => Promise<void>;
  handlePlayPause: () => void;
}

const PlayerContext = createContext<PlayerContextType | undefined>(undefined);

interface PlayerProviderProps {
  children: ReactNode;
}

export function PlayerProvider({ children }: PlayerProviderProps): JSX.Element {
  const [nowPlayingTrack, setNowPlayingTrack] = useState<
    spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo | null
  >(null);
  const [isPlaybackPaused, setIsPlaybackPaused] = useState(true);
  const [isUsingPreview, setIsUsingPreview] = useState(true);
  const [spotifyPlayer, setSpotifyPlayer] = useState<any>(null);
  const [spotifyDeviceId, setSpotifyDeviceId] = useState<string | null>(null);
  const audioRef = useRef<HTMLAudioElement>(new Audio());
  const hasInitialized = useRef(false);

  useEffect(() => {
    if (hasInitialized.current) return;
    hasInitialized.current = true;

    // Load Spotify Web Playback SDK
    const script = document.createElement("script");
    script.src = "https://sdk.scdn.co/spotify-player.js";
    script.async = true;

    document.body.appendChild(script);

    window.onSpotifyWebPlaybackSDKReady = () => {
      const player = new window.Spotify.Player({
        name: "Interestnaut Web Player",
        getOAuthToken: (cb) => {
          GetValidToken().then((token) => cb(token));
        },
        volume: 0.5,
      });

      player.addListener("ready", ({ device_id }) => {
        console.log("Ready with Device ID", device_id);
        setSpotifyDeviceId(device_id);
        setSpotifyPlayer(player);
      });

      player.addListener("not_ready", ({ device_id }) => {
        console.log("Device ID has gone offline", device_id);
      });

      player.connect();
    };

    return () => {
      if (spotifyPlayer) {
        spotifyPlayer.disconnect();
      }
      document.body.removeChild(script);
    };
  }, []);

  const handlePlay = async (
    track: spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo,
  ) => {
    console.log("[handlePlay] Called for track:", track?.name);

    // Check if we're trying to pause the current track
    if (nowPlayingTrack?.id === track.id && !isPlaybackPaused) {
      console.log("[handlePlay] Pausing current track");
      await stopPlayback();
      return;
    }

    // If we have a Spotify player and device ID, try full song playback
    if (spotifyPlayer && spotifyDeviceId) {
      try {
        console.log("[handlePlay] Attempting full song playback");
        const trackUri =
          "uri" in track ? track.uri : `spotify:track:${track.id}`;
        await PlayTrackOnDevice(spotifyDeviceId, trackUri);
        setNowPlayingTrack(track);
        setIsPlaybackPaused(false);
        setIsUsingPreview(false);
        return;
      } catch (err) {
        console.error("[handlePlay] Full playback failed:", err);
        // Fall back to preview if available
      }
    }

    // Fall back to preview URL playback
    if ("previewUrl" in track && track.previewUrl) {
      console.log("[handlePlay] Using preview URL playback");
      try {
        audioRef.current.src = track.previewUrl;
        await audioRef.current.play();
        setNowPlayingTrack(track);
        setIsPlaybackPaused(false);
        setIsUsingPreview(true);
      } catch (err) {
        console.error("[handlePlay] Preview playback failed:", err);
        throw new Error("Failed to play track. Please try again.");
      }
    } else {
      throw new Error("No preview available for this track.");
    }
  };

  const stopPlayback = async () => {
    if (!isUsingPreview && spotifyPlayer && spotifyDeviceId) {
      await PausePlaybackOnDevice(spotifyDeviceId);
    } else {
      audioRef.current.pause();
    }
    setIsPlaybackPaused(true);
  };

  const handlePlayPause = () => {
    // Implementation of handlePlayPause method
  };

  const value: PlayerContextType = {
    nowPlayingTrack,
    isPlaybackPaused,
    isUsingPreview,
    spotifyPlayer,
    spotifyDeviceId,
    handlePlay,
    stopPlayback,
    handlePlayPause,
  };

  return (
    <PlayerContext.Provider value={value}>{children}</PlayerContext.Provider>
  );
}

export function usePlayer() {
  const context = useContext(PlayerContext);
  if (context === undefined) {
    throw new Error("usePlayer must be used within a PlayerProvider");
  }
  return context;
}
