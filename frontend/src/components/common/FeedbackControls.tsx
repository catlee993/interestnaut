import React from 'react';
import { Stack, IconButton } from "@mui/material";
import {
  Favorite,
  FavoriteBorder,
  ThumbUp,
  ThumbDown,
} from "@mui/icons-material";

export interface FeedbackControlsProps {
  onLike?: () => void;
  onDislike?: () => void;
  onAddToFavorites: () => void;
  isSaved?: boolean;
}

export const FeedbackControls: React.FC<FeedbackControlsProps> = ({
  onLike,
  onDislike,
  onAddToFavorites,
  isSaved = false,
}) => {
  return (
    <Stack 
      direction="row" 
      spacing={0.5} 
      alignItems="center"
      justifyContent="flex-end"
    >
      {onLike && (
        <IconButton onClick={onLike} size="small" sx={{ color: "white" }}>
          <ThumbUp sx={{ fontSize: 20 }} />
        </IconButton>
      )}
      {onDislike && (
        <IconButton onClick={onDislike} size="small" sx={{ color: "white" }}>
          <ThumbDown sx={{ fontSize: 20 }} />
        </IconButton>
      )}
      <IconButton
        onClick={onAddToFavorites}
        size="small"
        sx={{ color: "white" }}
      >
        {isSaved ? (
          <Favorite sx={{ fontSize: 20, color: "var(--primary-color)" }} />
        ) : (
          <FavoriteBorder sx={{ fontSize: 20 }} />
        )}
      </IconButton>
    </Stack>
  );
}; 