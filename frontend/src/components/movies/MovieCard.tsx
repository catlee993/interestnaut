import { Card, CardContent, CardMedia, Typography, IconButton } from '@mui/material';
import { styled } from '@mui/material/styles';
import { BookmarkBorder, Bookmark } from '@mui/icons-material';
import { MovieWithSavedStatus } from '../../../wailsjs/go/models';

const StyledCard = styled(Card)(({ theme }) => ({
  height: '100%',
  display: 'flex',
  flexDirection: 'column',
  position: 'relative',
}));

const SaveButton = styled(IconButton)(({ theme }) => ({
  position: 'absolute',
  top: theme.spacing(1),
  right: theme.spacing(1),
  backgroundColor: 'rgba(255, 255, 255, 0.8)',
  '&:hover': {
    backgroundColor: 'rgba(255, 255, 255, 0.9)',
  },
}));

interface MovieCardProps {
  movie: MovieWithSavedStatus;
  isSaved: boolean;
  onSave: (movieId: number) => void;
}

export function MovieCard({ movie, isSaved, onSave }: MovieCardProps) {
  const releaseYear = movie.release_date ? new Date(movie.release_date).getFullYear() : 'N/A';
  const posterUrl = movie.poster_path 
    ? `https://image.tmdb.org/t/p/w500${movie.poster_path}`
    : '/placeholder.png';

  return (
    <StyledCard>
      <CardMedia
        component="img"
        height="300"
        image={posterUrl}
        alt={movie.title}
      />
      <SaveButton onClick={() => onSave(movie.id)}>
        {isSaved ? <Bookmark /> : <BookmarkBorder />}
      </SaveButton>
      <CardContent>
        <Typography gutterBottom variant="h6" component="div">
          {movie.title}
        </Typography>
        <Typography variant="body2" color="text.secondary">
          {releaseYear}
        </Typography>
      </CardContent>
    </StyledCard>
  );
} 