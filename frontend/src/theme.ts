import { createTheme } from '@mui/material/styles';

export const theme = createTheme({
  palette: {
    primary: {
      main: '#1DB954', // Spotify green
    },
    secondary: {
      main: '#191414', // Spotify black
    },
    error: {
      main: '#ff4444',
    },
    warning: {
      main: '#ffbb33',
    },
    success: {
      main: '#00C851',
    },
    background: {
      default: '#121212',
      paper: '#282828',
    },
    text: {
      primary: '#ffffff',
      secondary: '#b3b3b3',
    },
  },
  components: {
    MuiButton: {
      styleOverrides: {
        root: {
          borderRadius: 20,
          textTransform: 'none',
          fontWeight: 600,
        },
      },
    },
    MuiCard: {
      styleOverrides: {
        root: {
          borderRadius: 12,
          backgroundColor: '#282828',
          color: '#ffffff',
        },
      },
    },
    MuiContainer: {
      styleOverrides: {
        root: {
          padding: '16px',
        },
      },
    },
    MuiTypography: {
      styleOverrides: {
        root: {
          color: '#ffffff',
        },
      },
    },
    MuiStack: {
      styleOverrides: {
        root: {
          width: '100%',
        },
      },
    },
    MuiSnackbarContent: {
      styleOverrides: {
        root: {
          backgroundColor: '#282828',
          color: '#ffffff',
        },
      },
    },
  },
}); 