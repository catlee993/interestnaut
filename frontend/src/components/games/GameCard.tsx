import React from 'react';
import {
  Card,
  CardContent,
  CardMedia,
  Typography,
  CardActionArea,
  CardActions,
  IconButton,
  Tooltip,
  Box,
  Chip,
} from '@mui/material';
import FavoriteIcon from '@mui/icons-material/Favorite';
import FavoriteBorderIcon from '@mui/icons-material/FavoriteBorder';
import BookmarkIcon from '@mui/icons-material/Bookmark';
import BookmarkBorderIcon from '@mui/icons-material/BookmarkBorder';
import StarIcon from '@mui/icons-material/Star';
import CloseIcon from '@mui/icons-material/Close';

interface Game {
  id: number;
  name: string;
  background_image?: string;
  released?: string;
  rating?: number;
  genres?: Array<{ id: number; name: string }>;
  isSaved?: boolean;
  isInWatchlist?: boolean;
}

interface GameCardProps {
  game: Game;
  onSelect: () => void;
  onSave: () => void;
  onAddToWatchlist?: () => void;
  onRemoveFromWatchlist?: () => void;
  isSaved: boolean;
  isInWatchlist?: boolean;
  view?: "default" | "watchlist";
}

const GameCard: React.FC<GameCardProps> = ({
  game,
  onSelect,
  onSave,
  onAddToWatchlist,
  onRemoveFromWatchlist,
  isSaved,
  isInWatchlist,
  view = "default",
}) => {
  const handleSaveClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    onSave();
  };

  const handleWatchlistClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (isInWatchlist && onRemoveFromWatchlist) {
      onRemoveFromWatchlist();
    } else if (!isInWatchlist && onAddToWatchlist) {
      onAddToWatchlist();
    }
  };

  const handleRemoveClick = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (onRemoveFromWatchlist) {
      onRemoveFromWatchlist();
    }
  };

  return (
    <Card sx={{ height: '100%', display: 'flex', flexDirection: 'column', position: 'relative' }}>
      {view === "watchlist" && onRemoveFromWatchlist && (
        <IconButton
          onClick={handleRemoveClick}
          size="small"
          sx={{ 
            color: "white",
            position: "absolute",
            top: 8,
            right: 8,
            zIndex: 100,
            bgcolor: "rgba(0,0,0,0.7)",
            '&:hover': {
              bgcolor: "rgba(255,0,0,0.7)",
            },
            width: "24px",
            height: "24px",
            minWidth: "24px"
          }}
          aria-label="Remove from watchlist"
        >
          <CloseIcon fontSize="small" />
        </IconButton>
      )}
      <CardActionArea onClick={onSelect}>
        <CardMedia
          component="img"
          height="140"
          image={
            game.background_image ||
            'https://via.placeholder.com/300x150?text=No+Image'
          }
          alt={game.name}
        />
        <CardContent sx={{ flexGrow: 1 }}>
          <Typography gutterBottom variant="h6" component="div" noWrap>
            {game.name}
          </Typography>
          
          {game.released && (
            <Typography variant="body2" color="text.secondary">
              Released: {new Date(game.released).toLocaleDateString()}
            </Typography>
          )}
          
          {game.rating !== undefined && (
            <Box sx={{ display: 'flex', alignItems: 'center', mt: 1 }}>
              <StarIcon sx={{ color: 'gold', mr: 0.5 }} fontSize="small" />
              <Typography variant="body2">
                {game.rating.toFixed(1)}
              </Typography>
            </Box>
          )}
          
          {game.genres && game.genres.length > 0 && (
            <Box sx={{ mt: 1, display: 'flex', flexWrap: 'wrap', gap: 0.5 }}>
              {game.genres.slice(0, 2).map((genre) => (
                <Chip
                  key={genre.id}
                  label={genre.name}
                  size="small"
                  variant="outlined"
                  sx={{ fontSize: '0.7rem' }}
                />
              ))}
              {game.genres.length > 2 && (
                <Chip
                  label={`+${game.genres.length - 2}`}
                  size="small"
                  variant="outlined"
                  sx={{ fontSize: '0.7rem' }}
                />
              )}
            </Box>
          )}
        </CardContent>
      </CardActionArea>
      <CardActions>
        <Tooltip title={isSaved ? "Remove from favorites" : "Add to favorites"}>
          <IconButton size="small" color="primary" onClick={handleSaveClick}>
            {isSaved ? <FavoriteIcon /> : <FavoriteBorderIcon />}
          </IconButton>
        </Tooltip>
        
        {view === "default" && (onAddToWatchlist || onRemoveFromWatchlist) && (
          <Tooltip title={isInWatchlist ? "Remove from watchlist" : "Add to watchlist"}>
            <IconButton size="small" color="primary" onClick={handleWatchlistClick}>
              {isInWatchlist ? <BookmarkIcon /> : <BookmarkBorderIcon />}
            </IconButton>
          </Tooltip>
        )}
      </CardActions>
    </Card>
  );
};

export default GameCard; 