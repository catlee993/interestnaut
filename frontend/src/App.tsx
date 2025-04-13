import { useEffect, useRef, useState } from "react";
import {
  FaPause,
  FaPlay,
  FaPlus,
  FaStepForward,
  FaThumbsDown,
  FaThumbsUp,
} from "react-icons/fa";
import "./App.css";
import {
  ClearSpotifyCredentials,
  GetAuthStatus,
  GetCurrentUser,
  GetSavedTracks,
  GetValidToken,
  PausePlaybackOnDevice,
  PlayTrackOnDevice,
  ProvideSuggestionFeedback,
  RemoveTrack,
  RequestNewSuggestion,
  SaveTrack,
  SearchTracks,
} from "../wailsjs/go/bindings/Music";
import { session, spotify } from "../wailsjs/go/models";

// Declare Spotify types for TypeScript (if not already globally available)
declare global {
  interface Window {
    onSpotifyWebPlaybackSDKReady: () => void;
    Spotify: {
      Player: new (config: {
        name: string;
        getOAuthToken: (callback: (token: string) => void) => void;
        volume: number;
      }) => {
        addListener: (
          event: string,
          callback: (data: { device_id: string }) => void,
        ) => void;
        connect: () => Promise<void>;
        disconnect: () => void;
      };
    };
  }
}

function App() {
  const [savedTracks, setSavedTracks] = useState<spotify.SavedTracks | null>(
    null,
  );
  const [searchResults, setSearchResults] = useState<spotify.SimpleTrack[]>([]);
  const [searchQuery, setSearchQuery] = useState<string>("");
  const [user, setUser] = useState<spotify.UserProfile | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<{
    message: string;
    type: "success" | "error" | "dislike" | "skip";
  } | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [currentPage, setCurrentPage] = useState<number>(1);
  const [totalTracks, setTotalTracks] = useState<number>(0);
  const [nowPlayingTrack, setNowPlayingTrack] = useState<
    spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo | null
  >(null);
  const [isFavoritesCollapsed, setIsFavoritesCollapsed] =
    useState<boolean>(false);
  const [audioElement] = useState<HTMLAudioElement>(new Audio());
  const [isPlaybackPaused, setIsPlaybackPaused] = useState<boolean>(true);
  const [spotifyPlayer, setSpotifyPlayer] = useState<any>(null);
  const [spotifyDeviceId, setSpotifyDeviceId] = useState<string | null>(null);
  const [isUsingPreview, setIsUsingPreview] = useState<boolean>(true);
  const [hasLikedCurrentSuggestion, setHasLikedCurrentSuggestion] =
    useState<boolean>(false);

  const [isProcessingLibrary, setIsProcessingLibrary] =
    useState<boolean>(false);
  const [suggestionError, setSuggestionError] = useState<string | null>(null);
  const [suggestedTrack, setSuggestedTrack] =
    useState<spotify.SuggestedTrackInfo | null>(null);
  const [suggestionContext, setSuggestionContext] = useState<string | null>(
    null,
  );
  const [showSuggestionSection, setShowSuggestionSection] =
    useState<boolean>(false);

  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false);
  const authCheckInterval = useRef<number | null>(null);

  const ITEMS_PER_PAGE = 20;
  const hasInitialized = useRef<boolean>(false);

  useEffect(() => {
    if (!hasInitialized.current) {
      hasInitialized.current = true;
      initializeApp();
    }

    return () => {
      if (authCheckInterval.current) {
        clearInterval(authCheckInterval.current);
      }
      // Clean up audio
      audioElement.pause();
    };
  }, []);

  // Add effect to handle audio element events
  useEffect(() => {
    const handleEnded = () => {
      console.log("[Audio] Track ended");
      setIsPlaybackPaused(true);
    };

    const handlePause = () => {
      console.log("[Audio] Track paused");
      setIsPlaybackPaused(true);
    };

    const handlePlay = () => {
      console.log("[Audio] Track started playing");
      setIsPlaybackPaused(false);
    };

    const handleError = (e: ErrorEvent) => {
      console.error("[Audio] Error during playback:", e);
      setError("Error during playback. Please try again.");
      setIsPlaybackPaused(true);
    };

    audioElement.addEventListener("ended", handleEnded);
    audioElement.addEventListener("pause", handlePause);
    audioElement.addEventListener("play", handlePlay);
    audioElement.addEventListener("error", handleError);

    return () => {
      console.log("[Audio] Cleaning up event listeners");
      audioElement.pause();
      audioElement.removeEventListener("ended", handleEnded);
      audioElement.removeEventListener("pause", handlePause);
      audioElement.removeEventListener("play", handlePlay);
      audioElement.removeEventListener("error", handleError);
    };
  }, [audioElement]);

  // Helper function to handle suggestion errors consistently
  const handleSuggestionError = (err: unknown) => {
    console.error("Suggestion error:", err);
    let errorMsg = "";

    if (err && typeof err === "object") {
      console.log("Error is an object with properties:", Object.keys(err));
      errorMsg =
        (err as any).error || // Wails error format
        (err as Error).message || // Standard Error format
        (err as any).message || // Generic object with message
        (typeof err === "string" ? err : ""); // String error
    } else if (typeof err === "string") {
      errorMsg = err;
    }

    if (!errorMsg) {
      console.log("No error message found in error object, using default");
      errorMsg = "Failed to get suggestion.";
    }

    console.log("Final extracted error message:", errorMsg);

    if (errorMsg.includes("Could not find")) {
      console.log(
        "Error indicates a failed search, attempting to extract context",
      );
      const match = errorMsg.match(
        /Could not find '(.+)' by '(.+)' on Spotify/,
      );
      if (match) {
        const [_, track, artist] = match;
        const searchContext = `${track} by ${artist}`;
        console.log("Successfully extracted search context:", {
          track,
          artist,
          searchContext,
        });
        setSuggestionContext(searchContext);
        setSuggestionError(
          `Searched for "${searchContext}" on Spotify but couldn't find it.`,
        );
      } else {
        console.log("Could not parse search context from error message");
        setSuggestionError(errorMsg);
      }
    } else {
      console.log("Error does not contain search context, using raw message");
      setSuggestionError(errorMsg);
    }
  };

  const loadAppData = async () => {
    console.log("loadAppData: Loading core application data...");
    try {
      // Ensure user is loaded first
      const currentUser = user ?? (await GetCurrentUser());
      if (!currentUser) {
        throw new Error("Failed to load current user after authentication.");
      }
      if (!user) setUser(currentUser); // Set user state if not already set

      setIsAuthenticated(true); // Mark as authenticated
      await loadSavedTracks(1);

      // Show suggestion section and request first suggestion
      setShowSuggestionSection(true);
      await handleRequestSuggestion();
    } catch (err) {
      console.error("Failed to load app data:", err);
      console.log("Outer error type:", typeof err);
      console.log("Outer error object:", err);
      setError(
        err instanceof Error ? err.message : "An error occurred loading data",
      );
      setIsAuthenticated(false); // Ensure auth state reflects potential failure
    } finally {
      setIsLoading(false);
      console.log("loadAppData: Finished loading core data.");
    }
  };

  const initializeApp = async () => {
    console.log("initializeApp called...");
    setIsLoading(true);
    setError(null);
    setSuggestionError(null);

    try {
      console.log("Attempting initial user fetch...");
      const currentUser = await GetCurrentUser();
      setUser(currentUser);
      console.log("Initial user fetch successful.");
      // If user fetch worked, we are authenticated, load data
      await loadAppData();
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message.toLowerCase() : "";
      if (errorMsg.includes("not authenticated")) {
        console.log(
          "Not authenticated initially. Starting auth check polling...",
        );
        setIsAuthenticated(false);
        setIsLoading(false); // Stop main loading indicator
        // Clear previous interval if any
        if (authCheckInterval.current) clearInterval(authCheckInterval.current);
        // Poll for authentication status
        authCheckInterval.current = setInterval(async () => {
          console.log("Polling GetAuthStatus...");
          try {
            const status = await GetAuthStatus();
            if (status.isAuthenticated) {
              console.log(
                "Authentication detected! Stopping poll and loading data.",
              );
              if (authCheckInterval.current)
                clearInterval(authCheckInterval.current);
              authCheckInterval.current = null;
              setIsLoading(true); // Show loader while data loads
              await loadAppData();
            } else {
              console.log("Still not authenticated...");
            }
          } catch (pollErr) {
            console.error("Error polling auth status:", pollErr);
            // Optionally stop polling after too many errors
          }
        }, 3000); // Check every 3 seconds
      } else {
        // Different initialization error
        console.error("Failed to initialize app (non-auth error):", err);
        setError(
          err instanceof Error
            ? err.message
            : "An error occurred during initialization",
        );
        setIsLoading(false);
      }
    }
    // Don't set isLoading false here if polling started
  };

  // Ensure interval is cleared on unmount
  useEffect(() => {
    return () => {
      if (authCheckInterval.current) {
        clearInterval(authCheckInterval.current);
      }
    };
  }, []);

  const loadSavedTracks = async (page: number) => {
    try {
      console.log("Loading saved tracks for page:", page);
      setIsLoading(true);
      setError(null);
      const offset = (page - 1) * ITEMS_PER_PAGE;
      const tracks = await GetSavedTracks(ITEMS_PER_PAGE, offset);

      if (tracks) {
        console.log("Loaded", tracks.items?.length || 0, "tracks");
        setSavedTracks(tracks);
        setTotalTracks(tracks.total || 0);
        setCurrentPage(page);
      } else {
        console.error("Tracks response is null");
        setError("Failed to load saved tracks");
      }
    } catch (err) {
      console.error("Failed to load saved tracks:", err);
      setError("Failed to load saved tracks");
    } finally {
      setIsLoading(false);
    }
  };

  const handleSearch = async (query: string) => {
    if (!query.trim()) {
      setSearchResults([]);
      return;
    }

    try {
      setIsLoading(true);
      setError(null);
      const results = await SearchTracks(query, 10);
      setSearchResults(results || []);
    } catch (err) {
      console.error("Failed to search tracks:", err);
      setError("Failed to search tracks");
    } finally {
      setIsLoading(false);
    }
  };

  const handlePlay = async (
    track: spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo,
  ) => {
    console.log("[handlePlay] Called for track:", track?.name);

    const info = getTrackInfo(track);
    console.log("[handlePlay] Track info:", info);

    // Check if we're trying to pause the current track
    if (nowPlayingTrack?.id === track.id && !isPlaybackPaused) {
      console.log("[handlePlay] Pausing current track");
      if (!isUsingPreview && spotifyPlayer) {
        try {
          await PausePlaybackOnDevice(spotifyDeviceId!);
          setIsPlaybackPaused(true);
        } catch (err) {
          console.error("[handlePlay] Failed to pause Spotify playback:", err);
        }
      } else {
        audioElement.pause();
        setIsPlaybackPaused(true);
      }
      return;
    }

    // If we have a Spotify player and device ID, try full song playback
    if (spotifyPlayer && spotifyDeviceId) {
      try {
        console.log("[handlePlay] Attempting full song playback");
        // For suggested tracks, we need to construct the URI
        const trackUri =
          "uri" in track ? track.uri : `spotify:track:${track.id}`;

        console.log("[handlePlay] Using track URI:", trackUri);
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
    if (info.previewUrl) {
      console.log("[handlePlay] Using preview URL playback");
      try {
        audioElement.src = info.previewUrl;
        await audioElement.play();
        setNowPlayingTrack(track);
        setIsPlaybackPaused(false);
        setIsUsingPreview(true);
      } catch (err) {
        console.error("[handlePlay] Preview playback failed:", err);
        setError("Failed to play track. Please try again.");
      }
    } else {
      console.log("[handlePlay] No preview URL available");
      setError("No preview available for this track.");
    }
  };

  const handleSave = async (trackId: string) => {
    try {
      setError(null);
      await SaveTrack(trackId);
      setCurrentPage(1); // Reset to first page
      loadSavedTracks(1); // Always load first page after adding
    } catch (err) {
      console.error("Failed to save track:", err);
      setError("Failed to save track");
    }
  };

  const handleRemove = async (trackId: string) => {
    try {
      setError(null);
      await RemoveTrack(trackId);
      loadSavedTracks(currentPage);
    } catch (err) {
      console.error("Failed to remove track:", err);
      setError("Failed to remove track");
    }
  };

  const getTrackInfo = (track: spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo | null) => {
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
    if ('artists' in track && Array.isArray(track.artists) && 'album' in track && track.album && 'images' in track.album) {
      return {
        name: track.name,
        artist: track.artists[0]?.name || "Unknown Artist",
        album: track.album.name,
        albumArtUrl: track.album.images[0]?.url || "",
        previewUrl: track.preview_url || null,
      };
    }

    // Handle SimpleTrack type
    if ('artist' in track && typeof track.artist === 'string' && 'albumArtUrl' in track) {
      return {
        name: track.name,
        artist: track.artist,
        album: track.album || "",
        albumArtUrl: track.albumArtUrl || "",
        previewUrl: track.previewUrl || null,
      };
    }

    // Handle SuggestedTrackInfo type
    if ('artist' in track && typeof track.artist === 'string') {
      return {
        name: track.name,
        artist: track.artist,
        album: "",
        albumArtUrl: 'albumArtUrl' in track ? track.albumArtUrl || "" : "",
        previewUrl: 'previewUrl' in track ? track.previewUrl || null : null,
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
  };

  const TrackCard = ({
    track,
    isSaved = false,
  }: {
    track: spotify.Track | spotify.SimpleTrack;
    isSaved?: boolean;
  }) => {
    const info = getTrackInfo(track);
    const isPlayingThis = !isPlaybackPaused && nowPlayingTrack?.id === track.id;
    const hasUri = "uri" in track && track.uri;
    const canPlay = hasUri || info.previewUrl;

    console.log(`[TrackCard] Track "${track.name}" playability:`, {
      hasUri,
      hasPreview: !!info.previewUrl,
      canPlay,
    });

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
            className={`play-button ${isPlayingThis ? "playing" : ""} ${!canPlay ? "no-preview" : ""}`}
            onClick={() => {
              console.log("[Play] Button clicked for track:", track.name);
              console.log("[Play] Playability:", {
                hasUri,
                hasPreview: !!info.previewUrl,
              });
              handlePlay(track);
            }}
            disabled={!canPlay}
            title={
              !canPlay
                ? "Playback unavailable"
                : hasUri
                  ? "Play full song"
                  : "Play preview"
            }
          >
            {isPlayingThis ? <FaPause /> : <FaPlay />}
            {!canPlay && <span className="no-preview-icon">🚫</span>}
          </button>
          {isSaved ? (
            <button
              className="remove-button"
              onClick={() => handleRemove(track.id)}
            >
              Remove
            </button>
          ) : (
            <button
              className="save-button"
              onClick={() => handleSave(track.id)}
            >
              Save
            </button>
          )}
        </div>
      </div>
    );
  };

  const LoadingSkeleton = () => (
    <div className="track-grid">
      {[...Array(8)].map((_, i) => (
        <div key={i} className="track-card">
          <div className="skeleton skeleton-card" />
          <div className="skeleton skeleton-text" />
          <div className="skeleton skeleton-text" />
          <div className="skeleton skeleton-text" />
        </div>
      ))}
    </div>
  );

  // Add effect to handle page changes
  useEffect(() => {
    if (isAuthenticated) {
      loadSavedTracks(currentPage);
    }
  }, [currentPage, isAuthenticated]);

  const handleNextPage = () => {
    if (currentPage * ITEMS_PER_PAGE < totalTracks) {
      console.log("Moving to next page:", currentPage + 1);
      setCurrentPage((prev) => prev + 1);
    }
  };

  const handlePrevPage = () => {
    if (currentPage > 1) {
      console.log("Moving to previous page:", currentPage - 1);
      setCurrentPage((prev) => prev - 1);
    }
  };

  // Handler for providing feedback (Like/Dislike)
  const handleSuggestionFeedback = async (feedbackType: "like" | "dislike") => {
    if (!suggestedTrack) return;

    try {
      const outcome =
        feedbackType === "like"
          ? session.Outcome.liked
          : session.Outcome.disliked;
      await ProvideSuggestionFeedback(
        outcome,
        suggestedTrack.name,
        suggestedTrack.artist,
        suggestedTrack.album || "",
      );
      // Only show toast after successful API call
      setToast({
        message:
          feedbackType === "like"
            ? "Feedback recorded: liked the suggestion"
            : "Feedback recorded: did not like the suggestion",
        type: feedbackType === "like" ? "success" : "dislike",
      });
      // Set the liked state if the user liked the suggestion
      if (feedbackType === "like") {
        setHasLikedCurrentSuggestion(true);
      }
      // Keep the suggestion visible, let user decide when to dismiss
      if (feedbackType === "dislike") {
        setSuggestedTrack(null); // Only clear if disliked
      }
    } catch (err) {
      console.error("Failed to send feedback:", err);
      setToast({
        message: `Failed to send ${feedbackType} feedback`,
        type: "error",
      });
    }
  };

  // Handler for adding the suggested track to the library
  const handleAddToLibrary = async () => {
    if (!suggestedTrack) return;
    try {
      console.log(`Adding suggested track to library: ${suggestedTrack.id}`);
      await SaveTrack(suggestedTrack.id);
      await ProvideSuggestionFeedback(
        session.Outcome.added,
        suggestedTrack.name,
        suggestedTrack.artist,
        suggestedTrack.album || "",
      );
      setToast({
        message: "Added to your library! 🎵",
        type: "success",
      });
    } catch (err) {
      console.error("Failed to add suggested track or send feedback:", err);
      setToast({
        message: `Failed to add ${suggestedTrack.name} to library`,
        type: "error",
      });
    }
  };

  // Add effect to sync playback state with Spotify
  useEffect(() => {
    if (spotifyPlayer) {
      spotifyPlayer.addListener("player_state_changed", (state: any) => {
        console.log("[Spotify] Player state changed:", state);
        if (state === null) {
          setIsPlaybackPaused(true);
        } else {
          setIsPlaybackPaused(state.paused);
        }
      });
    }
  }, [spotifyPlayer]);

  // Update handleRequestSuggestion to better handle errors
  const handleRequestSuggestion = async () => {
    console.log("Starting new suggestion request...");

    // Record feedback for the current suggestion before requesting a new one
    if (suggestedTrack) {
      try {
        let feedbackText;
        if (hasLikedCurrentSuggestion) {
          feedbackText = `I liked the suggestion: ${suggestedTrack.name} by ${suggestedTrack.artist}`;
          await ProvideSuggestionFeedback(
            session.Outcome.liked,
            suggestedTrack.name,
            suggestedTrack.artist,
            suggestedTrack.album || "",
          );
        } else {
          feedbackText = `I skipped the suggestion: ${suggestedTrack.name} by ${suggestedTrack.artist}`;
          await ProvideSuggestionFeedback(
            session.Outcome.skipped,
            suggestedTrack.name,
            suggestedTrack.artist,
            suggestedTrack.album || "",
          );
          // Only show toast for skipped suggestions
          setToast({
            message: "Feedback recorded: skipped the suggestion",
            type: "skip",
          });
        }
        console.log("Recording feedback for current suggestion:", feedbackText);
      } catch (err) {
        console.error("Failed to record feedback:", err);
        // Continue with new suggestion request even if feedback recording fails
      }
    }

    setSuggestionError(null);
    setIsProcessingLibrary(true);
    setSuggestedTrack(null);
    setSuggestionContext(null);
    setHasLikedCurrentSuggestion(false);
    try {
      console.log("Requesting new suggestion...");
      const suggestion = await RequestNewSuggestion();
      console.log("Raw suggestion response:", suggestion);

      if (!suggestion) {
        console.error("Received null response");
        setSuggestionError("Failed to get suggestion.");
        return;
      }

      if (suggestion && suggestion.id) {
        console.log("Valid suggestion received:", {
          id: suggestion.id,
          name: suggestion.name,
          artist: suggestion.artist,
          originalQuery:
            "originalQuery" in suggestion
              ? suggestion.originalQuery
              : undefined,
        });
        setSuggestedTrack(suggestion);
        const context =
          "originalQuery" in suggestion &&
          typeof suggestion.originalQuery === "string"
            ? suggestion.originalQuery
            : `${suggestion.name} by ${suggestion.artist}`;
        console.log("Setting suggestion context:", context);
        setSuggestionContext(context);
      } else {
        console.error("Invalid suggestion format:", suggestion);
        setSuggestionError("Received invalid suggestion from backend.");
      }
    } catch (err) {
      handleSuggestionError(err);
    } finally {
      setIsProcessingLibrary(false);
    }
  };

  // Handler for skipping a suggestion
  const handleSkipSuggestion = async () => {
    if (!suggestedTrack) return;
    try {
      console.log(`Skipping suggestion: ${suggestedTrack.name}`);
      await ProvideSuggestionFeedback(
        session.Outcome.disliked,
        suggestedTrack.name,
        suggestedTrack.artist,
        "", // No album needed
      );
      setToast({
        message: "Skipped suggestion",
        type: "skip",
      });
      await handleRequestSuggestion();
    } catch (err) {
      console.error("Error skipping suggestion:", err);
      setToast({
        message: "Failed to skip suggestion",
        type: "error",
      });
    }
  };

  const handleClearCreds = async () => {
    console.log("Attempting to clear Spotify credentials...");
    try {
      await ClearSpotifyCredentials();
      console.log("Credentials cleared successfully.");

      // Reset all application state
      setUser(null);
      setSavedTracks(null);
      setSearchResults([]);
      setNowPlayingTrack(null);
      setSuggestedTrack(null);
      setIsAuthenticated(false);
      setShowSuggestionSection(false);

      // Clear any playing audio
      audioElement.pause();
      if (spotifyPlayer) {
        spotifyPlayer.disconnect();
      }

      // Show success message
      setToast({
        message:
          "Spotify credentials cleared. Please wait for re-authentication...",
        type: "success",
      });

      // Start polling for new auth
      if (authCheckInterval.current) clearInterval(authCheckInterval.current);
      authCheckInterval.current = setInterval(async () => {
        console.log("Polling GetAuthStatus after credentials clear...");
        try {
          const status = await GetAuthStatus();
          if (status.isAuthenticated) {
            console.log("Re-authenticated! Loading data...");
            if (authCheckInterval.current)
              clearInterval(authCheckInterval.current);
            authCheckInterval.current = null;
            setIsLoading(true);
            await loadAppData();
          }
        } catch (pollErr) {
          console.error("Error polling auth status:", pollErr);
        }
      }, 3000);
    } catch (err) {
      console.error("Failed to clear credentials:", err);
      setToast({
        message:
          err instanceof Error
            ? `Error clearing credentials: ${err.message}`
            : "Failed to clear credentials",
        type: "error",
      });
    }
  };

  // --- Now Playing Bar ---
  const {
    name: nowPlayingName,
    artist: nowPlayingArtist,
    albumArtUrl: nowPlayingAlbumArt,
  } = getTrackInfo(nowPlayingTrack);

  const handleNowPlayingClick = () => {
    // Check if there's a track currently set as now playing
    if (nowPlayingTrack) {
      handlePlay(nowPlayingTrack);
    } else {
      console.warn(
        "Play/Pause clicked but no track is set as 'nowPlayingTrack'.",
      );
    }
  };

  useEffect(() => {
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

  // Add toast timeout cleanup
  useEffect(() => {
    if (toast) {
      const timer = setTimeout(() => {
        setToast(null);
      }, 3000);
      return () => clearTimeout(timer);
    }
  }, [toast]);

  return (
    <div id="App">
      {toast && <div className={`toast ${toast.type}`}>{toast.message}</div>}
      <div className="top-section">
        <div className="top-section-content">
          <header>
            <div className="user-controls">
              {user && (
                <div className="user-info">
                  {user.images?.[0]?.url && (
                    <img
                      src={user.images[0].url}
                      alt={user.display_name}
                      className="user-avatar"
                    />
                  )}
                  <span className="user-name">
                    Connected as {user.display_name}
                  </span>
                </div>
              )}
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  console.log("Clear auth button clicked");
                  alert("Clear auth clicked");
                  handleClearCreds();
                }}
                className="clear-auth-button"
              >
                Clear Spotify Auth
              </button>
            </div>
            <h1 className="app-title">Spotify Library</h1>
          </header>
          <div className="search-section">
            <span className="search-icon">🔍</span>
            <input
              type="text"
              placeholder="Search tracks..."
              value={searchQuery}
              onChange={(e) => {
                setSearchQuery(e.target.value);
                handleSearch(e.target.value);
              }}
              className="search-input"
            />
          </div>
        </div>
      </div>
      <div className="main-content">
        {error && (
          <div className="error-message">
            <span>⚠️</span>
            {error}
          </div>
        )}

        {/* --- Suggestion Section --- */}
        {showSuggestionSection && (
          <div className="suggestion-section">
            <h2>Song Suggestion</h2>
            {isProcessingLibrary ? (
              <div className="loading-indicator">
                Asking the AI for a suggestion...
              </div>
            ) : suggestionError ? (
              <div className="suggestion-error-state">
                <div className="error-message">{suggestionError}</div>
                <button onClick={handleRequestSuggestion}>
                  Try another suggestion
                </button>
              </div>
            ) : suggestedTrack ? (
              <div className="suggested-track-display">
                <div className="suggestion-art-and-info">
                  {suggestedTrack.albumArtUrl && (
                    <img
                      src={suggestedTrack.albumArtUrl}
                      alt="Suggested album art"
                      className="suggested-album-art"
                    />
                  )}
                  <div className="suggestion-info">
                    <h4>{suggestedTrack.name}</h4>
                    <p>{suggestedTrack.artist}</p>
                    {suggestionContext &&
                      suggestionContext !==
                        `${suggestedTrack.name} by ${suggestedTrack.artist}` && (
                        <p className="suggestion-context">
                          Based on AI suggestion: "{suggestionContext}"
                        </p>
                      )}
                  </div>
                  <div className="suggestion-controls">
                    <button
                      className={`play-button ${!isPlaybackPaused && nowPlayingTrack?.id === suggestedTrack.id ? "playing" : ""}`}
                      onClick={() => {
                        console.log(
                          "[Suggestion] Play button clicked for track:",
                          suggestedTrack.name,
                        );
                        console.log("[Suggestion] Current state:", {
                          isPlaybackPaused,
                          nowPlayingId: nowPlayingTrack?.id,
                          suggestedId: suggestedTrack.id,
                        });
                        handlePlay(suggestedTrack);
                      }}
                    >
                      {!isPlaybackPaused &&
                      nowPlayingTrack?.id === suggestedTrack.id ? (
                        <FaPause />
                      ) : (
                        <FaPlay />
                      )}
                    </button>
                    {/* Feedback Buttons */}
                    <button
                      onClick={() => handleSuggestionFeedback("like")}
                      className="feedback-button like-button"
                    >
                      <FaThumbsUp /> Like
                    </button>
                    <button
                      onClick={() => handleSuggestionFeedback("dislike")}
                      className="feedback-button dislike-button"
                    >
                      <FaThumbsDown /> Dislike
                    </button>
                    {/* Action Buttons */}
                    <button
                      onClick={handleAddToLibrary}
                      className="action-button add-button"
                    >
                      <FaPlus /> Add to Library
                    </button>
                    <button
                      onClick={handleRequestSuggestion}
                      className="action-button next-button"
                    >
                      Next Suggestion <FaStepForward />
                    </button>
                  </div>
                </div>
                {/* End of suggestion-art-and-info wrapper */}
              </div>
            ) : (
              // Initial state or after successful feedback/add
              <button onClick={handleRequestSuggestion}>Suggest a song</button>
            )}
          </div>
        )}
        {/* --- End Suggestion Section --- */}

        {isLoading && !searchQuery ? (
          <LoadingSkeleton />
        ) : (
          <>
            {searchQuery ? (
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
                          (t) => t.track?.id === track.id,
                        )}
                      />
                    ))}
                  </div>
                )}
              </div>
            ) : (
              <div className="saved-tracks">
                <div className="saved-tracks-header">
                  <h2>Your Library</h2>
                  <button
                    className="collapse-button"
                    onClick={() =>
                      setIsFavoritesCollapsed(!isFavoritesCollapsed)
                    }
                  >
                    {isFavoritesCollapsed ? "▼" : "▲"}
                  </button>
                </div>
                {!isFavoritesCollapsed && (
                  <>
                    {!savedTracks?.items || savedTracks.items.length === 0 ? (
                      <div className="no-results">
                        No saved tracks yet. Search for tracks to add them to
                        your library.
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
                                />
                              ),
                          )}
                        </div>
                        <div className="pagination">
                          <button
                            onClick={handlePrevPage}
                            disabled={currentPage === 1}
                          >
                            Previous
                          </button>
                          <span>
                            Page {currentPage} of{" "}
                            {Math.ceil(totalTracks / ITEMS_PER_PAGE)}
                          </span>
                          <button
                            onClick={handleNextPage}
                            disabled={
                              currentPage * ITEMS_PER_PAGE >= totalTracks
                            }
                          >
                            Next
                          </button>
                        </div>
                      </>
                    )}
                  </>
                )}
              </div>
            )}
          </>
        )}
      </div>

      {/* Ensure Now Playing bar uses getTrackInfo correctly */}
      {nowPlayingTrack && (
        <div className="now-playing">
          {(() => {
            const info = getTrackInfo(nowPlayingTrack);
            return (
              <>
                <img
                  src={info.albumArtUrl}
                  alt={info.name}
                  className="now-playing-art"
                />
                <div className="now-playing-details">
                  <p>
                    <strong>{info.name}</strong>
                  </p>
                  <p>{info.artist}</p>
                  <p className="playback-type">
                    {isUsingPreview ? "(Preview)" : "(Full Song)"}
                  </p>
                </div>
                <button
                  className={`play-pause-button ${isPlaybackPaused ? "" : "playing"}`}
                  onClick={() => {
                    console.log(
                      "[NowPlaying] Play/Pause clicked, current state:",
                      {
                        isPlaybackPaused,
                        trackId: nowPlayingTrack?.id,
                      },
                    );
                    if (nowPlayingTrack) {
                      handlePlay(nowPlayingTrack);
                    }
                  }}
                >
                  {isPlaybackPaused ? <FaPlay /> : <FaPause />}
                </button>
              </>
            );
          })()}
        </div>
      )}
    </div>
  );
}

export default App;
