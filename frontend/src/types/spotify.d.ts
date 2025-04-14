declare global {
  interface Window {
    onSpotifyWebPlaybackSDKReady: () => void;
    Spotify: {
      Player: new (config: {
        name: string;
        getOAuthToken: (callback: (token: string) => void) => void;
        volume: number;
      }) => {
        connect: () => Promise<boolean>;
        disconnect: () => void;
        addListener: (
          event: string,
          callback: (event: SpotifyPlayerEvent) => void,
        ) => void;
        removeListener: (event: string) => void;
        getCurrentState: () => Promise<SpotifyPlayerState | null>;
        setName: (name: string) => Promise<void>;
        getVolume: () => Promise<number>;
        setVolume: (volume: number) => Promise<void>;
        pause: () => Promise<void>;
        resume: () => Promise<void>;
        togglePlay: () => Promise<void>;
        seek: (position_ms: number) => Promise<void>;
        previousTrack: () => Promise<void>;
        nextTrack: () => Promise<void>;
        activateElement: () => Promise<void>;
      };
    };
  }
}

export interface SpotifyPlayerEvent {
  device_id?: string;
  state?: SpotifyPlayerState;
  message?: string;
}

export interface SpotifyPlayerState {
  position: number;
  duration: number;
  paused: boolean;
  track_window: {
    current_track: {
      id: string;
      name: string;
      uri: string;
      duration_ms: number;
    };
  };
}
