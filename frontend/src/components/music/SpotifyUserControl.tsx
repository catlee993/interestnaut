import React from "react";
import { Box, Avatar, Typography, Button, CircularProgress } from "@mui/material";
import { styled } from "@mui/material/styles";
import { spotify } from "@wailsjs/go/models";
import { MediaType } from "@/contexts/MediaContext";

const StyledContainer = styled(Box)(({ theme }) => ({
  display: "flex",
  alignItems: "center",
  gap: "8px",
  padding: "2px 8px",
}));

interface SpotifyUserControlProps {
  user: spotify.UserProfile | null;
  onClearAuth: () => void;
  currentMedia: MediaType;
}

export function SpotifyUserControl({ user, onClearAuth, currentMedia }: SpotifyUserControlProps) {
  if (currentMedia !== "music") return null;

  // If we're in music media type but user is null, show a loading indicator
  if (!user) {
    return (
      <StyledContainer>
        <CircularProgress size={20} sx={{ color: "#1DB954" }} />
        <Typography variant="caption" sx={{ color: "#1DB954", fontSize: "0.75rem" }}>
          Loading user...
        </Typography>
      </StyledContainer>
    );
  }

  return (
    <StyledContainer>
      <Box sx={{ 
        display: 'flex', 
        flexDirection: 'column', 
        alignItems: 'flex-end',
        minWidth: '95px'
      }}>
        <Typography variant="caption" sx={{ 
          color: "#1DB954", 
          fontSize: "0.7rem", 
          lineHeight: 1.2, 
          textAlign: 'right',
          whiteSpace: 'nowrap'
        }}>
          Logged in as
        </Typography>
        <Typography variant="caption" sx={{ 
          color: "#1DB954", 
          fontSize: "0.75rem", 
          fontWeight: 600, 
          lineHeight: 1.2, 
          textAlign: 'right' 
        }}>
          {user.display_name || "Spotify User"}
        </Typography>
      </Box>
      {user.images?.[0]?.url ? (
        <Avatar
          src={user.images[0].url}
          sx={{ width: 24, height: 24 }}
        />
      ) : (
        <Avatar
          sx={{ width: 24, height: 24, backgroundColor: "#1DB954" }}
        >
          {(user.display_name || "S")[0].toUpperCase()}
        </Avatar>
      )}
      <Button
        variant="outlined"
        size="small"
        onClick={onClearAuth}
        sx={{
          color: 'var(--purple-red)',
          borderColor: 'var(--purple-red)',
          padding: "1px 8px",
          minWidth: "70px",
          fontSize: "0.7rem",
          height: "20px",
          whiteSpace: "nowrap",
          "&:hover": {
            borderColor: 'var(--purple-red)',
            backgroundColor: 'rgba(194, 59, 133, 0.1)',
          },
        }}
      >
        Clear Auth
      </Button>
    </StyledContainer>
  );
} 