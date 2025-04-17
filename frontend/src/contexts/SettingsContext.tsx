import React, {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
} from "react";
import {
  GetContinuousPlayback,
  SetContinuousPlayback,
  GetChatGPTModel,
  SetChatGPTModel,
} from "@wailsjs/go/bindings/Settings";
import { useSnackbar } from "notistack";

// Define the available ChatGPT models
export type ChatGPTModel = "gpt-4o" | "gpt-4o-mini" | "gpt-4-turbo";

interface SettingsContextType {
  isContinuousPlayback: boolean;
  setContinuousPlayback: (enabled: boolean) => Promise<void>;
  chatGPTModel: ChatGPTModel;
  setChatGPTModel: (model: ChatGPTModel) => Promise<void>;
}

const SettingsContext = createContext<SettingsContextType | undefined>(
  undefined,
);

export function SettingsProvider({ children }: { children: React.ReactNode }) {
  const [isContinuousPlayback, setIsContinuousPlaybackState] = useState(false);
  const [chatGPTModel, setChatGPTModelState] = useState<ChatGPTModel>("gpt-4o");
  const { enqueueSnackbar } = useSnackbar();

  // Load initial settings
  useEffect(() => {
    const loadSettings = async () => {
      try {
        // Load continuous playback setting
        const continuousPlaybackEnabled = await GetContinuousPlayback();
        console.log(
          "[SettingsContext] Loaded continuous playback setting:",
          continuousPlaybackEnabled,
        );
        setIsContinuousPlaybackState(continuousPlaybackEnabled);

        // Load ChatGPT model from backend
        const savedModel = await GetChatGPTModel();
        if (
          savedModel &&
          ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo"].includes(savedModel)
        ) {
          setChatGPTModelState(savedModel as ChatGPTModel);
          console.log(
            "[SettingsContext] Loaded ChatGPT model setting:",
            savedModel,
          );
        }
      } catch (error) {
        console.error("[SettingsContext] Error loading settings:", error);
        enqueueSnackbar("Failed to load settings", { variant: "error" });
      }
    };

    loadSettings();
  }, [enqueueSnackbar]);

  // Update continuous playback setting
  const setContinuousPlayback = useCallback(
    async (enabled: boolean) => {
      try {
        console.log("[SettingsContext] Setting continuous playback:", enabled);
        await SetContinuousPlayback(enabled);
        setIsContinuousPlaybackState(enabled);
      } catch (error) {
        console.error(
          "[SettingsContext] Error setting continuous playback:",
          error,
        );
        enqueueSnackbar("Failed to update continuous playback setting", {
          variant: "error",
        });
      }
    },
    [enqueueSnackbar],
  );

  // Update ChatGPT model setting
  const setChatGPTModel = useCallback(
    async (model: ChatGPTModel) => {
      try {
        console.log("[SettingsContext] Setting ChatGPT model:", model);
        await SetChatGPTModel(model);
        setChatGPTModelState(model);
      } catch (error) {
        console.error("[SettingsContext] Error setting ChatGPT model:", error);
        enqueueSnackbar("Failed to update ChatGPT model setting", {
          variant: "error",
        });
      }
    },
    [enqueueSnackbar],
  );

  const value = {
    isContinuousPlayback,
    setContinuousPlayback,
    chatGPTModel,
    setChatGPTModel,
  };

  return (
    <SettingsContext.Provider value={value}>
      {children}
    </SettingsContext.Provider>
  );
}

// Hook to use the settings context
export function useSettings() {
  const context = useContext(SettingsContext);
  if (context === undefined) {
    throw new Error("useSettings must be used within a SettingsProvider");
  }
  return context;
}
