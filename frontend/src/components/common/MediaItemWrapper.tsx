import React from "react";
import { Box } from "@mui/material";
import { MediaItemBase } from "@/hooks/useMediaSection";

interface MediaItemWrapperProps {
  item: MediaItemBase;
  children: React.ReactNode;
  view: "default" | "watchlist" | "saved";
  onRemoveFromWatchlist?: () => void;
}

/**
 * A wrapper component for media items that handles common functionality
 * like the remove button for watchlist items
 */
export const MediaItemWrapper: React.FC<MediaItemWrapperProps> = ({
  item,
  children,
  view,
  onRemoveFromWatchlist,
}) => {
  const handleRemoveClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (onRemoveFromWatchlist) {
      onRemoveFromWatchlist();
    }
  };

  return (
    <Box
      sx={{
        position: "relative",
        cursor: "pointer",
        height: "100%",
      }}
    >
      {/* Remove button - shown in watchlist and saved views */}
      {((view === "watchlist" || view === "saved") && onRemoveFromWatchlist) && (
        <Box
          onClick={handleRemoveClick}
          sx={{
            position: "absolute",
            top: 8,
            right: 8,
            zIndex: 100,
            cursor: "pointer",
            width: "24px",
            height: "24px",
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            transition: "transform 0.15s ease-in-out",
            "&:hover": {
              transform: "scale(1.2)",
            },
          }}
          aria-label={view === "watchlist" ? "Remove from watchlist" : "Remove from saved"}
        >
          <svg
            width="24"
            height="24"
            viewBox="0 0 24 24"
            xmlns="http://www.w3.org/2000/svg"
          >
            {/* X with purple outline */}
            <path
              d="M6.4 6.4L17.6 17.6M6.4 17.6L17.6 6.4"
              stroke="#6a1b9a"
              strokeWidth="6"
              strokeLinecap="round"
            />
            {/* White inner X */}
            <path
              d="M6.4 6.4L17.6 17.6M6.4 17.6L17.6 6.4"
              stroke="white"
              strokeWidth="1.5"
              strokeLinecap="round"
            />
          </svg>
        </Box>
      )}
      {children}
    </Box>
  );
};
