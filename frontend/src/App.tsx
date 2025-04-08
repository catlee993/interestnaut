import { useEffect, useState } from 'react';
import './App.css';
import {
    GetSavedTracks,
    SearchTracks,
    SaveTrack,
    RemoveTrack,
    GetCurrentUser
} from "../wailsjs/go/spotify/WailsClient";
import { spotify } from "../wailsjs/go/models";

interface AuthStatus {
    isAuthenticated: boolean;
    isExpired: boolean;
    expiresIn: number;
}

function App() {
    const [savedTracks, setSavedTracks] = useState<spotify.SavedTracks | null>(null);
    const [searchResults, setSearchResults] = useState<spotify.SimpleTrack[]>([]);
    const [searchQuery, setSearchQuery] = useState<string>("");
    const [user, setUser] = useState<spotify.UserProfile | null>(null);
    const [error, setError] = useState<string | null>(null);
    const [isLoading, setIsLoading] = useState<boolean>(false);
    const [currentPage, setCurrentPage] = useState<number>(1);
    const [totalTracks, setTotalTracks] = useState<number>(0);
    const [currentlyPlaying, setCurrentlyPlaying] = useState<string | null>(null);
    const [nowPlayingTrack, setNowPlayingTrack] = useState<spotify.SimpleTrack | spotify.Track | null>(null);
    const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false);
    const [isInitialized, setIsInitialized] = useState<boolean>(false);
    const ITEMS_PER_PAGE = 20;

    useEffect(() => {
        const initializeApp = async () => {
            try {
                console.log('Initializing app...');
                setIsLoading(true);
                setError(null);
                
                // Try to load user profile first to check authentication
                console.log('Loading user profile...');
                const userProfile = await GetCurrentUser();
                
                if (userProfile) {
                    console.log('User profile loaded successfully:', userProfile.display_name);
                    setUser(userProfile);
                    setIsAuthenticated(true);
                    
                    // Only load saved tracks after we confirm we're authenticated
                    console.log('Loading saved tracks...');
                    const tracks = await GetSavedTracks(ITEMS_PER_PAGE, 0);
                    
                    if (tracks) {
                        console.log('Loaded', tracks.items?.length || 0, 'tracks');
                        setSavedTracks(tracks);
                        setTotalTracks(tracks?.total || 0);
                        setCurrentPage(1);
                    } else {
                        console.error('Tracks response is null');
                        setError('Failed to load saved tracks');
                    }
                    
                    setIsInitialized(true);
                } else {
                    console.error('User profile is null');
                    setError('Failed to load user profile');
                }
            } catch (err) {
                console.error('Failed to initialize app:', err);
                setError('Not authenticated with Spotify');
                // Retry after a short delay
                setTimeout(initializeApp, 2000);
            } finally {
                setIsLoading(false);
            }
        };

        initializeApp();
    }, []);

    const loadSavedTracks = async (page: number) => {
        if (!isAuthenticated) {
            console.log('Not authenticated, skipping loadSavedTracks');
            return;
        }

        try {
            console.log('Loading saved tracks for page:', page);
            setIsLoading(true);
            setError(null);
            const offset = (page - 1) * ITEMS_PER_PAGE;
            const tracks = await GetSavedTracks(ITEMS_PER_PAGE, offset);
            
            if (tracks) {
                console.log('Loaded', tracks.items?.length || 0, 'tracks');
                setSavedTracks(tracks);
                setTotalTracks(tracks?.total || 0);
                setCurrentPage(page);
            } else {
                console.error('Tracks response is null');
                setError('Failed to load saved tracks');
            }
        } catch (err) {
            console.error('Failed to load saved tracks:', err);
            setError('Failed to load saved tracks');
            // If we get an auth error, update the auth state
            if (err instanceof Error && err.message.includes('not authenticated')) {
                setIsAuthenticated(false);
            }
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

    const handlePlay = (track: spotify.SimpleTrack | spotify.Track, previewUrl: string | null) => {
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

    const getTrackInfo = (track: spotify.SimpleTrack | spotify.Track) => {
        if ('artist' in track) {
            return {
                name: track.name,
                artist: track.artist,
                album: track.album,
                albumArtUrl: track.albumArtUrl || '',
                previewUrl: track.previewUrl || null,
            };
        } else {
            return {
                name: track.name,
                artist: track.artists[0]?.name || '',
                album: track.album.name,
                albumArtUrl: track.album.images[0]?.url || '',
                previewUrl: track.preview_url || null,
            };
        }
    };

    const TrackCard = ({ track, isSaved = false }: { track: spotify.SimpleTrack | spotify.Track, isSaved?: boolean }) => {
        const info = getTrackInfo(track);
        const previewUrl = info.previewUrl || undefined;
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

    return (
        <div className="app">
            <header>
                <h1>Spotify Library</h1>
                {user && (
                    <div className="user-info">
                        {user.images?.[0]?.url && (
                            <img src={user.images[0].url} alt={user.display_name} />
                        )}
                        <span>Welcome, {user.display_name}</span>
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
                                <h2>Your Library</h2>
                                {savedTracks?.items?.length === 0 ? (
                                    <div className="no-results">
                                        No saved tracks yet. Search for tracks to add them to your library.
                                    </div>
                                ) : (
                                    <>
                                        <div className="track-grid">
                                            {savedTracks?.items?.map((item) => (
                                                item.track && (
                                                    <TrackCard
                                                        key={item.track.id}
                                                        track={item.track}
                                                        isSaved={true}
                                                    />
                                                )
                                            ))}
                                        </div>
                                        {totalTracks > ITEMS_PER_PAGE && (
                                            <div className="pagination">
                                                <button
                                                    disabled={currentPage === 1}
                                                    onClick={() => loadSavedTracks(currentPage - 1)}
                                                >
                                                    ← Previous
                                                </button>
                                                <span>
                                                    Page {currentPage} of {Math.ceil(totalTracks / ITEMS_PER_PAGE)}
                                                </span>
                                                <button
                                                    disabled={currentPage >= Math.ceil(totalTracks / ITEMS_PER_PAGE)}
                                                    onClick={() => loadSavedTracks(currentPage + 1)}
                                                >
                                                    Next →
                                                </button>
                                            </div>
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
