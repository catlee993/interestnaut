import { useState, useRef, useEffect, useCallback } from "react";
import { spotify } from "@wailsjs/go/models";
import {
  GetSavedTracks,
  SaveTrack,
  RemoveTrack,
  SearchTracks,
} from "../../wailsjs/go/bindings/Music";
import { useSnackbar } from "notistack";

export function useTracks(itemsPerPage: number = 20) {
  const { enqueueSnackbar } = useSnackbar();
  const [savedTracks, setSavedTracks] = useState<spotify.SavedTracks | null>(
    null,
  );
  const [searchResults, setSearchResults] = useState<spotify.SimpleTrack[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [totalTracks, setTotalTracks] = useState(0);
  const loadingTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Add minimum loading time to prevent flashing
  const setLoadingWithMinTime = (loading: boolean) => {
    if (loading) {
      setIsLoading(true);
      if (loadingTimeoutRef.current) {
        clearTimeout(loadingTimeoutRef.current);
      }
    } else {
      // Ensure loading state shows for at least 500ms
      loadingTimeoutRef.current = setTimeout(() => {
        setIsLoading(false);
      }, 500);
    }
  };

  const loadSavedTracks = useCallback(
    async (page: number) => {
      try {
        console.log("Loading saved tracks for page:", page);
        setLoadingWithMinTime(true);
        setError(null);
        const offset = (page - 1) * itemsPerPage;
        const tracks = await GetSavedTracks(itemsPerPage, offset);

        if (tracks) {
          console.log("Loaded", tracks.items?.length || 0, "tracks");
          setSavedTracks(spotify.SavedTracks.createFrom(tracks));
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
        setLoadingWithMinTime(false);
      }
    },
    [itemsPerPage],
  );

  // Clean up timeout on unmount
  useEffect(() => {
    const handleRefresh = () => {
      loadSavedTracks(currentPage);
    };

    window.addEventListener("refreshSavedTracks", handleRefresh);

    return () => {
      if (loadingTimeoutRef.current) {
        clearTimeout(loadingTimeoutRef.current);
      }
      window.removeEventListener("refreshSavedTracks", handleRefresh);
    };
  }, [currentPage, loadSavedTracks]);

  const handleSearch = useCallback(
    async (query: string) => {
      if (!query.trim()) {
        setSearchResults([]);
        return;
      }

      try {
        setIsLoading(true);
        setError(null);
        const results = await SearchTracks(query, itemsPerPage);
        setSearchResults(
          results.map((track) => spotify.SimpleTrack.createFrom(track)),
        );
      } catch (err) {
        console.error("Failed to search tracks:", err);
        setError("Failed to search tracks");
      } finally {
        setIsLoading(false);
      }
    },
    [itemsPerPage],
  );

  const handleSave = useCallback(
    async (track: spotify.SimpleTrack) => {
      try {
        setIsLoading(true);
        await SaveTrack(track.id);

        if (savedTracks) {
          const newTrack = spotify.Track.createFrom({
            id: track.id,
            name: track.name,
            artists: [{ name: track.artist }],
            album: { name: track.album, images: [{ url: track.albumArtUrl }] },
            preview_url: track.previewUrl,
            uri: track.uri,
          });
          const newItem = spotify.SavedTrackItem.createFrom({
            track: newTrack,
            added_at: new Date().toISOString(),
          });

          // Update state in a single operation
          setSavedTracks((prev) => {
            if (!prev) return null;
            return spotify.SavedTracks.createFrom({
              ...prev,
              items: [...prev.items, newItem],
              total: prev.total + 1,
            });
          });
        }
        enqueueSnackbar("Track saved to library", { variant: "success" });
      } catch (error) {
        console.error("Error saving track:", error);
        enqueueSnackbar("Error saving track", { variant: "error" });
      } finally {
        setIsLoading(false);
      }
    },
    [savedTracks],
  );

  const handleRemove = useCallback(
    async (track: spotify.SimpleTrack) => {
      try {
        await RemoveTrack(track.id);
        if (savedTracks) {
          setSavedTracks(
            spotify.SavedTracks.createFrom({
              ...savedTracks,
              items: savedTracks.items.filter(
                (item) => item.track?.id !== track.id,
              ),
              total: savedTracks.total - 1,
            }),
          );
        }
        enqueueSnackbar("Track removed from library", { variant: "success" });
      } catch (error) {
        console.error("Error removing track:", error);
        enqueueSnackbar("Error removing track", { variant: "error" });
      }
    },
    [savedTracks],
  );

  const handleNextPage = () => {
    if (currentPage * itemsPerPage < totalTracks) {
      console.log("Moving to next page:", currentPage + 1);
      loadSavedTracks(currentPage + 1);
    }
  };

  const handlePrevPage = () => {
    if (currentPage > 1) {
      console.log("Moving to previous page:", currentPage - 1);
      loadSavedTracks(currentPage - 1);
    }
  };

  return {
    savedTracks,
    searchResults,
    isLoading,
    error,
    currentPage,
    totalTracks,
    loadSavedTracks,
    handleSearch,
    handleSave,
    handleRemove,
    handleNextPage,
    handlePrevPage,
  };
}
