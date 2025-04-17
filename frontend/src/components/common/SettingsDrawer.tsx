import React, { useEffect, useState } from "react";
import {
  Box,
  Drawer,
  FormControl,
  FormControlLabel,
  FormLabel,
  IconButton,
  MenuItem,
  Paper,
  Select,
  Stack,
  Switch,
  Tab,
  Tabs,
  TextField,
  Typography,
} from "@mui/material";
import { styled } from "@mui/material/styles";
import { FaTimes } from "react-icons/fa";
import {
  ClearGeminiToken,
  ClearOpenAIToken,
  ClearTMBDAccessToken,
  GetGeminiToken,
  GetOpenAIToken,
  GetTMBDAccessToken,
  SaveGeminiToken,
  SaveOpenAIToken,
  SaveTMBDAccessToken,
} from "@wailsjs/go/bindings/Auth";
import { RefreshCredentials } from "@wailsjs/go/bindings/Movies";
import { useSnackbar } from "notistack";
import { ApiCredentialsManager } from "@/components/common/ApiCredentialsManager";
import { useSettings, ChatGPTModel } from "@/contexts/SettingsContext";

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

const StyledSwitch = styled(Switch)(({ theme }) => ({
  "& .MuiSwitch-switchBase": {
    "&.Mui-checked": {
      color: "#7B68EE",
      "& + .MuiSwitch-track": {
        backgroundColor: "rgba(123, 104, 238, 0.5)",
      },
    },
  },
  "& .MuiSwitch-track": {
    backgroundColor: "rgba(255, 255, 255, 0.2)",
  },
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
  const [geminiKey, setGeminiKey] = useState("");
  const [tmdbKey, setTmdbKey] = useState("");

  const { enqueueSnackbar } = useSnackbar();
  const { 
    isContinuousPlayback,
    setContinuousPlayback,
    chatGPTModel,
    setChatGPTModel
  } = useSettings();

  // Create a wrapper for RefreshCredentials that returns void
  const refreshTmdbCredentials = async (): Promise<void> => {
    await RefreshCredentials();
  };

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
    const loadGeminiKey = async () => {
      try {
        const key = await GetGeminiToken();
        if (key) {
          setGeminiKey(key);
        }
      } catch (error) {
        console.error("Failed to load Gemini API key:", error);
      }
    };
    loadGeminiKey();
  }, []);

  useEffect(() => {
    const loadTmdbKey = async () => {
      try {
        const key = await GetTMBDAccessToken();
        if (key) {
          setTmdbKey(key);
        }
      } catch (error) {
        console.error("Failed to load TMDB token:", error);
      }
    };
    loadTmdbKey();
  }, []);

  useEffect(() => {
    console.log(
      `[SettingsDrawer] Continuous playback is: ${isContinuousPlayback}`,
    );
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
    if (value) {
      try {
        await SaveGeminiToken(value);
        enqueueSnackbar("Gemini API key saved", { variant: "success" });
      } catch (error) {
        console.error("Failed to save Gemini API key:", error);
        enqueueSnackbar("Failed to save Gemini API key", { variant: "error" });
      }
    }
  };

  const handleClearGeminiKey = async () => {
    try {
      await ClearGeminiToken();
      setGeminiKey("");
      enqueueSnackbar("Gemini API key cleared", { variant: "success" });
    } catch (error) {
      console.error("Failed to clear Gemini API key:", error);
      enqueueSnackbar("Failed to clear Gemini API key", { variant: "error" });
    }
  };

  const handleTmdbKeyChange = async (value: string) => {
    setTmdbKey(value);
    if (value) {
      try {
        await SaveTMBDAccessToken(value);
        enqueueSnackbar("TMDB token key saved", { variant: "success" });
      } catch (error) {
        console.error("Failed to save TMDB token:", error);
        enqueueSnackbar("Failed to save TMDB token", { variant: "error" });
      }
    }
  };

  const handleClearTmdbKey = async () => {
    try {
      await ClearTMBDAccessToken();
      setTmdbKey("");
      enqueueSnackbar("TMDB token cleared", { variant: "success" });
    } catch (error) {
      console.error("Failed to clear TMDB token:", error);
      enqueueSnackbar("Failed to clear TMDB token", { variant: "error" });
    }
  };

  const handleContinuousPlaybackToggle = async (
    event: React.ChangeEvent<HTMLInputElement>,
  ) => {
    const newValue = event.target.checked;
    console.log(`[SettingsDrawer] Toggle continuous playback to: ${newValue}`);

    try {
      await setContinuousPlayback(newValue);
      enqueueSnackbar(
        `Continuous playback ${newValue ? "enabled" : "disabled"}`,
        { variant: "success" },
      );
    } catch (error) {
      console.error(
        "[SettingsDrawer] Error setting continuous playback:",
        error,
      );
      enqueueSnackbar("Failed to update setting", { variant: "error" });
    }
  };

  return (
    <StyledDrawer anchor="right" open={open} onClose={onClose}>
      <Box
        sx={{
          p: 3,
          display: "flex",
          flexDirection: "column",
          alignItems: "flex-start",
          height: "100%",
        }}
      >
        <Box
          sx={{
            width: "100%",
            display: "flex",
            justifyContent: "flex-end",
            mb: 1,
          }}
        >
          <IconButton
            onClick={onClose}
            sx={{
              color: "white",
              padding: "4px",
              "&:hover": {
                backgroundColor: "rgba(255, 255, 255, 0.1)",
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
          <Box
            sx={{
              mt: 4,
              width: "100%",
              display: "flex",
              flexDirection: "column",
              gap: 3,
            }}
          >
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
                "& .MuiFormControlLabel-label": {
                  fontSize: "0.875rem",
                },
              }}
            />

            <FormControl fullWidth>
              <FormLabel
                sx={{
                  color: "rgba(255, 255, 255, 0.7)",
                  marginBottom: 1,
                  fontSize: "0.875rem",
                  textAlign: "left",
                }}
              >
                ChatGPT Model
              </FormLabel>
              <Select
                value={chatGPTModel}
                onChange={(e) => {
                  setChatGPTModel(e.target.value as ChatGPTModel);
                  enqueueSnackbar(`Model changed to ${e.target.value}`, { variant: "success" });
                }}
                sx={{
                  color: "white",
                  textAlign: "left",
                  "& .MuiSelect-select": {
                    paddingLeft: 2
                  },
                  "& .MuiOutlinedInput-notchedOutline": {
                    borderColor: "rgba(123, 104, 238, 0.3)"
                  },
                  "&:hover .MuiOutlinedInput-notchedOutline": {
                    borderColor: "rgba(123, 104, 238, 0.5)"
                  },
                  "& .MuiSelect-icon": {
                    color: "white"
                  }
                }}
                MenuProps={{
                  PaperProps: {
                    sx: {
                      backgroundColor: "rgba(30, 30, 30, 0.95)",
                      backdropFilter: "blur(10px)",
                      "& .MuiMenuItem-root": {
                        color: "white",
                        paddingLeft: 2
                      },
                      "& .MuiMenuItem-root.Mui-selected": {
                        backgroundColor: "rgba(123, 104, 238, 0.15)"
                      }
                    }
                  }
                }}
              >
                <MenuItem value="gpt-4o">GPT-4o (Default)</MenuItem>
                <MenuItem value="gpt-4o-mini">GPT-4o Mini (Faster)</MenuItem>
                <MenuItem value="gpt-4-turbo">GPT-4 Turbo (Long Context)</MenuItem>
              </Select>
            </FormControl>
          </Box>
        )}

        {activeTab === 1 && (
          <Box sx={{ mt: 4, width: "100%", overflow: "auto" }}>
            <SectionContainer>
              <BorderedSectionTitle>LLM APIs</BorderedSectionTitle>

              <Stack spacing={2}>
                <ApiCredentialsManager
                  label="OpenAI"
                  value={openAIKey}
                  onChange={handleOpenAIKeyChange}
                  onClear={handleClearOpenAIKey}
                />

                <ApiCredentialsManager
                  label="Gemini"
                  value={geminiKey}
                  onChange={handleGeminiKeyChange}
                  onClear={handleClearGeminiKey}
                />
              </Stack>
            </SectionContainer>

            <SectionContainer>
              <BorderedSectionTitle>Media APIs</BorderedSectionTitle>

              <ApiCredentialsManager
                label="TMDB"
                value={tmdbKey}
                onChange={handleTmdbKeyChange}
                onClear={handleClearTmdbKey}
                refreshHandler={refreshTmdbCredentials}
              />
            </SectionContainer>
          </Box>
        )}
      </Box>
    </StyledDrawer>
  );
}
