import React from "react";
import { Box, Avatar, Typography, Button, CircularProgress } from "@mui/material";
import { styled } from "@mui/material/styles";
import { spotify } from "@wailsjs/go/models";
import { MediaType } from "@/contexts/MediaContext";

const StyledContainer = styled(Box)(({ theme }) => ({
  display: "flex",
  alignItems: "center",
  gap: "8px",
  padding: "4px 8px",
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
        <CircularProgress size={24} sx={{ color: "#1DB954" }} />
        <Typography variant="subtitle2" sx={{ color: "#1DB954", fontSize: "0.875rem" }}>
          Loading user...
        </Typography>
      </StyledContainer>
    );
  }

  return (
    <StyledContainer>
      <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end' }}>
        <Typography variant="subtitle2" sx={{ color: "#1DB954", fontSize: "0.875rem", textAlign: 'right' }}>
          Logged in as
        </Typography>
        <Typography variant="subtitle2" sx={{ color: "#1DB954", fontSize: "0.875rem", fontWeight: 600, textAlign: 'right' }}>
          {user.display_name || "Spotify User"}
        </Typography>
      </Box>
      {user.images?.[0]?.url ? (
        <Avatar
          src={user.images[0].url}
          sx={{ width: 28, height: 28 }}
        />
      ) : (
        <Avatar
          sx={{ width: 28, height: 28, backgroundColor: "#1DB954" }}
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
          padding: "2px 8px",
          minWidth: "auto",
          fontSize: "0.75rem",
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