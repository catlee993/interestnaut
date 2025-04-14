import { Card, CardContent, CardMedia, Typography, IconButton, Box } from '@mui/material';
import { Favorite, FavoriteBorder } from '@mui/icons-material';
import { MovieWithSavedStatus } from '@wailsjs/go/models';

interface MovieCardProps {
  movie: MovieWithSavedStatus;
  isSaved: boolean;
  onSave: (movieId: number) => void;
}

export function MovieCard({ movie, isSaved, onSave }: MovieCardProps) {
  return (
    <Card sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      <CardMedia
        component="img"
        height="300"
        image={`https://image.tmdb.org/t/p/w500${movie.poster_path}`}
        alt={movie.title}
      />
      <CardContent sx={{ flexGrow: 1 }}>
        <Typography gutterBottom variant="h6" component="div">
          {movie.title}
        </Typography>
        <Typography variant="body2" color="text.secondary">
          {movie.release_date}
        </Typography>
      </CardContent>
      <Box sx={{ p: 1, display: 'flex', justifyContent: 'flex-end' }}>
        <IconButton onClick={() => onSave(movie.id)}>
          {isSaved ? <Favorite color="error" /> : <FavoriteBorder />}
        </IconButton>
      </Box>
    </Card>
  );
} 