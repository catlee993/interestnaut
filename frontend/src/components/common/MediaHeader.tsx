import {
  AppBar,
  Toolbar,
  Tabs,
  Tab,
  Box,
  IconButton,
  styled,
} from "@mui/material";
import { useMedia, MediaType } from "@/contexts/MediaContext";
import { FaCog } from "react-icons/fa";
import { useState, useEffect } from "react";
import { SettingsDrawer } from "./SettingsDrawer";
import { SearchBar } from "./SearchBar";

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

interface MediaHeaderProps {
  additionalControl?: React.ReactNode | null;
  onSearch: (query: string) => void;
  onClearSearch?: () => void;
  currentMedia?: MediaType;
}

export function MediaHeader({ 
  additionalControl, 
  onSearch, 
  onClearSearch,
  currentMedia: externalMedia 
}: MediaHeaderProps) {
  const { currentMedia, setCurrentMedia } = useMedia();
  const [showSettingsDrawer, setShowSettingsDrawer] = useState(false);
  const [controlKey, setControlKey] = useState(0);

  // Use externally provided media type if available, otherwise use context
  const activeMedia = externalMedia !== undefined ? externalMedia : currentMedia;

  // Force refresh of additionalControl when it changes
  useEffect(() => {
    setControlKey(prev => prev + 1);
  }, [additionalControl]);

  const handleOpenSettings = () => {
    setShowSettingsDrawer(true);
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
            </Tabs>
          </Box>

          <Box sx={{ display: "flex", alignItems: "center", gap: 3 }}>
            <Box key={controlKey}>
              {additionalControl}
            </Box>

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
          </Box>
        </TopRow>

        <Box sx={{ p: 2, width: "100%" }}>
          <SearchBar
            placeholder={
              activeMedia === "music" ? "Search tracks..." : "Search movies..."
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
