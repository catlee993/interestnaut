import React from 'react';
import { Box, Typography, Button, Card, CardMedia, CardContent, styled } from '@mui/material';
import { ThumbUp, ThumbDown, SkipNext } from '@mui/icons-material';
import { bindings } from '@wailsjs/go/models';

interface GameSuggestionProps {
  game: bindings.GameWithSavedStatus;
  reason: string | null;
  onLike: () => void;
  onDislike: () => void;
  onSkip: () => void;
}

const ActionButton = styled(Button)(({ theme }) => ({
  margin: '0 8px',
  borderRadius: '20px',
  textTransform: 'none',
  padding: '8px 16px',
}));

export function GameSuggestion({ game, reason, onLike, onDislike, onSkip }: GameSuggestionProps) {
  return (
    <Box
      sx={{
        display: 'flex',
        flexDirection: { xs: 'column', md: 'row' },
        alignItems: { xs: 'center', md: 'flex-start' },
        backgroundColor: 'var(--surface-color)',
        borderRadius: 'var(--border-radius)',
        overflow: 'hidden',
        p: 3,
      }}
    >
      <Box sx={{ width: { xs: '100%', md: '300px' }, flexShrink: 0, mb: { xs: 2, md: 0 } }}>
        <Card sx={{ height: '100%' }}>
          <CardMedia
            component="img"
            image={game.background_image || '/placeholder-game.jpg'}
            alt={game.name}
            sx={{ height: '450px', objectFit: 'cover' }}
          />
        </Card>
      </Box>
      
      <Box sx={{ ml: { md: 4 }, flex: 1 }}>
        <Typography variant="h4" gutterBottom>
          {game.name}
        </Typography>
        
        <Typography variant="subtitle1" color="text.secondary" gutterBottom>
          {game.released?.substring(0, 4)} • Rating: {game.rating.toFixed(1)}/5
        </Typography>
        
        {game.genres && game.genres.length > 0 && (
          <Box sx={{ mb: 2 }}>
            <Typography variant="subtitle2" component="span">
              Genres:
            </Typography>
            <Typography component="span" color="text.secondary" sx={{ ml: 1 }}>
              {game.genres.map(genre => genre.name).join(', ')}
            </Typography>
          </Box>
        )}

        {game.platforms && game.platforms.length > 0 && (
          <Box sx={{ mb: 2 }}>
            <Typography variant="subtitle2" component="span">
              Platforms:
            </Typography>
            <Typography component="span" color="text.secondary" sx={{ ml: 1 }}>
              {game.platforms.map(platform => platform.name).join(', ')}
            </Typography>
          </Box>
        )}
        
        <Typography 
          variant="body1" 
          paragraph 
          sx={{ 
            mb: 3, 
            maxHeight: '120px', 
            overflowY: 'auto', 
            padding: '0 8px 0 0',
            '&::-webkit-scrollbar': {
              width: '6px',
            },
            '&::-webkit-scrollbar-thumb': {
              backgroundColor: 'rgba(123, 104, 238, 0.3)',
              borderRadius: '6px',
            },
            '&::-webkit-scrollbar-track': {
              backgroundColor: 'rgba(0, 0, 0, 0.1)',
              borderRadius: '6px',
            },
          }}
        >
          {game.description}
        </Typography>
        
        {reason && (
          <Box sx={{ 
            mb: 3, 
            p: 2, 
            bgcolor: 'rgba(123, 104, 238, 0.1)', 
            borderRadius: 2,
            maxHeight: '150px',
            overflowY: 'auto',
            '&::-webkit-scrollbar': {
              width: '6px',
            },
            '&::-webkit-scrollbar-thumb': {
              backgroundColor: 'rgba(123, 104, 238, 0.3)',
              borderRadius: '6px',
            },
            '&::-webkit-scrollbar-track': {
              backgroundColor: 'rgba(0, 0, 0, 0.1)',
              borderRadius: '6px',
            },
          }}>
            <Typography variant="h6" gutterBottom sx={{ color: 'var(--primary-color)' }}>
              Why we recommend this
            </Typography>
            <Typography variant="body2">
              {reason}
            </Typography>
          </Box>
        )}
        
        <Box sx={{ 
          display: 'flex', 
          justifyContent: 'center',
          flexWrap: 'wrap',
          mt: 3
        }}>
          <ActionButton 
            variant="contained" 
            startIcon={<ThumbUp />}
            onClick={onLike}
            sx={{ 
              bgcolor: 'var(--primary-color)',
              '&:hover': { bgcolor: 'var(--primary-hover)' }
            }}
          >
            Like
          </ActionButton>
          
          <ActionButton 
            variant="outlined" 
            startIcon={<ThumbDown />}
            onClick={onDislike}
            sx={{ 
              borderColor: 'var(--error-color)',
              color: 'var(--error-color)',
              '&:hover': { 
                bgcolor: 'rgba(244, 67, 54, 0.08)',
                borderColor: 'var(--error-color)'
              }
            }}
          >
            Dislike
          </ActionButton>
          
          <ActionButton 
            variant="outlined" 
            startIcon={<SkipNext />}
            onClick={onSkip}
            sx={{ 
              borderColor: 'var(--text-secondary)',
              color: 'var(--text-secondary)',
              '&:hover': { 
                bgcolor: 'rgba(255, 255, 255, 0.08)',
                borderColor: 'var(--text-secondary)'
              }
            }}
          >
            Skip
          </ActionButton>
        </Box>
      </Box>
    </Box>
  );
} 