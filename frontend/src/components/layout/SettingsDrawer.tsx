import React, { useState, useEffect } from "react";
import {
  Drawer,
  Box,
  Tabs,
  Tab,
  Typography,
  FormControlLabel,
  Switch,
  TextField,
  IconButton,
  Button,
} from "@mui/material";
import { styled } from "@mui/material/styles";
import { FaEye, FaEyeSlash, FaTimes } from "react-icons/fa";
import {
  SaveOpenAIToken,
  GetOpenAIToken,
  ClearOpenAIToken,
} from "@wailsjs/go/bindings/Auth";
import { useSnackbar } from "notistack";

const StyledDrawer = styled(Drawer)(({ theme }) => ({
  "& .MuiDrawer-paper": {
    width: 400,
    backgroundColor: "rgba(18, 18, 18, 0.95)",
    backdropFilter: "blur(10px)",
    borderLeft: "1px solid rgba(123, 104, 238, 0.3)",
  },
}));

const StyledTabs = styled(Tabs)(({ theme }) => ({
  "& .MuiTabs-indicator": {
    backgroundColor: "#7B68EE",
  },
  "& .MuiTab-root": {
    color: "white",
    "&.Mui-selected": {
      color: "white",
    },
  },
}));

const StyledTextField = styled(TextField)(({ theme }) => ({
  "& .MuiOutlinedInput-root": {
    color: "white",
    "& fieldset": {
      borderColor: "rgba(123, 104, 238, 0.3)",
    },
    "&:hover fieldset": {
      borderColor: "rgba(123, 104, 238, 0.5)",
    },
    "&.Mui-focused fieldset": {
      borderColor: "white",
    },
  },
  "& .MuiInputLabel-root": {
    color: "rgba(255, 255, 255, 0.7)",
  },
}));

const ClearButton = styled(Button)(({ theme }) => ({
  color: "#EF4444",
  borderColor: "#EF4444",
  "&:hover": {
    backgroundColor: "rgba(239, 68, 68, 0.1)",
    borderColor: "#EF4444",
  },
}));

const StyledSwitch = styled(Switch)(({ theme }) => ({
  '& .MuiSwitch-switchBase': {
    '&.Mui-checked': {
      color: '#7B68EE',
      '& + .MuiSwitch-track': {
        backgroundColor: 'rgba(123, 104, 238, 0.5)',
      },
    },
  },
  '& .MuiSwitch-track': {
    backgroundColor: 'rgba(255, 255, 255, 0.2)',
  },
}));

interface SettingsDrawerProps {
  open: boolean;
  onClose: () => void;
}

export function SettingsDrawer({ open, onClose }: SettingsDrawerProps) {
  const [activeTab, setActiveTab] = useState(0);
  const [authTab, setAuthTab] = useState(0);
  const [openAIKey, setOpenAIKey] = useState("");
  const [showOpenAIKey, setShowOpenAIKey] = useState(false);
  const [continuePlaying, setContinuePlaying] = useState(false);
  const { enqueueSnackbar } = useSnackbar();

  useEffect(() => {
    const loadOpenAIKey = async () => {
      try {
        const key = await GetOpenAIToken();
        if (key) {
          setOpenAIKey(key);
        }
      } catch (error) {
        console.error("Failed to load OpenAI API key:", error);
      }
    };
    loadOpenAIKey();
  }, []);

  const handleTabChange = (_: React.SyntheticEvent, newValue: number) => {
    setActiveTab(newValue);
  };

  const handleAuthTabChange = (_: React.SyntheticEvent, newValue: number) => {
    setAuthTab(newValue);
  };

  const handleOpenAIKeyChange = async (value: string) => {
    setOpenAIKey(value);
    if (value) {
      try {
        await SaveOpenAIToken(value);
        enqueueSnackbar("OpenAI API key saved", { variant: "success" });
      } catch (error) {
        console.error("Failed to save OpenAI API key:", error);
        enqueueSnackbar("Failed to save OpenAI API key", { variant: "error" });
      }
    }
  };

  const handleClearOpenAIKey = async () => {
    try {
      await ClearOpenAIToken();
      setOpenAIKey("");
      enqueueSnackbar("OpenAI API key cleared", { variant: "success" });
    } catch (error) {
      console.error("Failed to clear OpenAI API key:", error);
      enqueueSnackbar("Failed to clear OpenAI API key", { variant: "error" });
    }
  };

  return (
    <StyledDrawer anchor="right" open={open} onClose={onClose}>
      <Box sx={{ p: 2, display: 'flex', flexDirection: 'column', alignItems: 'flex-start' }}>
        <Box sx={{ width: '100%', display: 'flex', justifyContent: 'flex-end', mb: 1 }}>
          <IconButton
            onClick={onClose}
            sx={{
              color: 'white',
              padding: '4px',
              '&:hover': {
                backgroundColor: 'rgba(255, 255, 255, 0.1)',
              },
            }}
          >
            <FaTimes size={14} />
          </IconButton>
        </Box>
        <StyledTabs value={activeTab} onChange={handleTabChange}>
          <Tab label="Settings" />
          <Tab label="Authentication" />
        </StyledTabs>

        {activeTab === 0 && (
          <Box sx={{ mt: 4, width: '100%', display: 'flex', justifyContent: 'flex-start' }}>
            <FormControlLabel
              control={
                <StyledSwitch
                  checked={continuePlaying}
                  onChange={(e) => setContinuePlaying(e.target.checked)}
                />
              }
              label="Continue playing liked songs"
              sx={{ 
                color: "white",
                margin: 0,
                '& .MuiFormControlLabel-label': {
                  fontSize: '0.875rem',
                }
              }}
            />
          </Box>
        )}

        {activeTab === 1 && (
          <Box sx={{ mt: 4, width: '100%' }}>
            <StyledTabs value={authTab} onChange={handleAuthTabChange}>
              <Tab label="OpenAI" />
              <Tab label="Gemini" />
              <Tab label="TMDB" />
            </StyledTabs>

            {authTab === 0 && (
              <Box sx={{ mt: 4, width: '100%' }}>
                <Box sx={{ display: "flex", gap: 1, alignItems: "center", width: '100%' }}>
                  <StyledTextField
                    label="OpenAI API Key"
                    type={showOpenAIKey ? "text" : "password"}
                    value={openAIKey ? (showOpenAIKey ? openAIKey : "********") : ""}
                    onChange={(e) => handleOpenAIKeyChange(e.target.value)}
                    size="small"
                    sx={{ flex: 1 }}
                  />
                  <IconButton
                    onClick={() => setShowOpenAIKey(!showOpenAIKey)}
                    sx={{ color: "white" }}
                  >
                    {showOpenAIKey ? <FaEyeSlash /> : <FaEye />}
                  </IconButton>
                  <ClearButton
                    variant="outlined"
                    size="small"
                    onClick={handleClearOpenAIKey}
                  >
                    Clear
                  </ClearButton>
                </Box>
              </Box>
            )}
          </Box>
        )}
      </Box>
    </StyledDrawer>
  );
} 