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
  Divider,
  Paper,
} from "@mui/material";
import { styled } from "@mui/material/styles";
import { FaEye, FaEyeSlash, FaTimes } from "react-icons/fa";
import {
  SaveOpenAIToken,
  GetOpenAIToken,
  ClearOpenAIToken,
} from "@wailsjs/go/bindings/Auth";
import { useSnackbar } from "notistack";
import { usePlayer } from "@/components/music/player/PlayerContext";

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

// Title for credential sections
const SectionTitle = styled(Typography)(({ theme }) => ({
  color: "white",
  fontSize: "1rem",
  fontWeight: 500,
  marginBottom: theme.spacing(2),
  marginTop: theme.spacing(3),
}));

// Section container with light border
const SectionContainer = styled(Paper)(({ theme }) => ({
  backgroundColor: "transparent",
  border: "1px solid rgba(123, 104, 238, 0.2)",
  borderRadius: theme.shape.borderRadius,
  padding: theme.spacing(2),
  marginBottom: theme.spacing(3),
  width: "100%",
}));

// Section title that overlays the border
const BorderedSectionTitle = styled(Typography)(({ theme }) => ({
  color: "white",
  fontSize: "0.875rem",
  fontWeight: 500,
  backgroundColor: "rgba(18, 18, 18, 0.95)",
  padding: "0 8px",
  position: "relative",
  top: -22,
  left: 12,
  display: "inline-block",
  marginBottom: -14,
}));

interface SettingsDrawerProps {
  open: boolean;
  onClose: () => void;
}

export function SettingsDrawer({ open, onClose }: SettingsDrawerProps) {
  const [activeTab, setActiveTab] = useState(0);
  const [openAIKey, setOpenAIKey] = useState("");
  const [showOpenAIKey, setShowOpenAIKey] = useState(false);
  // For future credential managers
  const [geminiKey, setGeminiKey] = useState("");
  const [showGeminiKey, setShowGeminiKey] = useState(false);
  const [tmdbKey, setTmdbKey] = useState("");
  const [showTmdbKey, setShowTmdbKey] = useState(false);
  
  const { isContinuousPlayback, setContinuousPlayback } = usePlayer();
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

  useEffect(() => {
    console.log(`[SettingsDrawer] Continuous playback is: ${isContinuousPlayback}`);
  }, [isContinuousPlayback]);

  const handleTabChange = (_event: React.SyntheticEvent, newValue: number) => {
    setActiveTab(newValue);
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

  // Placeholder handlers for future APIs
  const handleGeminiKeyChange = async (value: string) => {
    setGeminiKey(value);
    enqueueSnackbar("Gemini API integration coming soon", { variant: "info" });
  };

  const handleClearGeminiKey = async () => {
    setGeminiKey("");
    enqueueSnackbar("Gemini API integration coming soon", { variant: "info" });
  };

  const handleTmdbKeyChange = async (value: string) => {
    setTmdbKey(value);
    enqueueSnackbar("TMDB API integration coming soon", { variant: "info" });
  };

  const handleClearTmdbKey = async () => {
    setTmdbKey("");
    enqueueSnackbar("TMDB API integration coming soon", { variant: "info" });
  };

  const handleContinuousPlaybackToggle = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const newValue = event.target.checked;
    console.log(`[SettingsDrawer] Toggle continuous playback to: ${newValue}`);
    
    try {
      await setContinuousPlayback(newValue);
      enqueueSnackbar(`Continuous playback ${newValue ? 'enabled' : 'disabled'}`, { 
        variant: "success" 
      });
    } catch (error) {
      console.error('[SettingsDrawer] Error setting continuous playback:', error);
      enqueueSnackbar(`Failed to ${newValue ? 'enable' : 'disable'} continuous playback`, { 
        variant: "error" 
      });
    }
  };

  // Reusable credential manager component
  interface CredentialManagerProps {
    label: string;
    value: string;
    showValue: boolean;
    onToggleShow: () => void;
    onChange: (value: string) => void;
    onClear: () => void;
    disabled?: boolean;
  }

  const CredentialManager = ({ 
    label, 
    value, 
    showValue, 
    onToggleShow, 
    onChange, 
    onClear,
    disabled = false
  }: CredentialManagerProps) => (
    <Box sx={{ mb: 2 }}>
      <Typography sx={{ color: 'white', mb: 1, fontSize: '0.875rem' }}>
        {label}
      </Typography>
      <Box sx={{ display: "flex", gap: 1, alignItems: "center", width: '100%' }}>
        <StyledTextField
          type={showValue ? "text" : "password"}
          value={value ? (showValue ? value : "********") : ""}
          onChange={(e) => onChange(e.target.value)}
          size="small"
          placeholder={`Enter your ${label} API key`}
          disabled={disabled}
          sx={{ flex: 1 }}
        />
        <IconButton
          onClick={onToggleShow}
          sx={{ color: "white" }}
          disabled={disabled}
        >
          {showValue ? <FaEyeSlash /> : <FaEye />}
        </IconButton>
        <ClearButton
          variant="outlined"
          size="small"
          onClick={onClear}
          disabled={disabled || !value}
        >
          Clear
        </ClearButton>
      </Box>
    </Box>
  );

  return (
    <StyledDrawer anchor="right" open={open} onClose={onClose}>
      <Box sx={{ p: 3, display: 'flex', flexDirection: 'column', alignItems: 'flex-start', height: '100%' }}>
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
                  checked={isContinuousPlayback}
                  onChange={handleContinuousPlaybackToggle}
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
          <Box sx={{ mt: 4, width: '100%', overflow: 'auto' }}>
            <SectionContainer>
              <BorderedSectionTitle>LLM APIs</BorderedSectionTitle>
              
              <CredentialManager
                label="OpenAI API"
                value={openAIKey}
                showValue={showOpenAIKey}
                onToggleShow={() => setShowOpenAIKey(!showOpenAIKey)}
                onChange={handleOpenAIKeyChange}
                onClear={handleClearOpenAIKey}
              />
              
              <CredentialManager
                label="Gemini API"
                value={geminiKey}
                showValue={showGeminiKey}
                onToggleShow={() => setShowGeminiKey(!showGeminiKey)}
                onChange={handleGeminiKeyChange}
                onClear={handleClearGeminiKey}
                disabled={true}
              />
            </SectionContainer>
            
            <SectionContainer>
              <BorderedSectionTitle>Media APIs</BorderedSectionTitle>
              
              <CredentialManager
                label="TMDB API"
                value={tmdbKey}
                showValue={showTmdbKey}
                onToggleShow={() => setShowTmdbKey(!showTmdbKey)}
                onChange={handleTmdbKeyChange}
                onClear={handleClearTmdbKey}
                disabled={true}
              />
            </SectionContainer>
          </Box>
        )}
      </Box>
    </StyledDrawer>
  );
} 