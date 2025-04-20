import {
  AppBar,
  Toolbar,
  Box,
  IconButton,
  styled,
  Typography,
  Menu,
  MenuItem,
} from "@mui/material";
import { useMedia, MediaType } from "@/contexts/MediaContext";
import { FaCog, FaChevronDown } from "react-icons/fa";
import { useState, useEffect, useRef } from "react";
import { SettingsDrawer } from "./SettingsDrawer";
import { SearchBar } from "./SearchBar";
import interestnautLogo from "../../assets/images/logo/interestnaut-mascot.png";

const StyledAppBar = styled(AppBar)(({ theme }) => ({
  background: "rgba(18, 18, 18, 0.95)",
  backdropFilter: "blur(10px)",
  borderBottom: `1px solid ${theme.palette.divider}`,
  color: "white",
}));

const StyledToolbar = styled(Toolbar)({
  minHeight: "32px",
  padding: "8px 8px 0 8px",
  display: "flex",
  flexDirection: "column",
  alignItems: "stretch",
});

const TopRow = styled(Box)({
  display: "flex",
  justifyContent: "space-between",
  alignItems: "center",
  width: "100%",
  padding: "6px 0 2px 0",
  height: "46px",
});

// Styled logo text
const LogoText = styled(Typography)({
  fontFamily: "'Inter', sans-serif",
  fontWeight: 300,
  background: "linear-gradient(45deg, #c165dd 30%, #9880ff 90%)",
  backgroundClip: "text",
  WebkitBackgroundClip: "text",
  WebkitTextFillColor: "transparent",
  marginLeft: "4px",
  fontSize: "0.875rem",
  letterSpacing: "1px",
  textTransform: "uppercase",
  lineHeight: 1,
  paddingBottom: "2px",
  fontStretch: "expanded",
});

// Logo container to hold both the image and text
const LogoContainer = styled(Box)({
  display: "flex",
  alignItems: "center",
  position: "absolute",
  left: "50%",
  transform: "translateX(-50%)",
});

// Left section container
const LeftSection = styled(Box)({
  display: "flex",
  alignItems: "center",
  width: "200px", // Fixed width to ensure consistent spacing
});

// Center section container
const CenterSection = styled(Box)({
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  flex: 1,
  position: "relative", // For absolute positioning of logo container
});

// Right section container
const RightSection = styled(Box)({
  display: "flex",
  alignItems: "center",
  gap: "12px",
  width: "200px", // Fixed width to balance with LeftSection
  justifyContent: "flex-end",
  height: "100%",
});

// Media selector styles
const MediaSelector = styled(Box)(({ theme }) => ({
  cursor: "pointer",
  display: "flex",
  alignItems: "center",
  padding: "6px 12px",
  borderRadius: "4px",
  "&:hover": {
    backgroundColor: "rgba(255, 255, 255, 0.1)",
  },
}));

const MediaSelectorText = styled(Typography)({
  color: "white",
  fontSize: "0.875rem",
  fontWeight: 300,
  letterSpacing: "1px",
  marginRight: "8px",
  textTransform: "uppercase",
  fontStretch: "expanded",
});

interface MediaHeaderProps {
  additionalControl?: React.ReactNode | null;
  onSearch: (query: string) => void;
  onClearSearch?: () => void;
  currentMedia?: "music" | "movies" | "tv" | "games" | "books";
  onMediaChange?: (media: "music" | "movies" | "tv" | "games" | "books") => void;
}

export function MediaHeader({
  additionalControl,
  onSearch,
  onClearSearch,
  currentMedia: externalMedia,
  onMediaChange,
}: MediaHeaderProps) {
  const { currentMedia, setCurrentMedia } = useMedia();
  const [showSettingsDrawer, setShowSettingsDrawer] = useState(false);
  const [controlKey, setControlKey] = useState(0);
  const [menuAnchor, setMenuAnchor] = useState<null | HTMLElement>(null);
  
  // Use externally provided media type if available, otherwise use context
  const activeMedia =
    externalMedia !== undefined ? externalMedia : currentMedia;

  // Force refresh of additionalControl when it changes
  useEffect(() => {
    setControlKey((prev) => prev + 1);
  }, [additionalControl]);

  const handleOpenSettings = () => {
    setShowSettingsDrawer(true);
  };

  const handleOpenMenu = (event: React.MouseEvent<HTMLElement>) => {
    setMenuAnchor(event.currentTarget);
  };

  const handleCloseMenu = () => {
    setMenuAnchor(null);
  };

  const handleMediaChange = (media: MediaType) => {
    // Update both the external state and context state
    if (onMediaChange) {
      onMediaChange(media);
    } else {
      setCurrentMedia(media);
    }
    handleCloseMenu();
  };

  // Function to get display name for the media type
  const getMediaDisplayName = (mediaType: MediaType): string => {
    switch (mediaType) {
      case "music": return "MUSIC";
      case "movies": return "MOVIES";
      case "tv": return "SHOWS";
      case "games": return "GAMES";
      case "books": return "BOOKS";
      default: return "Media";
    }
  };

  return (
    <StyledAppBar position="sticky" elevation={0}>
      <StyledToolbar>
        <TopRow>
          <LeftSection>
            <MediaSelector onClick={handleOpenMenu}>
              <MediaSelectorText>
                {getMediaDisplayName(activeMedia)}
              </MediaSelectorText>
              <FaChevronDown size={12} color="white" />
            </MediaSelector>
            <Menu
              anchorEl={menuAnchor}
              open={Boolean(menuAnchor)}
              onClose={handleCloseMenu}
              anchorOrigin={{
                vertical: "bottom",
                horizontal: "left",
              }}
              transformOrigin={{
                vertical: "top",
                horizontal: "left",
              }}
              sx={{
                "& .MuiPaper-root": {
                  backgroundColor: "rgba(18, 18, 18, 0.95)",
                  backdropFilter: "blur(10px)",
                  border: "1px solid rgba(255, 255, 255, 0.1)",
                  marginTop: "4px",
                },
                "& .MuiMenuItem-root": {
                  padding: "6px 12px", // Match the padding of MediaSelector
                },
              }}
            >
              <MenuItem 
                onClick={() => handleMediaChange("music")}
                selected={activeMedia === "music"}
                sx={{ 
                  fontSize: "0.875rem", 
                  fontWeight: 300,
                  letterSpacing: "1px",
                  textTransform: "uppercase",
                  fontStretch: "expanded",
                  minWidth: "120px",
                  lineHeight: 1
                }}
              >
                Music
              </MenuItem>
              <MenuItem 
                onClick={() => handleMediaChange("movies")}
                selected={activeMedia === "movies"}
                sx={{ 
                  fontSize: "0.875rem", 
                  fontWeight: 300,
                  letterSpacing: "1px",
                  textTransform: "uppercase",
                  fontStretch: "expanded",
                  lineHeight: 1
                }}
              >
                Movies
              </MenuItem>
              <MenuItem 
                onClick={() => handleMediaChange("tv")}
                selected={activeMedia === "tv"}
                sx={{ 
                  fontSize: "0.875rem", 
                  fontWeight: 300,
                  letterSpacing: "1px",
                  textTransform: "uppercase",
                  fontStretch: "expanded",
                  lineHeight: 1
                }}
              >
                TV Shows
              </MenuItem>
              <MenuItem 
                onClick={() => handleMediaChange("games")}
                selected={activeMedia === "games"}
                sx={{ 
                  fontSize: "0.875rem", 
                  fontWeight: 300,
                  letterSpacing: "1px",
                  textTransform: "uppercase",
                  fontStretch: "expanded",
                  lineHeight: 1
                }}
              >
                Games
              </MenuItem>
              <MenuItem 
                onClick={() => handleMediaChange("books")}
                selected={activeMedia === "books"}
                sx={{ 
                  fontSize: "0.875rem", 
                  fontWeight: 300,
                  letterSpacing: "1px",
                  textTransform: "uppercase",
                  fontStretch: "expanded",
                  lineHeight: 1
                }}
              >
                Books
              </MenuItem>
            </Menu>
          </LeftSection>

          <CenterSection>
            <LogoContainer>
              <LogoText>interestnaut</LogoText>
              <img
                src={interestnautLogo}
                alt="Interestnaut Logo"
                style={{
                  height: "28px",
                  width: "28px",
                  marginLeft: "6px",
                  marginBottom: "4px", // Move astronaut down a bit
                }}
              />
            </LogoContainer>
          </CenterSection>

          <RightSection>
            <Box key={controlKey} sx={{ display: "flex", alignItems: "center", height: "100%" }}>
              {additionalControl}
            </Box>

            <IconButton
              size="small"
              onClick={handleOpenSettings}
              sx={{
                color: "var(--primary-color)",
                padding: "2px",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                "&:hover": {
                  backgroundColor: "rgba(123, 104, 238, 0.1)",
                },
              }}
            >
              <FaCog size={20} />
            </IconButton>
          </RightSection>
        </TopRow>

        <Box sx={{ py: 1, px: 2, width: "100%" }}>
          <SearchBar
            placeholder={
              activeMedia === "music"
                ? "Search tracks..."
                : activeMedia === "movies"
                  ? "Search movies..."
                  : activeMedia === "tv"
                    ? "Search TV shows..."
                    : activeMedia === "books"
                      ? "Search books..."
                      : "Search games..."
            }
            onSearch={onSearch}
            onClear={onClearSearch}
          />
        </Box>
      </StyledToolbar>

      <SettingsDrawer
        open={showSettingsDrawer}
        onClose={() => setShowSettingsDrawer(false)}
      />
    </StyledAppBar>
  );
}
