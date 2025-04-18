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
  const [initializationError, setInitializationError] = useState<string | null>(
    null,
  );

  // References for player state management
  const hasInitialized = useRef(false);
  const isConnecting = useRef(false);
  const retryCount = useRef(0);
  const maxRetries = 5; // Increased from 3 to 5
  const deviceCheckInterval = useRef<NodeJS.Timeout | null>(null);
  const lastTokenRefresh = useRef<number>(Date.now());
  const tokenRefreshTimeout = useRef<NodeJS.Timeout | null>(null);

  /**
   * Force refresh the token regardless of current state
   */
  const forceTokenRefresh = useCallback(async () => {
    try {
      console.log("[SpotifyPlayer] Forcing token refresh");
      await GetValidToken();
      lastTokenRefresh.current = Date.now();
      return true;
    } catch (err) {
      console.error("[SpotifyPlayer] Token refresh failed:", err);
      return false;
    }
  }, []);

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

      // Force refresh token if it's been more than 50 minutes since last refresh
      // (Spotify tokens typically last 60 minutes)
      const timeSinceLastRefresh = Date.now() - lastTokenRefresh.current;
      if (timeSinceLastRefresh > 50 * 60 * 1000) {
        await forceTokenRefresh();
      }

      const player = new window.Spotify.Player({
        name: "Interestnaut Web Player",
        getOAuthToken: async (cb) => {
          try {
            const token = await GetValidToken();
            lastTokenRefresh.current = Date.now();
            cb(token);
          } catch (err) {
            console.error("[SpotifyPlayer] Failed to get token:", err);
            setInitializationError("Failed to get Spotify token");

            // Try to force refresh token on error
            const refreshed = await forceTokenRefresh();
            if (refreshed) {
              try {
                const newToken = await GetValidToken();
                cb(newToken);
              } catch (refreshErr) {
                throw refreshErr;
              }
            } else {
              throw err;
            }
          }
        },
        volume: 0.5,
      });

      // Add error handler for 404s and 401s (auth errors)
      player.addListener("playback_error", (event: SpotifyPlayerEvent) => {
        console.error("[SpotifyPlayer] Playback error:", event.message);

        // Check for both 404 (device not found) and 401 (unauthorized) errors
        if (
          event.message?.includes("404") ||
          event.message?.includes("Device not found") ||
          event.message?.includes("401") ||
          event.message?.includes("Unauthorized")
        ) {
          // For 401s specifically, try to force refresh the token first
          if (
            event.message?.includes("401") ||
            event.message?.includes("Unauthorized")
          ) {
            forceTokenRefresh().then((success) => {
              if (success) {
                console.log(
                  "[SpotifyPlayer] Token refreshed, reconnecting player",
                );
                // Set a short delay before reconnecting to allow token to propagate
                setTimeout(() => {
                  hasInitialized.current = false;
                  initializePlayer();
                }, 1000);
              }
            });
          } else {
            // For other errors, just reconnect
            hasInitialized.current = false;
            initializePlayer();
          }
        }
      });

      player.addListener("ready", (event: SpotifyPlayerEvent) => {
        console.log("[SpotifyPlayer] Ready with device ID:", event.device_id);
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
        console.warn("[SpotifyPlayer] Device is not ready:", event);
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
          console.error("[SpotifyPlayer] Authentication error:", event.message);
          if (event.message) {
            setInitializationError(`Failed to authenticate: ${event.message}`);
          }
          setIsInitializing(false);
          isConnecting.current = false;

          // Try to refresh token first, but with an aggressive timeout
          // to avoid UI locking up if backend is also having issues
          const tokenPromise = forceTokenRefresh();
          const timeoutPromise = new Promise((_, reject) => {
            setTimeout(() => reject(new Error("Token refresh timed out")), 5000);
          });
          
          Promise.race([tokenPromise, timeoutPromise])
            .then((success) => {
              if (success === true) {
                console.log("[SpotifyPlayer] Token refresh successful, reconnecting player");
                // If token refresh was successful, try to reconnect with longer delay
                setTimeout(() => {
                  hasInitialized.current = false;
                  initializePlayer();
                }, 2000); // Increased from 1000 to 2000ms
              } else {
                // Handle unexpected response
                throw new Error("Unexpected response from token refresh");
              }
            })
            .catch((error) => {
              console.error("[SpotifyPlayer] Token refresh failed or timed out:", error);
              
              // If we've had too many auth errors in a short time, stop retrying
              // Check the time between retries to avoid rapid looping
              const now = Date.now();
              const MIN_RETRY_INTERVAL = 30000; // 30 seconds minimum between auth error retries
              
              if (lastTokenRefresh.current > 0 && (now - lastTokenRefresh.current) < MIN_RETRY_INTERVAL) {
                console.warn("[SpotifyPlayer] Too many auth errors too quickly, pausing retries for 2 minutes");
                retryCount.current = maxRetries; // Force a longer wait by maxing out retries
                
                // Display a more informative error to the user
                setInitializationError("Spotify authentication is failing repeatedly. Please try manually clearing credentials.");
                
                // After 2 minutes, reset the retry count to allow another attempt
                setTimeout(() => {
                  console.log("[SpotifyPlayer] Resetting retry count after cooling period");
                  retryCount.current = 0;
                  lastTokenRefresh.current = Date.now();
                }, 120000); // 2 minutes
                
                return;
              }
              
              // Use much more aggressive exponential backoff for auth errors
              const delay = Math.min(
                120000, // 2 minute max delay
                5000 * Math.pow(2, retryCount.current), // Start with 5 seconds, then 10s, 20s, 40s...
              );
              retryCount.current += 1;

              if (retryCount.current <= maxRetries) {
                console.log(
                  `[SpotifyPlayer] Retrying in ${delay / 1000} seconds (attempt ${retryCount.current}/${maxRetries})`,
                );
                setTimeout(() => {
                  hasInitialized.current = false;
                  initializePlayer();
                }, delay);
              } else {
                console.error("[SpotifyPlayer] Exceeded maximum retry attempts for authentication");
                setInitializationError("Failed to authenticate after multiple attempts. Please try clearing your Spotify credentials.");
              }
            });
        },
      );

      // Add WebSocket error handler
      player.addListener("account_error", (event: SpotifyPlayerEvent) => {
        console.error("[SpotifyPlayer] Account error:", event.message);
        setSpotifyDeviceId(null);
        setSpotifyPlayer(null);
        setIsInitializing(false);
        isConnecting.current = false;

        // Try to reconnect on WebSocket error with exponential backoff
        const delay = Math.min(30000, 2000 * Math.pow(2, retryCount.current));
        retryCount.current += 1;

        if (retryCount.current <= maxRetries) {
          setTimeout(() => {
            hasInitialized.current = false;
            initializePlayer();
          }, delay);
        }
      });

      await player.connect();
    } catch (err) {
      const errorMessage =
        err instanceof Error
          ? err.message
          : "Unknown error during initialization";
      console.error("[SpotifyPlayer] Initialization error:", errorMessage);

      setInitializationError(errorMessage);
      setIsInitializing(false);
      isConnecting.current = false;

      // Retry initialization with exponential backoff if we haven't exceeded max retries
      if (retryCount.current < maxRetries) {
        const delay = Math.min(30000, 2000 * Math.pow(2, retryCount.current));
        retryCount.current += 1;
        console.log(
          `[SpotifyPlayer] Retrying in ${delay / 1000} seconds (attempt ${retryCount.current}/${maxRetries})`,
        );

        setTimeout(initializePlayer, delay);
      }
    }
  }, [spotifyPlayer, forceTokenRefresh]);

  /**
   * Check if the device is active and refresh token if needed
   */
  const checkDeviceStatus = useCallback(async () => {
    if (!spotifyPlayer) return;

    try {
      // First check if we need to refresh the token based on time
      const timeSinceLastRefresh = Date.now() - lastTokenRefresh.current;
      if (timeSinceLastRefresh > 50 * 60 * 1000) {
        // 50 minutes
        console.log("[SpotifyPlayer] Token may be expiring soon, refreshing");
        await forceTokenRefresh();
      }

      // Then check the player state
      const state = await spotifyPlayer.getCurrentState();
      if (!state && spotifyDeviceId) {
        console.log("[SpotifyPlayer] Device inactive, reconnecting");
        hasInitialized.current = false;
        await initializePlayer();
      }
    } catch (error) {
      console.error("[SpotifyPlayer] Error checking device status:", error);
      // If there's an error getting the state, try to reconnect
      hasInitialized.current = false;
      await initializePlayer();
    }
  }, [spotifyPlayer, spotifyDeviceId, initializePlayer, forceTokenRefresh]);

  // Add periodic device status check and token refresh
  useEffect(() => {
    if (spotifyPlayer) {
      // Clear any existing intervals
      if (deviceCheckInterval.current) {
        clearInterval(deviceCheckInterval.current);
      }
      if (tokenRefreshTimeout.current) {
        clearTimeout(tokenRefreshTimeout.current);
      }

      // Set up new interval - check every 5 minutes
      deviceCheckInterval.current = setInterval(
        checkDeviceStatus,
        5 * 60 * 1000,
      );

      // Also schedule a token refresh for 50 minutes from now
      const timeSinceLastRefresh = Date.now() - lastTokenRefresh.current;
      const timeToRefresh = Math.max(0, 50 * 60 * 1000 - timeSinceLastRefresh);

      tokenRefreshTimeout.current = setTimeout(() => {
        forceTokenRefresh().then(() => {
          console.log("[SpotifyPlayer] Scheduled token refresh completed");
        });
      }, timeToRefresh);
    }

    return () => {
      if (deviceCheckInterval.current) {
        clearInterval(deviceCheckInterval.current);
      }
      if (tokenRefreshTimeout.current) {
        clearTimeout(tokenRefreshTimeout.current);
      }
    };
  }, [spotifyPlayer, checkDeviceStatus, forceTokenRefresh]);

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

      // Clear all intervals and timeouts
      if (deviceCheckInterval.current) {
        clearInterval(deviceCheckInterval.current);
      }
      if (tokenRefreshTimeout.current) {
        clearTimeout(tokenRefreshTimeout.current);
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
