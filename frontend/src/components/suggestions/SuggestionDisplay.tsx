import {
  FaPause,
  FaPlay,
  FaPlus,
  FaStepForward,
  FaThumbsDown,
  FaThumbsUp,
} from "react-icons/fa";
import { useSuggestion } from "@/contexts/SuggestionContext";
import { usePlayer } from "@/contexts/PlayerContext";
import { SaveTrack } from "../../../wailsjs/go/bindings/Music";

export function SuggestionDisplay() {
  const {
    suggestedTrack,
    suggestionContext,
    isProcessingLibrary,
    suggestionError,
    handleSkipSuggestion,
    handleSuggestionFeedback,
    handleAddToLibrary,
    handleRequestSuggestion,
  } = useSuggestion();

  const { nowPlayingTrack, isPlaybackPaused, handlePlay } = usePlayer();

  if (isProcessingLibrary) {
    return (
      <div className="loading-indicator">
        <div className="loading-spinner"></div>
        <p>Finding your next song recommendation...</p>
      </div>
    );
  }

  if (suggestionError) {
    return (
      <div className="suggestion-error-state">
        <div className="error-message">{suggestionError}</div>
        <button onClick={handleRequestSuggestion} className="retry-button">
          Try getting a suggestion
        </button>
      </div>
    );
  }

  if (!suggestedTrack) {
    return (
      <div className="empty-suggestion-state">
        <button
          onClick={handleRequestSuggestion}
          className="request-suggestion-button"
        >
          Get a song suggestion
        </button>
      </div>
    );
  }

  return (
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
            onClick={() => handlePlay(suggestedTrack)}
          >
            {!isPlaybackPaused && nowPlayingTrack?.id === suggestedTrack.id ? (
              <FaPause />
            ) : (
              <FaPlay />
            )}
          </button>
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
          <button
            onClick={handleAddToLibrary}
            className="action-button add-button"
          >
            <FaPlus /> Add to Library
          </button>
          <button
            onClick={handleSkipSuggestion}
            className="action-button next-button"
          >
            Next Suggestion <FaStepForward />
          </button>
        </div>
      </div>
    </div>
  );
}
