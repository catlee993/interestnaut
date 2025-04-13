import { useState, useRef, useEffect } from "react";
import { spotify } from "../../wailsjs/go/models";
import { GetSavedTracks, SaveTrack, RemoveTrack, SearchTracks } from "../../wailsjs/go/bindings/Music";
import { useToast } from "./useToast";

export function useTracks(itemsPerPage: number = 20) {
  const [savedTracks, setSavedTracks] = useState<spotify.SavedTracks | null>(null);
  const [searchResults, setSearchResults] = useState<spotify.SimpleTrack[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [totalTracks, setTotalTracks] = useState(0);
  const { showToast } = useToast();
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

  const loadSavedTracks = async (page: number) => {
    try {
      console.log("Loading saved tracks for page:", page);
      setLoadingWithMinTime(true);
      setError(null);
      const offset = (page - 1) * itemsPerPage;
      const tracks = await GetSavedTracks(itemsPerPage, offset);

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
      setLoadingWithMinTime(false);
    }
  };

  // Clean up timeout on unmount
  useEffect(() => {
    return () => {
      if (loadingTimeoutRef.current) {
        clearTimeout(loadingTimeoutRef.current);
      }
    };
  }, []);

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

  const handleNextPage = () => {
    if (currentPage * itemsPerPage < totalTracks) {
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

  return {
    savedTracks,
    setSavedTracks,
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
    handlePrevPage
  };
} 