import React, { useState, useEffect } from "react";
import { Box, Button, TextField, Typography, Paper } from "@mui/material";
import { styled } from "@mui/material/styles";
import { useSnackbar } from "notistack";
import {
  SaveOpenAIToken,
  GetOpenAIToken,
  ClearOpenAIToken,
} from "@wailsjs/go/bindings/Auth";

const StyledPaper = styled(Paper)(({ theme }) => ({
  padding: theme.spacing(2),
  backgroundColor: "rgba(18, 18, 18, 0.95)",
  backdropFilter: "blur(10px)",
  border: "1px solid rgba(123, 104, 238, 0.3)",
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
      borderColor: "rgba(123, 104, 238, 0.7)",
    },
  },
  "& .MuiInputLabel-root": {
    color: "rgba(255, 255, 255, 0.7)",
  },
}));

const SaveButton = styled(Button)(({ theme }) => ({
  color: "#A855F7",
  borderColor: "#A855F7",
  "&:hover": {
    backgroundColor: "rgba(168, 85, 247, 0.1)",
    borderColor: "#A855F7",
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

export function OpenAICredsManager() {
  const [apiKey, setApiKey] = useState("");
  const { enqueueSnackbar } = useSnackbar();

  useEffect(() => {
    const loadApiKey = async () => {
      try {
        const key = await GetOpenAIToken();
        if (key) {
          setApiKey(key);
        }
      } catch (error) {
        console.error("Failed to load OpenAI API key:", error);
      }
    };
    loadApiKey();
  }, []);

  const handleSave = async () => {
    try {
      await SaveOpenAIToken(apiKey);
      enqueueSnackbar("OpenAI API key saved successfully", {
        variant: "success",
      });
    } catch (error) {
      console.error("Failed to save OpenAI API key:", error);
      enqueueSnackbar("Failed to save OpenAI API key", { variant: "error" });
    }
  };

  const handleClear = async () => {
    try {
      await ClearOpenAIToken();
      setApiKey("");
      enqueueSnackbar("OpenAI API key cleared", { variant: "success" });
    } catch (error) {
      console.error("Failed to clear OpenAI API key:", error);
      enqueueSnackbar("Failed to clear OpenAI API key", { variant: "error" });
    }
  };

  return (
    <StyledPaper>
      <Typography variant="h6" sx={{ mb: 2, color: "white" }}>
        OpenAI API Key
      </Typography>
      <Box sx={{ display: "flex", gap: 2, alignItems: "center" }}>
        <StyledTextField
          label="API Key"
          type="password"
          value={apiKey}
          onChange={(e) => setApiKey(e.target.value)}
          size="small"
          sx={{ flex: 1 }}
        />
        <SaveButton variant="outlined" onClick={handleSave} disabled={!apiKey}>
          Save
        </SaveButton>
        <ClearButton variant="outlined" onClick={handleClear}>
          Clear
        </ClearButton>
      </Box>
    </StyledPaper>
  );
}
