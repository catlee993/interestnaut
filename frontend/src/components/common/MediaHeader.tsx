import {
  AppBar,
  Toolbar,
  Tabs,
  Tab,
  Box,
  IconButton,
  styled,
  Typography,
} from "@mui/material";
import { useMedia, MediaType } from "@/contexts/MediaContext";
import { FaCog } from "react-icons/fa";
import { useState, useEffect } from "react";
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

// Styled logo text
const LogoText = styled(Typography)({
  fontFamily: "'Inter', sans-serif",
  fontWeight: 300,
  background: "linear-gradient(45deg, #c165dd 30%, #9880ff 90%)",
  backgroundClip: "text",
  WebkitBackgroundClip: "text",
  WebkitTextFillColor: "transparent",
  marginLeft: "4px",
  fontSize: "0.95rem",
  letterSpacing: "0.5px",
  textTransform: "uppercase",
  lineHeight: 1,
  paddingBottom: "2px",
});

// Logo container to hold both the image and text
const LogoContainer = styled(Box)({
  display: "flex",
  alignItems: "flex-end",
});

// Left section container
const LeftSection = styled(Box)({
  display: "flex",
  alignItems: "center",
});

// Center section container
const CenterSection = styled(Box)({
  display: "flex",
  alignItems: "center",
  justifyContent: "center",
  flex: 1,
});

// Right section container
const RightSection = styled(Box)({
  display: "flex",
  alignItems: "center",
  gap: "12px",
});

interface MediaHeaderProps {
  additionalControl?: React.ReactNode | null;
  onSearch: (query: string) => void;
  onClearSearch?: () => void;
  currentMedia?: "music" | "movies" | "tv" | "games";
  onMediaChange?: (media: "music" | "movies" | "tv" | "games") => void;
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

  const handleChange = (_: React.SyntheticEvent, newValue: any) => {
    // Update both the external state and context state
    if (onMediaChange) {
      onMediaChange(newValue);
    } else {
      setCurrentMedia(newValue);
    }
  };

  return (
    <StyledAppBar position="sticky" elevation={0}>
      <StyledToolbar>
        <TopRow>
          <LeftSection>
            <Tabs
              value={activeMedia}
              onChange={handleChange}
              textColor="inherit"
              sx={{
                "& .MuiTab-root": {
                  color: "white",
                  "&.Mui-selected": {
                    color: "white",
                  },
                  minHeight: "52px",
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
              <Tab value="tv" label="Shows" />
              <Tab value="games" label="Games" />
            </Tabs>
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
                }}
              />
            </LogoContainer>
          </CenterSection>

          <RightSection>
            <Box key={controlKey}>{additionalControl}</Box>

            <IconButton
              size="small"
              onClick={handleOpenSettings}
              sx={{
                color: "var(--primary-color)",
                padding: "2px",
                "&:hover": {
                  backgroundColor: "rgba(123, 104, 238, 0.1)",
                },
              }}
            >
              <FaCog size={20} />
            </IconButton>
          </RightSection>
        </TopRow>

        <Box sx={{ p: 2, width: "100%" }}>
          <SearchBar
            placeholder={
              activeMedia === "music"
                ? "Search tracks..."
                : activeMedia === "movies"
                  ? "Search movies..."
                  : activeMedia === "tv"
                    ? "Search TV shows..."
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
