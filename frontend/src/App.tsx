import { useState, useEffect, useRef } from 'react';
import './App.css';
import {
    GetSavedTracks,
    SearchTracks,
    SaveTrack,
    RemoveTrack,
    GetCurrentUser,
    GetInitialSuggestionState,
    ProcessLibraryAndGetFirstSuggestion,
    RequestNewSuggestion,
    ProvideSuggestionFeedback
} from "../wailsjs/go/spotify/WailsClient";
import { spotify } from "../wailsjs/go/models";

function App() {
    const [savedTracks, setSavedTracks] = useState<spotify.SavedTracks | null>(null);
    const [searchResults, setSearchResults] = useState<spotify.SimpleTrack[]>([]);
    const [searchQuery, setSearchQuery] = useState<string>("");
    const [user, setUser] = useState<spotify.UserProfile | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [isLoading, setIsLoading] = useState<boolean>(true);
    const [currentPage, setCurrentPage] = useState<number>(1);
    const [totalTracks, setTotalTracks] = useState<number>(0);
    const [currentlyPlaying, setCurrentlyPlaying] = useState<string | null>(null);
    const [nowPlayingTrack, setNowPlayingTrack] = useState<spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo | null>(null);
    const [isFavoritesCollapsed, setIsFavoritesCollapsed] = useState<boolean>(false);

    const [isProcessingLibrary, setIsProcessingLibrary] = useState<boolean>(false);
    const [suggestionError, setSuggestionError] = useState<string | null>(null);
    const [suggestedTrack, setSuggestedTrack] = useState<spotify.SuggestedTrackInfo | null>(null);
    const [showSuggestionSection, setShowSuggestionSection] = useState<boolean>(false);

    const ITEMS_PER_PAGE = 20;

    const hasInitialized = useRef<boolean>(false);

    useEffect(() => {
        if (!hasInitialized.current) {
            hasInitialized.current = true;
            initializeApp();
        }
    }, []);

    const initializeApp = async () => {
        console.log('initializeApp called...');

        try {
            console.log('Starting core initialization...');
            setIsLoading(true);
            setError(null);
            setSuggestionError(null);

            const currentUser = await GetCurrentUser();
            if (currentUser) {
                setUser(currentUser);
                await loadSavedTracks(1);

                console.log('Checking initial suggestion state...');
                const needsProcessing = await GetInitialSuggestionState();
                console.log('Needs processing:', needsProcessing);

                if (needsProcessing) {
                    console.log('Starting initial library processing...');
                    setIsProcessingLibrary(true);
                    setShowSuggestionSection(true); 
                    try {
                        const firstSuggestion = await ProcessLibraryAndGetFirstSuggestion();
                        console.log('First suggestion received:', firstSuggestion);
                        if (firstSuggestion && firstSuggestion.id) {
                            setSuggestedTrack(firstSuggestion);
                        } else {
                            console.error('Invalid suggestion format or missing ID:', firstSuggestion);
                            setSuggestionError('Received invalid suggestion from backend.');
                        }
                    } catch (processErr) {
                        console.error('Failed during initial processing:', processErr);
                        const errorMsg = processErr instanceof Error ? processErr.message : 'Failed to get initial suggestion.';
                        setSuggestionError(`Suggestion failed: ${errorMsg}`); 
                        setSuggestedTrack(null); 
                    } finally {
                        setIsProcessingLibrary(false);
                    }
                } else {
                    setShowSuggestionSection(true);
                }
            }
        } catch (err) { 
            console.error('Failed to initialize app:', err);
            setError(err instanceof Error ? err.message : 'An error occurred during initialization');
        } finally {
            setIsLoading(false);
            console.log('Core initialization finished.');
        }
    };

    const loadSavedTracks = async (page: number) => {
        try {
            console.log('Loading saved tracks for page:', page);
            setIsLoading(true);
            setError(null);
            const offset = (page - 1) * ITEMS_PER_PAGE;
            const response = await GetSavedTracks(ITEMS_PER_PAGE, offset);
            
            if (response) {
                console.log('Loaded', response.items?.length || 0, 'tracks');
                setSavedTracks(response);
                setTotalTracks(response.total || 0);
                setCurrentPage(page);
            } else {
                console.error('Tracks response is null');
                setError('Failed to load saved tracks');
            }
        } catch (err) {
            console.error('Failed to load saved tracks:', err);
            setError('Failed to load saved tracks');
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
            const results = await SearchTracks(query, 20);
            setSearchResults(results || []);
        } catch (err) {
            console.error('Failed to search tracks:', err);
            setError('Failed to search tracks');
        } finally {
            setIsLoading(false);
        }
    };

    const handlePlay = (track: spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo, previewUrl: string | null) => {
        if (previewUrl) {
            if (currentlyPlaying === previewUrl) {
                setCurrentlyPlaying(null);
                setNowPlayingTrack(null);
            } else {
                setCurrentlyPlaying(previewUrl);
                setNowPlayingTrack(track);
            }
        }
    };

    const handleSave = async (trackId: string) => {
        try {
            setError(null);
            await SaveTrack(trackId);
            loadSavedTracks(currentPage);
        } catch (err) {
            console.error('Failed to save track:', err);
            setError('Failed to save track');
        }
    };

    const handleRemove = async (trackId: string) => {
        try {
            setError(null);
            await RemoveTrack(trackId);
            loadSavedTracks(currentPage);
        } catch (err) {
            console.error('Failed to remove track:', err);
            setError('Failed to remove track');
        }
    };

    const getTrackInfo = (track: spotify.Track | spotify.SimpleTrack | spotify.SuggestedTrackInfo | null): 
        { name: string; artist: string; album: string; albumArtUrl: string; previewUrl: string | null } => 
    {
        if (!track) {
             return {
                name: 'No Track',
                artist: '',
                album: '',
                albumArtUrl: '',
                previewUrl: null,
            };
        }
        
        // Check for Full Track (has artists array and album object)
        if ('artists' in track && Array.isArray(track.artists) && 'album' in track && typeof track.album === 'object' && track.album !== null && 'images' in track.album) {
            return {
                name: track.name,
                artist: track.artists[0]?.name || '',
                album: track.album.name,
                albumArtUrl: track.album.images[0]?.url || '',
                previewUrl: track.preview_url || null, // Ensure null if missing
            };
        }
        
        // Check for Simple Track (has artist string and album string)
        // Note: SimpleTrack mapping in client.go puts album name in track.album
        if ('artist' in track && typeof track.artist === 'string' && 'album' in track && typeof track.album === 'string' && 'albumArtUrl' in track) {
             return {
                name: track.name,
                artist: track.artist, 
                album: track.album, 
                albumArtUrl: track.albumArtUrl || '', // Ensure string
                previewUrl: track.previewUrl || null, // Ensure null if missing
            };
        }

        // Check for Suggested Track Info (has artist string, no album field)
        if ('artist' in track && typeof track.artist === 'string' && !('album' in track) && 'albumArtUrl' in track) {
             return {
                name: track.name,
                artist: track.artist,
                album: '', // No album info for suggestions
                albumArtUrl: track.albumArtUrl || '', // Ensure string
                previewUrl: track.previewUrl || null, // Ensure null if missing
            };
        }
        
        // Fallback for unknown type
        console.warn("Unknown track type passed to getTrackInfo:", track);
        return {
            name: track.name || 'Unknown Track', // Try to get name at least
            artist: ('artist' in track && typeof track.artist === 'string') ? track.artist : 'Unknown Artist', // Try basic artist
            album: '',
            albumArtUrl: ('albumArtUrl' in track && typeof track.albumArtUrl === 'string') ? track.albumArtUrl : '', // Try basic art
            previewUrl: ('previewUrl' in track && typeof track.previewUrl === 'string') ? track.previewUrl : null, // Try basic preview
        };
    };

    const TrackCard = ({ track, isSaved = false }: { track: spotify.Track | spotify.SimpleTrack, isSaved?: boolean }) => {
        const info = getTrackInfo(track);
        const previewUrl = info.previewUrl;
        return (
            <div className="track-card">
                {info.albumArtUrl && (
                    <img src={info.albumArtUrl} alt={info.album} className="album-art" />
                )}
                <div className="track-info">
                    <h3>{info.name}</h3>
                    <p>{info.artist}</p>
                    <p className="album-name">{info.album}</p>
                </div>
                <div className="track-controls">
                    {previewUrl && (
                        <button
                            className={`play-button ${currentlyPlaying === previewUrl ? 'playing' : ''}`}
                            onClick={() => handlePlay(track, previewUrl)}
                        >
                            {currentlyPlaying === previewUrl ? '⏸' : '▶'}
                        </button>
                    )}
                    {isSaved ? (
                        <button className="remove-button" onClick={() => handleRemove(track.id)}>
                            Remove
                        </button>
                    ) : (
                        <button className="save-button" onClick={() => handleSave(track.id)}>
                            Save
                        </button>
                    )}
                </div>
                {currentlyPlaying === previewUrl && (
                    <audio
                        src={previewUrl || ''}
                        autoPlay
                        onEnded={() => {
                            setCurrentlyPlaying(null);
                            setNowPlayingTrack(null);
                        }}
                    />
                )}
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

    const handleNextPage = () => {
        if (currentPage * ITEMS_PER_PAGE < totalTracks) {
            setCurrentPage(prev => prev + 1);
        }
    };

    const handlePrevPage = () => {
        if (currentPage > 1) {
            setCurrentPage(prev => prev - 1);
        }
    };

    // Handler for providing feedback (Like/Dislike)
    const handleSuggestionFeedback = async (feedbackType: 'like' | 'dislike') => {
        if (!suggestedTrack) return;

        const feedbackText = feedbackType === 'like'
            ? `I liked the suggestion: ${suggestedTrack.name} by ${suggestedTrack.artist}.`
            : `I disliked the suggestion: ${suggestedTrack.name} by ${suggestedTrack.artist}.`;
        
        try {
            console.log(`Sending feedback (${feedbackType}):`, feedbackText);
            await ProvideSuggestionFeedback(feedbackText);
            // Optionally clear the suggestion or request a new one after feedback
            // For now, just leave the current suggestion displayed
        } catch (err) {
            console.error('Failed to send feedback:', err);
            // Show a temporary error to the user?
            setSuggestionError(`Failed to send ${feedbackType} feedback.`); 
            // Clear error after a delay?
            setTimeout(() => setSuggestionError(null), 3000);
        }
    };

    // Handler for adding the suggested track to the library
    const handleAddSuggestionToLibrary = async () => {
        if (!suggestedTrack) return;

        try {
            console.log(`Adding suggested track to library: ${suggestedTrack.id}`);
            await SaveTrack(suggestedTrack.id);
            // Also send strong positive feedback
            const feedbackText = `I liked the suggestion ${suggestedTrack.name} by ${suggestedTrack.artist} so much I added it to my library!`;
            await ProvideSuggestionFeedback(feedbackText);
            // Refresh saved tracks view if needed (might automatically update if pagination logic is robust)
            // loadSavedTracks(currentPage); 
            
            // Optionally clear suggestion or request a new one?
            setSuggestedTrack(null); // Clear suggestion after adding
            // handleRequestSuggestion(); // Or immediately request next?
        } catch (err) {
            console.error('Failed to add suggested track or send feedback:', err);
            setSuggestionError(`Failed to add track ${suggestedTrack.name}.`);
            setTimeout(() => setSuggestionError(null), 3000);
        }
    };

    // Handler to request a new suggestion from the backend
    const handleRequestSuggestion = async () => {
        setSuggestionError(null);
        setIsProcessingLibrary(true); 
        setSuggestedTrack(null); 
        try {
            console.log('Requesting new suggestion...');
            const newSuggestion = await RequestNewSuggestion();
            console.log('New suggestion received:', newSuggestion);
            if (newSuggestion && newSuggestion.id) {
                setSuggestedTrack(newSuggestion);
            } else {
                console.error('Invalid suggestion format or missing ID:', newSuggestion);
                setSuggestionError('Received invalid suggestion from backend.');
            }
        } catch (err) {
           // Display error, user can manually retry with button
           console.error('Failed to request suggestion:', err);
           const errorMsg = err instanceof Error ? err.message : 'Failed to get suggestion.';
           setSuggestionError(`Suggestion failed: ${errorMsg}`);
        } finally {
            setIsProcessingLibrary(false);
        }
    };

    return (
        <div className="app">
            <header>
                <h1>Spotify Library</h1>
                {user && (
                    <div className="user-info">
                        {user.images?.[0]?.url && (
                            <img src={user.images[0].url} alt={user.display_name} className="user-avatar" />
                        )}
                        <span className="user-name">Connected as {user.display_name}</span>
                    </div>
                )}
            </header>

            <div className="main-content">
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
                            <div className="loading-indicator">Asking the AI for a suggestion...</div>
                        ) : suggestionError ? (
                            // Show error and the suggest button
                            <div className="suggestion-error-state">
                                <div className="error-message">{suggestionError}</div>
                                <button onClick={handleRequestSuggestion}>Suggest a song</button>
                            </div>
                        ) : suggestedTrack ? (
                            <div className="suggested-track-display">
                                <div className="suggestion-art-and-info">
                                    {/* Album art */} 
                                    {suggestedTrack.albumArtUrl && (
                                        <img 
                                            src={suggestedTrack.albumArtUrl} 
                                            alt={suggestedTrack.name} 
                                            className="suggestion-album-art" 
                                        />
                                    )}
                                    {/* Track info + Play button */} 
                                    <div className="suggestion-track-info">
                                        <p><strong>{suggestedTrack.name}</strong></p>
                                        <p>by {suggestedTrack.artist}</p>
                                        {suggestedTrack.previewUrl && (
                                            <button 
                                                className={`play-button suggestion-play-button ${currentlyPlaying === suggestedTrack.previewUrl ? 'playing' : ''}`}
                                                onClick={() => handlePlay(suggestedTrack, suggestedTrack.previewUrl ?? null)}
                                            >
                                                {currentlyPlaying === suggestedTrack.previewUrl ? '⏸' : '▶'}
                                            </button>
                                        )}
                                    </div>
                                    {/* Controls moved inside */} 
                                    <div className="suggestion-controls">
                                        <button onClick={() => handleSuggestionFeedback('like')}>👍 Like</button>
                                        <button onClick={() => handleSuggestionFeedback('dislike')}>👎 Dislike</button>
                                        <button onClick={handleAddSuggestionToLibrary}>➕ Add to Library</button>
                                        <button onClick={handleRequestSuggestion}>Next Suggestion</button>
                                    </div>
                                </div> {/* End of suggestion-art-and-info wrapper */} 
                                
                                {/* Controls block is no longer here */}
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
                                                isSaved={savedTracks?.items?.some((t) => t.track?.id === track.id)}
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
                                        onClick={() => setIsFavoritesCollapsed(!isFavoritesCollapsed)}
                                    >
                                        {isFavoritesCollapsed ? '▼' : '▲'}
                                    </button>
                                </div>
                                {!isFavoritesCollapsed && (
                                    <>
                                        {!savedTracks?.items || savedTracks.items.length === 0 ? (
                                            <div className="no-results">
                                                No saved tracks yet. Search for tracks to add them to your library.
                                            </div>
                                        ) : (
                                            <>
                                                <div className="track-grid">
                                                    {savedTracks.items.map((item) => item.track && (
                                                        <TrackCard
                                                            key={item.track.id}
                                                            track={item.track}
                                                            isSaved={true}
                                                        />
                                                    ))}
                                                </div>
                                                <div className="pagination">
                                                    <button
                                                        onClick={handlePrevPage}
                                                        disabled={currentPage === 1}
                                                    >
                                                        Previous
                                                    </button>
                                                    <span>Page {currentPage} of {Math.ceil(totalTracks / ITEMS_PER_PAGE)}</span>
                                                    <button
                                                        onClick={handleNextPage}
                                                        disabled={currentPage * ITEMS_PER_PAGE >= totalTracks}
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
                                <img src={info.albumArtUrl} alt={info.name} />
                                <div className="now-playing-info">
                                    <h4>{info.name}</h4>
                                    <p>{info.artist}</p>
                                </div>
                                <div className="now-playing-controls">
                                    <button
                                        className="play-button playing"
                                        // Call handlePlay directly, relying on its internal null check
                                        // Pass info.previewUrl which is string | null
                                        onClick={() => handlePlay(nowPlayingTrack, info.previewUrl)}
                                        disabled={info.previewUrl === null} // Still disable if no preview
                                    >
                                        ⏸
                                    </button>
                                </div>
                                {/* Render audio only if playing this specific track */}
                                {currentlyPlaying === info.previewUrl && info.previewUrl !== null && (
                                    <audio
                                        src={info.previewUrl} // Safe due to check
                                        autoPlay
                                        onEnded={() => {
                                            setCurrentlyPlaying(null);
                                            setNowPlayingTrack(null);
                                        }}
                                    />
                                )}
                            </>
                        );
                    })()}
                </div>
            )}
        </div>
    );
}

export default App;
