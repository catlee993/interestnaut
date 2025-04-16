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
import { Favorite, FavoriteBorder, Movie } from "@mui/icons-material";
import { MovieWithSavedStatus } from "@wailsjs/go/models";

interface MovieCardProps {
  movie: MovieWithSavedStatus;
  isSaved: boolean;
  onSave: (movieId: number) => void;
}

interface ControlsProps {
  isFavorited: boolean;
  onToggleFavorite: () => void;
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
  height: "120px", // Fixed height
}));

const Controls = styled(Box)<ControlsProps>(({ theme }) => ({
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  width: "100%",
  marginTop: theme.spacing(1),
}));

// Helper component for Controls
const FavoriteControls = ({ isFavorited, onToggleFavorite }: ControlsProps) => (
  <IconButton onClick={onToggleFavorite} size="small" sx={{ color: "white" }}>
    {isFavorited ? <Favorite sx={{ color: "#ff4081" }} /> : <FavoriteBorder />}
  </IconButton>
);

export function MovieCard({ movie, isSaved, onSave }: MovieCardProps) {
  const hasPoster = movie.poster_path && movie.poster_path !== "";
  
  return (
    <StyledCard>
      {/* Movie poster */}
      <Box sx={{ position: "relative", width: "100%", paddingTop: "150%" }}>
        {hasPoster ? (
          <CardMedia
            component="img"
            image={`https://image.tmdb.org/t/p/w500${movie.poster_path}`}
            alt={movie.title}
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
            <Movie sx={{ fontSize: 60, opacity: 0.7, mb: 2 }} />
            <Typography variant="subtitle1" align="center" sx={{ px: 2 }}>
              {movie.title}
            </Typography>
          </Box>
        )}

        <Overlay>
          {/* Title positioned directly above controls */}
          <Box sx={{ position: "absolute", bottom: "36px", left: 16, right: 16 }}>
            <Typography 
              variant="h6" 
              component="h2" 
              noWrap
            >
              {movie.title}
            </Typography>
          </Box>
          
          {/* Controls positioned at bottom */}
          <Box 
            sx={{
              position: "absolute", 
              bottom: 8, 
              left: 16, 
              right: 16,
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
              width: "calc(100% - 32px)"
            }}
          >
            <Box sx={{ display: "flex", alignItems: "center" }}>
              {movie.release_date && (
                <Typography variant="body2" sx={{ opacity: 0.8, mr: 1 }}>
                  {new Date(movie.release_date).getFullYear()}
                </Typography>
              )}
              {movie.vote_average > 0 && (
                <Tooltip title={`${movie.vote_count} votes`}>
                  <Chip
                    label={movie.vote_average.toFixed(1)}
                    size="small"
                    sx={{
                      bgcolor: getScoreColor(movie.vote_average),
                      color: "white",
                      height: "20px",
                      "& .MuiChip-label": { px: 1 },
                    }}
                  />
                </Tooltip>
              )}
            </Box>
            <FavoriteControls
              isFavorited={isSaved}
              onToggleFavorite={() => onSave(movie.id)}
            />
          </Box>
        </Overlay>
      </Box>
    </StyledCard>
  );
}

function getScoreColor(score: number): string {
  if (score >= 8) return "#4CAF50";
  if (score >= 6) return "#FF9800";
  return "#F44336";
}
