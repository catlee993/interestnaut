import { AppBar, Toolbar, Tabs, Tab, Box, Avatar, Typography, Button } from '@mui/material';
import { styled } from '@mui/material/styles';
import { useMedia, MediaType } from '@/contexts/MediaContext';
import { spotify } from '../../../wailsjs/go/models';
import { useAuth } from '@/hooks/useAuth';

const StyledAppBar = styled(AppBar)(({ theme }) => ({
  background: 'rgba(18, 18, 18, 0.95)',
  backdropFilter: 'blur(10px)',
  borderBottom: `1px solid ${theme.palette.divider}`,
  color: 'white',
}));

const StyledToolbar = styled(Toolbar)({
  minHeight: '48px',
  padding: '0 16px',
  display: 'flex',
  justifyContent: 'space-between',
});

interface HeaderProps {
  user: spotify.UserProfile | null;
}

export function Header({ user }: HeaderProps) {
  const { currentMedia, setCurrentMedia } = useMedia();
  const { handleClearCreds } = useAuth();

  const handleChange = (_: React.SyntheticEvent, newValue: MediaType) => {
    setCurrentMedia(newValue);
  };

  return (
    <StyledAppBar position="sticky" elevation={0}>
      <StyledToolbar>
        <Tabs 
          value={currentMedia} 
          onChange={handleChange}
          textColor="inherit"
          sx={{ 
            '& .MuiTab-root': {
              color: 'white',
              '&.Mui-selected': {
                color: 'white',
              },
            },
            '& .MuiTabs-indicator': {
              backgroundColor: '#7B68EE',
            },
          }}
        >
          <Tab value="music" label="Music" />
          <Tab value="movies" label="Movies" />
        </Tabs>
        
        <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
          {currentMedia === 'music' && user && (
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              {user.images?.[0]?.url && (
                <Avatar 
                  src={user.images[0].url} 
                  sx={{ width: 32, height: 32 }}
                />
              )}
              <Typography variant="subtitle2" sx={{ color: 'white' }}>
                {user.display_name}
              </Typography>
              <Button
                variant="outlined"
                size="small"
                onClick={handleClearCreds}
                sx={{
                  color: 'white',
                  borderColor: 'white',
                  '&:hover': {
                    borderColor: 'white',
                    backgroundColor: 'rgba(255, 255, 255, 0.1)',
                  },
                }}
              >
                Clear Auth
              </Button>
            </Box>
          )}
        </Box>
      </StyledToolbar>
    </StyledAppBar>
  );
} 