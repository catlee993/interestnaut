import { useEffect, useRef, useState, useCallback } from "react";
import {
  GetAuthStatus,
  ClearSpotifyCredentials,
  GetCurrentUser,
  GetValidToken,
} from "@wailsjs/go/bindings/Music";
import { spotify } from "@wailsjs/go/models";
import { useSnackbar } from "notistack";

interface AuthStatus {
  isAuthenticated: boolean;
}

export function useAuth() {
  const [user, setUser] = useState<spotify.UserProfile | null>(null);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const authCheckInterval = useRef<ReturnType<typeof setInterval> | null>(null);
  const { enqueueSnackbar } = useSnackbar();

  const startAuthPolling = (onAuthenticated: () => Promise<void>) => {
    if (authCheckInterval.current) {
      clearInterval(authCheckInterval.current);
    }

    authCheckInterval.current = setInterval(async () => {
      try {
        const response = (await GetAuthStatus()) as unknown as AuthStatus;
        if (response.isAuthenticated) {
          setIsAuthenticated(true);
          await onAuthenticated();
          if (authCheckInterval.current) {
            clearInterval(authCheckInterval.current);
          }
        } else {
          setIsAuthenticated(false);
        }
      } catch (error) {
        console.error("Error checking auth status:", error);
        setIsAuthenticated(false);
      }
    }, 1000);
  };

  const handleClearCreds = useCallback(async () => {
    try {
      await ClearSpotifyCredentials();
      setIsAuthenticated(false);
      setUser(null);
      enqueueSnackbar("Cleared Spotify credentials", { variant: "success" });
    } catch (error) {
      console.error("Error clearing credentials:", error);
      enqueueSnackbar("Error clearing credentials", { variant: "error" });
    }
  }, []);

  // Check auth status on mount
  useEffect(() => {
    const checkInitialAuth = async () => {
      try {
        const response = (await GetAuthStatus()) as unknown as AuthStatus;
        setIsAuthenticated(response.isAuthenticated);
        if (response.isAuthenticated) {
          const userProfile = await GetCurrentUser();
          setUser(userProfile);
        } else {
          setUser(null);
        }
      } catch (error) {
        console.error("Error checking initial auth status:", error);
        setIsAuthenticated(false);
      }
    };
    checkInitialAuth();
  }, []);

  useEffect(() => {
    return () => {
      if (authCheckInterval.current) {
        clearInterval(authCheckInterval.current);
      }
    };
  }, []);

  return {
    user,
    isAuthenticated,
    startAuthPolling,
    handleClearCreds,
  };
}
