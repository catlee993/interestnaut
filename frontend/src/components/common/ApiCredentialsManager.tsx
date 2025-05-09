import React, { useState, useEffect } from "react";
import { Box, IconButton, TextField, Button } from "@mui/material";
import { styled } from "@mui/material/styles";
import { FaEye, FaEyeSlash } from "react-icons/fa";
import { useSnackbar } from "notistack";

// Styled components matching the SettingsDrawer styling
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
  color: "var(--purple-red)",
  borderColor: "var(--purple-red)",
  "&:hover": {
    backgroundColor: "rgba(194, 59, 133, 0.1)",
    borderColor: "var(--purple-red)",
  },
}));

interface ApiCredentialsManagerProps {
  label: string;
  value: string;
  onChange: (value: string) => Promise<void>;
  onClear: () => Promise<void>;
  onLoad?: () => Promise<string>;
  placeholderText?: string;
  disabled?: boolean;
  refreshHandler?: () => Promise<void>;
}

export function ApiCredentialsManager({
  label,
  value,
  onChange,
  onClear,
  onLoad,
  placeholderText = "",
  disabled = false,
  refreshHandler,
}: ApiCredentialsManagerProps) {
  const [apiKey, setApiKey] = useState(value);
  const [showApiKey, setShowApiKey] = useState(false);
  const { enqueueSnackbar } = useSnackbar();

  // Load API key on component mount if onLoad is provided
  useEffect(() => {
    if (onLoad) {
      const loadApiKey = async () => {
        try {
          const key = await onLoad();
          if (key) {
            setApiKey(key);
          }
        } catch (error) {
          console.error(`Failed to load ${label} API key:`, error);
        }
      };
      loadApiKey();
    }
  }, [onLoad, label]);

  // Update internal state when external value changes
  useEffect(() => {
    setApiKey(value);
  }, [value]);

  const handleApiKeyChange = async (newValue: string) => {
    setApiKey(newValue);
    if (newValue) {
      try {
        await onChange(newValue);
        // Call the refresh handler if provided
        if (refreshHandler) {
          await refreshHandler();
        }
        enqueueSnackbar(`${label} API key saved`, { variant: "success" });
      } catch (error) {
        console.error(`Failed to save ${label} API key:`, error);
        enqueueSnackbar(`Failed to save ${label} API key`, { variant: "error" });
      }
    }
  };

  const handleClearApiKey = async () => {
    try {
      await onClear();
      // Call the refresh handler if provided
      if (refreshHandler) {
        await refreshHandler();
      }
      setApiKey("");
      enqueueSnackbar(`${label} API key cleared`, { variant: "success" });
    } catch (error) {
      console.error(`Failed to clear ${label} API key:`, error);
      enqueueSnackbar(`Failed to clear ${label} API key`, { variant: "error" });
    }
  };

  // If the value is censored, we don't want to display the actual key
  const displayValue = apiKey && !showApiKey ? "********" : apiKey;

  return (
    <Box sx={{ display: "flex", gap: 1, alignItems: "center", width: '100%' }}>
      <StyledTextField
        label={`${label} API Key`}
        type={showApiKey ? "text" : "password"}
        value={displayValue}
        onChange={(e) => handleApiKeyChange(e.target.value)}
        size="small"
        placeholder={placeholderText}
        disabled={disabled}
        sx={{ flex: 1 }}
      />
      <IconButton
        onClick={() => setShowApiKey(!showApiKey)}
        sx={{ color: "white" }}
        disabled={disabled}
      >
        {showApiKey ? <FaEyeSlash /> : <FaEye />}
      </IconButton>
      <ClearButton
        variant="outlined"
        size="small"
        onClick={handleClearApiKey}
        disabled={disabled || !apiKey}
      >
        Clear
      </ClearButton>
    </Box>
  );
} 