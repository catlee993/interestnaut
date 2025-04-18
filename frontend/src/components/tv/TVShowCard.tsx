import {
  Card,
  CardMedia,
  Typography,
  IconButton,
  Box,
  Chip,
  Tooltip,
  styled,
  Stack,
} from "@mui/material";
import {
  Favorite,
  FavoriteBorder,
  Tv,
  PlaylistAdd,
  PlaylistAddCheck,
  ThumbUp,
  ThumbDown,
} from "@mui/icons-material";
import { bindings } from "@wailsjs/go/models";

interface TVShowCardProps {
  show: bindings.TVShowWithSavedStatus;
  isSaved: boolean;
  isInWatchlist?: boolean;
  view: "default" | "watchlist";
  onSave: (showId: number) => void;
  onAddToWatchlist?: (showId: number) => void;
  onRemoveFromWatchlist?: (showId: number) => void;
  onLike?: (showId: number) => void;
  onDislike?: (showId: number) => void;
}

interface LibraryControlsProps {
  isInLibrary: boolean;
  onToggleLibrary: () => void;
}

interface WatchlistControlsProps {
  isInWatchlist: boolean;
  onAddToWatchlist: () => void;
}

interface FeedbackControlsProps {
  onLike?: () => void;
  onDislike?: () => void;
  onAddToFavorites: () => void;
  isSaved?: boolean;
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
      <PlaylistAdd />
    )}
  </IconButton>
);

const FeedbackControls = ({
  onLike,
  onDislike,
  onAddToFavorites,
  isSaved = false,
}: FeedbackControlsProps) => {
  return (
    <Box sx={{ display: "flex", gap: 0.5 }}>
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
    </Box>
  );
};

export function TVShowCard({
  show,
  isSaved,
  isInWatchlist = false,
  view = "default",
  onSave,
  onAddToWatchlist,
  onRemoveFromWatchlist,
  onLike,
  onDislike,
}: TVShowCardProps) {
  const hasPoster = show.poster_path && show.poster_path !== "";

  return (
    <StyledCard>
      <Box sx={{ position: "relative", width: "100%", paddingTop: "150%" }}>
        {hasPoster ? (
          <CardMedia
            component="img"
            image={`https://image.tmdb.org/t/p/w500${show.poster_path}`}
            alt={show.name}
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
            <Tv sx={{ fontSize: 60, opacity: 0.7, mb: 2 }} />
            <Typography variant="subtitle1" align="center" sx={{ px: 2 }}>
              {show.name}
            </Typography>
          </Box>
        )}

        <Overlay>
          <Box
            sx={{ position: "absolute", bottom: "36px", left: 16, right: 16 }}
          >
            <Typography variant="h6" component="h2" noWrap>
              {show.name}
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
              {show.first_air_date && (
                <Typography variant="body2" sx={{ opacity: 0.8, mr: 1 }}>
                  {new Date(show.first_air_date).getFullYear()}
                </Typography>
              )}
              {show.vote_average > 0 && (
                <Tooltip title={`${show.vote_count} votes`}>
                  <Chip
                    label={show.vote_average.toFixed(1)}
                    size="small"
                    sx={{
                      bgcolor: getScoreColor(show.vote_average),
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
                    onAddToWatchlist={() => onAddToWatchlist!(show.id)}
                  />
                )}
                <LibraryControls
                  isInLibrary={isSaved}
                  onToggleLibrary={() => onSave(show.id)}
                />
              </Box>
            ) : (
              <FeedbackControls
                onLike={() => onLike && onLike(show.id)}
                onDislike={() => onDislike && onDislike(show.id)}
                onAddToFavorites={() => onSave(show.id)}
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