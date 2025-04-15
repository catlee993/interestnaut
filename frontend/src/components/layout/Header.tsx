import {
  AppBar,
  Toolbar,
  Tabs,
  Tab,
  Box,
  Avatar,
  Typography,
  Button,
  Menu,
  MenuItem,
  IconButton,
} from "@mui/material";
import { styled } from "@mui/material/styles";
import { useMedia, MediaType } from "@/contexts/MediaContext";
import { spotify } from "@wailsjs/go/models";
import { useAuth } from "@/components/music/hooks/useAuth";
import { SearchSection } from "@/components/music/search/SearchSection";
import { OpenAICredsManager } from "@/components/common/OpenAICredsManager";
import { useState } from "react";
import { FaTimes, FaCog } from "react-icons/fa";
import { SettingsDrawer } from "./SettingsDrawer";
import { SpotifyUserControl } from "@/components/music/SpotifyUserControl";

const StyledAppBar = styled(AppBar)(({ theme }) => ({
  background: "rgba(18, 18, 18, 0.95)",
  backdropFilter: "blur(10px)",
  borderBottom: `1px solid ${theme.palette.divider}`,
  color: "white",
}));

const StyledToolbar = styled(Toolbar)({
  minHeight: "32px",
  padding: "0 8px",
  display: "flex",
  flexDirection: "column",
  alignItems: "stretch",
});

const TopRow = styled(Box)({
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  width: "100%",
  padding: "2px 0",
});

interface HeaderProps {
  user: spotify.UserProfile | null;
  onSearch: (query: string) => Promise<void>;
}

export function Header({ user, onSearch }: HeaderProps) {
  const { currentMedia, setCurrentMedia } = useMedia();
  const { handleClearCreds } = useAuth();
  const [anchorEl, setAnchorEl] = useState<null | HTMLElement>(null);
  const [showSettings, setShowSettings] = useState(false);

  const handleMenuClick = (event: React.MouseEvent<HTMLElement>) => {
    setAnchorEl(event.currentTarget);
  };

  const handleMenuClose = () => {
    setAnchorEl(null);
  };

  const handleOpenSettings = () => {
    setShowSettings(true);
    handleMenuClose();
  };

  const handleChange = (_: React.SyntheticEvent, newValue: MediaType) => {
    setCurrentMedia(newValue);
  };

  return (
    <StyledAppBar position="sticky" elevation={0}>
      <StyledToolbar>
        <TopRow>
          <Box sx={{ display: "flex", alignItems: "center", gap: 1 }}>
            <Tabs
              value={currentMedia}
              onChange={handleChange}
              textColor="inherit"
              sx={{
                "& .MuiTab-root": {
                  color: "white",
                  "&.Mui-selected": {
                    color: "white",
                  },
                  minHeight: "48px",
                  padding: "6px 12px",
                  fontSize: "0.875rem",
                },
                "& .MuiTabs-indicator": {
                  backgroundColor: "#7B68EE",
                },
              }}
            >
              <Tab value="music" label="Music" />
              <Tab value="movies" label="Movies" />
            </Tabs>
          </Box>

          <Box sx={{ display: "flex", alignItems: "center", gap: 3 }}>
            {currentMedia === "music" && user && (
              <>
                <SpotifyUserControl
                  user={user}
                  onClearAuth={handleClearCreds}
                  currentMedia={currentMedia}
                />
                <IconButton
                  size="small"
                  onClick={handleOpenSettings}
                  sx={{
                    color: "#A855F7",
                    padding: "2px",
                    "&:hover": {
                      backgroundColor: "rgba(168, 85, 247, 0.1)",
                    },
                  }}
                >
                  <FaCog size={20} />
                </IconButton>
              </>
            )}
          </Box>
        </TopRow>

        {currentMedia === "music" && <SearchSection />}
      </StyledToolbar>

      <SettingsDrawer
        open={showSettings}
        onClose={() => setShowSettings(false)}
      />
    </StyledAppBar>
  );
}
