import { Box, TextField, IconButton, Paper } from '@mui/material';
import { TrackCard } from '@/components/music/tracks/TrackCard';
import { useTracks } from '@/hooks/useTracks';
import { usePlayer } from '@/components/music/player/PlayerContext';
import { FaTimes } from 'react-icons/fa';
import { useState } from 'react';

export function SearchSection() {
  const { searchResults, handleSearch, handleSave, handleRemove } = useTracks();
  const { handlePlay } = usePlayer();
  const [showResults, setShowResults] = useState(true);

  return (
    <Box sx={{ p: 3 }}>
      <Box sx={{ position: 'relative', mb: 3 }}>
        <TextField
          fullWidth
          placeholder="Search tracks..."
          onChange={(e) => {
            handleSearch(e.target.value);
            setShowResults(true);
          }}
          sx={{ 
            '& .MuiOutlinedInput-root': {
              '& fieldset': {
                borderColor: 'rgba(123, 104, 238, 0.3)',
              },
              '&:hover fieldset': {
                borderColor: 'rgba(123, 104, 238, 0.5)',
              },
              '&.Mui-focused fieldset': {
                borderColor: 'rgba(123, 104, 238, 0.8)',
              },
            },
            '& .MuiInputBase-input': {
              color: 'white',
            },
            '& .MuiInputLabel-root': {
              color: 'rgba(255, 255, 255, 0.7)',
            },
          }}
        />
        {searchResults.length > 0 && (
          <IconButton
            onClick={() => setShowResults(false)}
            sx={{
              position: 'absolute',
              right: 8,
              top: '50%',
              transform: 'translateY(-50%)',
              color: 'rgba(123, 104, 238, 0.7)',
              '&:hover': {
                color: 'rgba(123, 104, 238, 1)',
                backgroundColor: 'rgba(123, 104, 238, 0.1)',
              }
            }}
          >
            <FaTimes />
          </IconButton>
        )}
      </Box>
      {showResults && searchResults.length > 0 && (
        <Box
          sx={{
            display: 'grid',
            gridTemplateColumns: {
              xs: '1fr',
              sm: 'repeat(2, 1fr)',
              md: 'repeat(3, 1fr)'
            },
            gap: 3
          }}
        >
          {searchResults.map(track => (
            <TrackCard
              key={track.id}
              track={track}
              isSaved={false}
              onPlay={handlePlay}
              onSave={handleSave}
              onRemove={handleRemove}
            />
          ))}
        </Box>
      )}
    </Box>
  );
} 