import { useEffect, useState, useRef, useCallback } from "react";
import { GetValidToken } from "@wailsjs/go/bindings/Music";
import { SpotifyPlayerEvent } from "@/types/spotify";

/**
 * A hook that manages the Spotify Web Playback SDK player
 */
export function useSpotifyPlayer() {
  const [spotifyPlayer, setSpotifyPlayer] = useState<any>(null);
  const [spotifyDeviceId, setSpotifyDeviceId] = useState<string | null>(null);
  const [isInitializing, setIsInitializing] = useState(false);
  const [initializationError, setInitializationError] = useState<string | null>(null);
  
  // References for player state management
  const hasInitialized = useRef(false);
  const isConnecting = useRef(false);
  const retryCount = useRef(0);
  const maxRetries = 3;
  const deviceCheckInterval = useRef<NodeJS.Timeout | null>(null);

  /**
   * Initialize the Spotify Web Playback SDK player
   */
  const initializePlayer = useCallback(async () => {
    if (isConnecting.current) return;

    setIsInitializing(true);
    setInitializationError(null);
    isConnecting.current = true;

    try {
      // Check if Spotify SDK is already loaded
      if (!window.Spotify) return;

      // Clean up existing player if it exists
      if (spotifyPlayer) {
        await spotifyPlayer.disconnect();
        setSpotifyPlayer(null);
        setSpotifyDeviceId(null);
      }

      const player = new window.Spotify.Player({
        name: "Interestnaut Web Player",
        getOAuthToken: async (cb) => {
          try {
            const token = await GetValidToken();
            cb(token);
          } catch (err) {
            setInitializationError("Failed to get Spotify token");
            throw err;
          }
        },
        volume: 0.5,
      });

      // Add error handler for 404s
      player.addListener("playback_error", (event: SpotifyPlayerEvent) => {
        // If it's a device not found error, try to reconnect
        if (
          event.message?.includes("404") ||
          event.message?.includes("Device not found")
        ) {
          hasInitialized.current = false;
          initializePlayer();
        }
      });

      player.addListener("ready", (event: SpotifyPlayerEvent) => {
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
        setSpotifyDeviceId(null);
        setSpotifyPlayer(null);
        setIsInitializing(false);
        isConnecting.current = false;
        // Try to reconnect when device goes offline
        setTimeout(() => {
          hasInitialized.current = false;
          initializePlayer();
        }, 2000);
      });

      player.addListener(
        "authentication_error",
        (event: SpotifyPlayerEvent) => {
          if (event.message) {
            setInitializationError(`Failed to authenticate: ${event.message}`);
          }
          setIsInitializing(false);
          isConnecting.current = false;
          // Try to reconnect on auth error
          setTimeout(() => {
            hasInitialized.current = false;
            initializePlayer();
          }, 2000);
        },
      );

      // Add WebSocket error handler
      player.addListener("account_error", (event: SpotifyPlayerEvent) => {
        setSpotifyDeviceId(null);
        setSpotifyPlayer(null);
        setIsInitializing(false);
        isConnecting.current = false;
        // Try to reconnect on WebSocket error
        setTimeout(() => {
          hasInitialized.current = false;
          initializePlayer();
        }, 2000);
      });

      await player.connect();
    } catch (err) {
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
        setTimeout(initializePlayer, 2000 * retryCount.current); // Exponential backoff
      }
    }
  }, [spotifyPlayer]);

  /**
   * Check if the device is active
   */
  const checkDeviceStatus = useCallback(async () => {
    if (!spotifyPlayer || !spotifyDeviceId) return;

    try {
      const state = await spotifyPlayer.getCurrentState();
      if (!state) {
        hasInitialized.current = false;
        await initializePlayer();
      }
    } catch (error) {
      hasInitialized.current = false;
      await initializePlayer();
    }
  }, [spotifyPlayer, spotifyDeviceId, initializePlayer]);

  // Add periodic device status check
  useEffect(() => {
    if (spotifyPlayer && spotifyDeviceId) {
      // Clear any existing interval
      if (deviceCheckInterval.current) {
        clearInterval(deviceCheckInterval.current);
      }

      // Set up new interval
      deviceCheckInterval.current = setInterval(checkDeviceStatus, 30000); // Check every 30 seconds
    }

    return () => {
      if (deviceCheckInterval.current) {
        clearInterval(deviceCheckInterval.current);
      }
    };
  }, [spotifyPlayer, spotifyDeviceId, checkDeviceStatus]);

  // Initialize the player on mount
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
  }, [initializePlayer, spotifyPlayer]);

  // Return the player, device ID, and initialization state
  return {
    spotifyPlayer,
    spotifyDeviceId,
    isInitializing,
    initializationError,
    initializePlayer,
  };
} 