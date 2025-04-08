import { useState, useEffect } from 'react';
import './App.css';
import {
    GetSavedTracks,
    SearchTracks,
    SaveTrack,
    RemoveTrack,
    GetCurrentUser
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
    const [nowPlayingTrack, setNowPlayingTrack] = useState<spotify.Track | spotify.SimpleTrack | null>(null);
    const [isFavoritesCollapsed, setIsFavoritesCollapsed] = useState<boolean>(false);
    const ITEMS_PER_PAGE = 20;

    useEffect(() => {
        initializeApp();
    }, []);

    const initializeApp = async () => {
        try {
            console.log('Initializing app...');
            setIsLoading(true);
            setError(null);
            
            // Get current user
            const currentUser = await GetCurrentUser();
            if (currentUser) {
                setUser(currentUser);
                await loadSavedTracks(1);
            }
        } catch (err) {
            console.error('Failed to initialize app:', err);
            setError(err instanceof Error ? err.message : 'An error occurred');
        } finally {
            setIsLoading(false);
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

    const handlePlay = (track: spotify.Track | spotify.SimpleTrack, previewUrl: string | null) => {
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

    const getTrackInfo = (track: spotify.Track | spotify.SimpleTrack) => {
        if ('artists' in track) {
            return {
                name: track.name,
                artist: track.artists[0]?.name || '',
                album: track.album.name,
                albumArtUrl: track.album.images[0]?.url || '',
                previewUrl: track.preview_url,
            };
        } else {
            return {
                name: track.name,
                artist: track.artist,
                album: track.album,
                albumArtUrl: track.albumArtUrl,
                previewUrl: track.previewUrl,
            };
        }
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
                        src={previewUrl}
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

                {isLoading ? (
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

            {nowPlayingTrack && (
                <div className="now-playing">
                    <img src={getTrackInfo(nowPlayingTrack).albumArtUrl} alt={getTrackInfo(nowPlayingTrack).name} />
                    <div className="now-playing-info">
                        <h4>{getTrackInfo(nowPlayingTrack).name}</h4>
                        <p>{getTrackInfo(nowPlayingTrack).artist}</p>
                    </div>
                    <div className="now-playing-controls">
                        <button
                            className="play-button playing"
                            onClick={() => handlePlay(nowPlayingTrack, getTrackInfo(nowPlayingTrack).previewUrl)}
                        >
                            ⏸
                        </button>
                    </div>
                </div>
            )}
        </div>
    );
}

export default App;
