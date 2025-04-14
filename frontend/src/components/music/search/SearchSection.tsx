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
  const [searchQuery, setSearchQuery] = useState('');

  const handleClearSearch = () => {
    setSearchQuery('');
    handleSearch('');
    setShowResults(false);
  };

  return (
    <Box sx={{ p: 2 }}>
      <Box sx={{ position: 'relative', mb: 2 }}>
        <TextField
          fullWidth
          placeholder="Search tracks..."
          size="small"
          value={searchQuery}
          onChange={(e) => {
            setSearchQuery(e.target.value);
            handleSearch(e.target.value);
            setShowResults(true);
          }}
          sx={{ 
            '& .MuiOutlinedInput-root': {
              '& fieldset': {
                borderColor: 'rgba(123, 104, 238, 0.5)',
              },
              '&:hover fieldset': {
                borderColor: 'rgba(123, 104, 238, 0.7)',
              },
              '&.Mui-focused fieldset': {
                borderColor: 'rgba(123, 104, 238, 0.9)',
              },
            },
            '& .MuiInputBase-input': {
              color: 'white',
              fontSize: '0.875rem',
            },
            '& .MuiInputBase-input::placeholder': {
              color: 'rgba(255, 255, 255, 0.75)',
            },
          }}
        />
        {(searchResults.length > 0 || searchQuery) && (
          <IconButton
            onClick={handleClearSearch}
            size="small"
            sx={{
              position: 'absolute',
              right: 4,
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
        <Paper
          elevation={3}
          sx={{
            position: 'absolute',
            left: 0,
            right: 0,
            zIndex: 1000,
            backgroundColor: 'rgba(18, 18, 18, 0.95)',
            backdropFilter: 'blur(10px)',
            maxHeight: '60vh',
            overflowY: 'auto',
            '&::-webkit-scrollbar': {
              width: '8px',
            },
            '&::-webkit-scrollbar-track': {
              background: 'rgba(255, 255, 255, 0.1)',
            },
            '&::-webkit-scrollbar-thumb': {
              background: 'rgba(123, 104, 238, 0.5)',
              borderRadius: '4px',
              '&:hover': {
                background: 'rgba(123, 104, 238, 0.7)',
              },
            },
          }}
        >
          <Box
            sx={{
              display: 'grid',
              gridTemplateColumns: {
                xs: '1fr',
                sm: 'repeat(2, 1fr)',
                md: 'repeat(3, 1fr)'
              },
              gap: 2,
              p: 2
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
        </Paper>
      )}
    </Box>
  );
} 