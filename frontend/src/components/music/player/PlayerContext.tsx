import {
  createContext,
  useContext,
  useState,
  ReactNode,
  useEffect,
  useRef,
  useCallback,
} from "react";
import { spotify } from "@wailsjs/go/models";
import {
  PausePlaybackOnDevice,
  PlayTrackOnDevice,
  GetValidToken,
} from "@wailsjs/go/bindings/Music";
import { SpotifyPlayerEvent, SpotifyPlayerState } from "@/types/spotify";

interface PlayerContextType {
  nowPlayingTrack:
    | spotify.Track
    | spotify.SimpleTrack
    | spotify.SuggestedTrackInfo
    | null;
  isPlaybackPaused: boolean;
  spotifyPlayer: any;
  spotifyDeviceId: string | null;
  currentPosition: number;
  duration: number;
  handlePlay: (
    track: spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo | string,
  ) => Promise<void>;
  stopPlayback: () => Promise<void>;
  handlePlayPause: () => void;
  seekTo: (position: number) => void;
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
  const [spotifyPlayer, setSpotifyPlayer] = useState<any>(null);
  const [spotifyDeviceId, setSpotifyDeviceId] = useState<string | null>(null);
  const [currentPosition, setCurrentPosition] = useState(0);
  const [duration, setDuration] = useState(0);
  const [isInitializing, setIsInitializing] = useState(false);
  const [initializationError, setInitializationError] = useState<string | null>(
    null,
  );
  const hasInitialized = useRef(false);
  const isConnecting = useRef(false);
  const retryCount = useRef(0);
  const maxRetries = 3;

  const initializePlayer = useCallback(async () => {
    if (isConnecting.current || hasInitialized.current) {
      console.log(
        "[initializePlayer] Already connecting or initialized, skipping",
      );
      return;
    }

    console.log("[initializePlayer] Starting initialization");
    setIsInitializing(true);
    setInitializationError(null);
    isConnecting.current = true;

    try {
      // Check if Spotify SDK is already loaded
      if (!window.Spotify) {
        console.log(
          "[initializePlayer] Spotify SDK not loaded, waiting for script",
        );
        return;
      }

      const player = new window.Spotify.Player({
        name: "Interestnaut Web Player",
        getOAuthToken: async (cb) => {
          try {
            const token = await GetValidToken();
            console.log("[initializePlayer] Got token");
            cb(token);
          } catch (err) {
            console.error("[initializePlayer] Failed to get token:", err);
            setInitializationError("Failed to get Spotify token");
            throw err;
          }
        },
        volume: 0.5,
      });

      player.addListener("ready", (event: SpotifyPlayerEvent) => {
        console.log("Ready with Device ID", event.device_id);
        if (event.device_id) {
          setSpotifyDeviceId(event.device_id);
        }
        setSpotifyPlayer(player);
        setIsInitializing(false);
        isConnecting.current = false;
        hasInitialized.current = true;
        retryCount.current = 0;
      });

      player.addListener("not_ready", (event: SpotifyPlayerEvent) => {
        console.log("Device ID has gone offline", event.device_id);
        setSpotifyDeviceId(null);
        setSpotifyPlayer(null);
        setIsInitializing(false);
        isConnecting.current = false;
      });

      player.addListener(
        "player_state_changed",
        (event: SpotifyPlayerEvent) => {
          if (event.state) {
            console.log("[player_state_changed] State:", event.state);
            const state = event.state as SpotifyPlayerState;
            setCurrentPosition(state.position);
            setDuration(state.duration);
            setIsPlaybackPaused(state.paused);
          }
        },
      );

      player.addListener(
        "initialization_error",
        (event: SpotifyPlayerEvent) => {
          console.error("Failed to initialize:", event.message);
          if (event.message) {
            setInitializationError(`Failed to initialize: ${event.message}`);
          }
          setIsInitializing(false);
          isConnecting.current = false;
        },
      );

      player.addListener(
        "authentication_error",
        (event: SpotifyPlayerEvent) => {
          console.error("Failed to authenticate:", event.message);
          if (event.message) {
            setInitializationError(`Failed to authenticate: ${event.message}`);
          }
          setIsInitializing(false);
          isConnecting.current = false;
        },
      );

      player.addListener("account_error", (event: SpotifyPlayerEvent) => {
        console.error("Failed to validate Spotify account:", event.message);
        if (event.message) {
          setInitializationError(
            `Failed to validate Spotify account: ${event.message}`,
          );
        }
        setIsInitializing(false);
        isConnecting.current = false;
      });

      await player.connect();
      // If we get here, connection was successful
      setSpotifyPlayer(player);
      setIsInitializing(false);
      isConnecting.current = false;
      hasInitialized.current = true;
      retryCount.current = 0;
    } catch (err) {
      console.error("[initializePlayer] Failed to create Spotify player:", err);
      setInitializationError(
        err instanceof Error
          ? err.message
          : "Unknown error during initialization",
      );
      setIsInitializing(false);
      isConnecting.current = false;

      // Retry initialization if we haven't exceeded max retries
      if (retryCount.current < maxRetries) {
        retryCount.current += 1;
        console.log(
          `[initializePlayer] Retrying initialization (attempt ${retryCount.current}/${maxRetries})`,
        );
        setTimeout(initializePlayer, 2000 * retryCount.current); // Exponential backoff
      }
    }
  }, []);

  useEffect(() => {
    if (hasInitialized.current) return;

    // Load Spotify Web Playback SDK
    const script = document.createElement("script");
    script.src = "https://sdk.scdn.co/spotify-player.js";
    script.async = true;

    // Only set the callback if it hasn't been set yet
    if (!window.onSpotifyWebPlaybackSDKReady) {
      window.onSpotifyWebPlaybackSDKReady = initializePlayer;
    }

    document.body.appendChild(script);

    return () => {
      if (spotifyPlayer) {
        spotifyPlayer.disconnect();
      }
    };
  }, [initializePlayer]);

  // Add position tracking interval
  useEffect(() => {
    let interval: NodeJS.Timeout;

    if (spotifyPlayer && !isPlaybackPaused) {
      interval = setInterval(async () => {
        try {
          const state = await spotifyPlayer.getCurrentState();
          if (state) {
            setCurrentPosition(state.position);
            setDuration(state.duration);
          }
        } catch (error) {
          console.error(
            "[position tracking] Failed to get current state:",
            error,
          );
        }
      }, 1000); // Update every second
    }

    return () => {
      if (interval) {
        clearInterval(interval);
      }
    };
  }, [spotifyPlayer, isPlaybackPaused]);

  const handlePlay = async (
    trackOrUri: spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo | string,
  ) => {
    if (!spotifyDeviceId) {
      console.error("No active Spotify device found");
      return;
    }

    const trackUri = typeof trackOrUri === 'string' ? trackOrUri : trackOrUri.uri;
    if (!trackUri) {
      console.error("No track URI provided");
      return;
    }

    try {
      await PlayTrackOnDevice(spotifyDeviceId, trackUri);
      if (typeof trackOrUri !== 'string') {
        setNowPlayingTrack(trackOrUri);
      }
      setIsPlaybackPaused(false);
    } catch (error) {
      console.error("Failed to play track:", error);
    }
  };

  const stopPlayback = async () => {
    if (spotifyPlayer && spotifyDeviceId) {
      try {
        await PausePlaybackOnDevice(spotifyDeviceId);
      } catch (error: unknown) {
        const errorMessage =
          error instanceof Error
            ? error.message
            : "Unknown error occurred while pausing playback";
        console.error("[stopPlayback]", errorMessage);
      }
    }
    setIsPlaybackPaused(true);
  };

  const handlePlayPause = async () => {
    if (!nowPlayingTrack) return;

    if (isPlaybackPaused) {
      // Resume playback
      if (spotifyPlayer && spotifyDeviceId) {
        try {
          const trackUri =
            "uri" in nowPlayingTrack
              ? nowPlayingTrack.uri
              : `spotify:track:${nowPlayingTrack.id}`;
          await PlayTrackOnDevice(spotifyDeviceId, trackUri!);
          setIsPlaybackPaused(false);
        } catch (error: unknown) {
          const errorMessage =
            error instanceof Error
              ? error.message
              : "Unknown error occurred while resuming playback";
          console.error(
            "[handlePlayPause] Failed to resume Spotify playback:",
            errorMessage,
          );
        }
      }
    } else {
      // Pause playback
      await stopPlayback();
    }
  };

  const seekTo = useCallback(
    async (position: number) => {
      if (!nowPlayingTrack) return;

      try {
        // Convert position from milliseconds to seconds for the API
        const positionMs = Math.floor(position);
        console.log("[seekTo] Seeking to position:", positionMs);

        if (spotifyPlayer && "uri" in nowPlayingTrack) {
          // Use the Spotify Player's seek method for full tracks
          await spotifyPlayer.seek(positionMs);
        } else {
          // For preview tracks, we can only update the UI position
          setCurrentPosition(positionMs);
        }

        // Update the UI position
        setCurrentPosition(positionMs);
      } catch (error) {
        console.error("[seekTo] Failed to seek:", error);
        // Revert the UI position if the seek failed
        if (spotifyPlayer) {
          const state = await spotifyPlayer.getCurrentState();
          if (state) {
            setCurrentPosition(state.position);
          }
        }
      }
    },
    [nowPlayingTrack, spotifyPlayer],
  );

  const value: PlayerContextType = {
    nowPlayingTrack,
    isPlaybackPaused,
    spotifyPlayer,
    spotifyDeviceId,
    currentPosition,
    duration,
    handlePlay,
    stopPlayback,
    handlePlayPause,
    seekTo,
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
