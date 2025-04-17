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
  const userCheckInterval = useRef<ReturnType<typeof setInterval> | null>(null);
  const { enqueueSnackbar } = useSnackbar();

  const refreshUserProfile = useCallback(async () => {
    try {
      console.log("[useAuth] Refreshing user profile");
      const userProfile = await GetCurrentUser();
      if (userProfile) {
        console.log("[useAuth] Got user profile:", userProfile.display_name);
        setUser(userProfile);
      }
    } catch (error) {
      console.error("[useAuth] Error fetching user profile:", error);
    }
  }, []);

  const startAuthPolling = (onAuthenticated: () => Promise<void>) => {
    if (authCheckInterval.current) {
      clearInterval(authCheckInterval.current);
    }

    authCheckInterval.current = setInterval(async () => {
      try {
        const response = (await GetAuthStatus()) as unknown as AuthStatus;
        if (response.isAuthenticated) {
          setIsAuthenticated(true);
          await refreshUserProfile(); // Get user profile when authenticated
          await onAuthenticated();
          if (authCheckInterval.current) {
            clearInterval(authCheckInterval.current);
          }
          
          // Start periodic user profile refreshes
          startUserProfilePolling();
        } else {
          setIsAuthenticated(false);
        }
      } catch (error) {
        console.error("Error checking auth status:", error);
        setIsAuthenticated(false);
      }
    }, 1000);
  };

  // Function to periodically check for user profile updates
  const startUserProfilePolling = useCallback(() => {
    if (userCheckInterval.current) {
      clearInterval(userCheckInterval.current);
    }
    
    // Check for user profile updates every 30 seconds
    userCheckInterval.current = setInterval(async () => {
      if (isAuthenticated) {
        await refreshUserProfile();
      } else if (userCheckInterval.current) {
        clearInterval(userCheckInterval.current);
      }
    }, 30000);
  }, [isAuthenticated, refreshUserProfile]);

  const handleClearCreds = useCallback(async () => {
    try {
      await ClearSpotifyCredentials();
      setIsAuthenticated(false);
      setUser(null);
      
      // Immediately start polling for auth again
      startAuthPolling(async () => {
        console.log("[handleClearCreds] Re-authenticated after clearing credentials");
        // Any additional init logic can go here
      });
      
      enqueueSnackbar("Cleared Spotify credentials", { variant: "success" });
    } catch (error) {
      console.error("Error clearing credentials:", error);
      enqueueSnackbar("Error clearing credentials", { variant: "error" });
    }
  }, [enqueueSnackbar]);

  // Check auth status on mount
  useEffect(() => {
    const checkInitialAuth = async () => {
      try {
        const response = (await GetAuthStatus()) as unknown as AuthStatus;
        setIsAuthenticated(response.isAuthenticated);
        if (response.isAuthenticated) {
          await refreshUserProfile();
          // Start user profile polling when authenticated
          startUserProfilePolling();
        } else {
          setUser(null);
        }
      } catch (error) {
        console.error("Error checking initial auth status:", error);
        setIsAuthenticated(false);
      }
    };
    checkInitialAuth();
  }, [refreshUserProfile, startUserProfilePolling]);

  useEffect(() => {
    return () => {
      if (authCheckInterval.current) {
        clearInterval(authCheckInterval.current);
      }
      if (userCheckInterval.current) {
        clearInterval(userCheckInterval.current);
      }
    };
  }, []);

  return {
    user,
    isAuthenticated,
    startAuthPolling,
    handleClearCreds,
    refreshUserProfile,
  };
}
