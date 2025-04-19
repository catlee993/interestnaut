import React from "react";
import {
  Card,
  CardMedia,
  Typography,
  IconButton,
  Tooltip,
  Box,
  Chip,
  styled,
} from "@mui/material";
import {
  Favorite,
  FavoriteBorder,
  PlaylistAdd,
  PlaylistAddCheck,
  SportsEsports,
} from "@mui/icons-material";
import { FeedbackControls } from "../common/FeedbackControls";
import { bindings } from "@wailsjs/go/models";

// Extended game type to support additional properties
export interface ExtendedGame {
  convertValues?: (a: any, classs: any, asMap?: boolean) => any;
  isSaved?: boolean;
  isInWatchlist?: boolean;
  id: number;
  name: string;
  background_image?: string;
  description?: string;
  released?: string;
  rating?: number;
  ratings_count?: number;
  genres?: { name: string }[];
  platforms?: { name: string }[];
}

export interface GameCardProps {
  game: ExtendedGame;
  isSaved: boolean;
  isInWatchlist?: boolean;
  view: "default" | "watchlist";
  onSave: (gameId: number) => void;
  onAddToWatchlist?: (gameId: number) => void;
  onRemoveFromWatchlist?: (gameId: number) => void;
  onLike?: (gameId: number) => void;
  onDislike?: (gameId: number) => void;
}

interface LibraryControlsProps {
  isInLibrary: boolean;
  onToggleLibrary: () => void;
}

interface WatchlistControlsProps {
  isInWatchlist: boolean;
  onAddToWatchlist: () => void;
}

const StyledCard = styled(Card)(({ theme }) => ({
  height: "100%",
  width: "100%",
  position: "relative",
  overflow: "hidden",
  backgroundColor: "var(--surface-color)",
  transition: "transform 0.2s ease-in-out, box-shadow 0.2s ease-in-out",
  border: "2px solid rgba(123, 104, 238, 0.3)",
  "&:hover": {
    transform: "translateY(-4px)",
    boxShadow: "0 10px 20px rgba(0,0,0,0.2)",
    borderColor: "rgba(123, 104, 238, 0.5)",
  },
}));

const Overlay = styled(Box)(({ theme }) => ({
  position: "absolute",
  bottom: 0,
  left: 0,
  right: 0,
  background:
    "linear-gradient(to top, rgba(0,0,0,1) 0%, rgba(0,0,0,0.95) 20%, rgba(0,0,0,0.85) 40%, rgba(0,0,0,0.6) 70%, rgba(0,0,0,0.3) 85%, transparent 100%)",
  padding: theme.spacing(2),
  color: theme.palette.common.white,
  height: "120px",
}));

const LibraryControls = ({
  isInLibrary,
  onToggleLibrary,
}: LibraryControlsProps) => (
  <IconButton onClick={onToggleLibrary} size="small" sx={{ color: "white" }}>
    {isInLibrary ? (
      <Favorite sx={{ color: "var(--primary-color)" }} />
    ) : (
      <FavoriteBorder />
    )}
  </IconButton>
);

const WatchlistControls = ({
  isInWatchlist,
  onAddToWatchlist,
}: WatchlistControlsProps) => (
  <IconButton onClick={onAddToWatchlist} size="small" sx={{ color: "white" }}>
    {isInWatchlist ? (
      <PlaylistAddCheck sx={{ color: "#64b5f6" }} />
    ) : (
      <PlaylistAdd sx={{ color: "white" }} />
    )}
  </IconButton>
);

export function GameCard({
  game,
  isSaved,
  isInWatchlist = false,
  view = "default",
  onSave,
  onAddToWatchlist,
  onRemoveFromWatchlist,
  onLike,
  onDislike,
}: GameCardProps) {
  const hasImage = game.background_image && game.background_image !== "";

  return (
    <StyledCard>
      <Box sx={{ position: "relative", width: "100%", paddingTop: "150%" }}>
        {hasImage ? (
          <CardMedia
            component="img"
            image={game.background_image}
            alt={game.name}
            sx={{
              position: "absolute",
              top: 0,
              left: 0,
              width: "100%",
              height: "100%",
              objectFit: "cover",
            }}
          />
        ) : (
          <Box
            sx={{
              position: "absolute",
              top: 0,
              left: 0,
              width: "100%",
              height: "100%",
              display: "flex",
              flexDirection: "column",
              justifyContent: "center",
              alignItems: "center",
              bgcolor: "rgba(123, 104, 238, 0.1)",
              color: "white",
            }}
          >
            <SportsEsports sx={{ fontSize: 60, opacity: 0.7, mb: 2 }} />
            <Typography variant="subtitle1" align="center" sx={{ px: 2 }}>
              {game.name}
            </Typography>
          </Box>
        )}

        <Overlay>
          <Box
            sx={{ position: "absolute", bottom: "36px", left: 16, right: 16 }}
          >
            <Typography variant="h6" component="h2" noWrap>
              {game.name}
            </Typography>
          </Box>

          <Box
            sx={{
              position: "absolute",
              bottom: 8,
              left: 16,
              right: 16,
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
              width: "calc(100% - 32px)",
            }}
          >
            <Box sx={{ display: "flex", alignItems: "center" }}>
              {game.released && (
                <Typography variant="body2" sx={{ opacity: 0.8, mr: 1 }}>
                  {new Date(game.released).getFullYear()}
                </Typography>
              )}
              {game.rating !== undefined && (
                <Tooltip title={`${game.ratings_count || 0} ratings`}>
                  <Chip
                    label={(game.rating * 2).toFixed(1)}
                    size="small"
                    sx={{
                      bgcolor: getScoreColor(game.rating * 2),
                      color: "white",
                      height: "20px",
                      "& .MuiChip-label": { px: 1 },
                    }}
                  />
                </Tooltip>
              )}
            </Box>

            {view === "default" ? (
              <Box sx={{ display: "flex", gap: 1 }}>
                {onAddToWatchlist && (
                  <WatchlistControls
                    isInWatchlist={isInWatchlist ?? false}
                    onAddToWatchlist={() => onAddToWatchlist!(game.id)}
                  />
                )}
                <LibraryControls
                  isInLibrary={isSaved}
                  onToggleLibrary={() => onSave(game.id)}
                />
              </Box>
            ) : (
              <FeedbackControls
                onLike={() => onLike && onLike(game.id)}
                onDislike={() => onDislike && onDislike(game.id)}
                onAddToFavorites={() => onSave(game.id)}
                isSaved={isSaved}
              />
            )}
          </Box>
        </Overlay>
      </Box>
    </StyledCard>
  );
}

function getScoreColor(score: number): string {
  if (score >= 8) return "#4c91af";
  if (score >= 6) return "#0077ff";
  return "#3c36f4";
}
