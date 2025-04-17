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
  GetLLMProvider,
  SetLLMProvider,
} from "@wailsjs/go/bindings/Settings";
import { useSnackbar } from "notistack";

// Define the available ChatGPT models
export type ChatGPTModel = "gpt-4o" | "gpt-4o-mini" | "gpt-4-turbo";
export type LLMProvider = "openai" | "gemini";

// Helper function to parse error objects consistently
const parseErrorMessage = (error: any, defaultMessage: string = "An error occurred"): string => {
  if (typeof error === "string") {
    return error;
  } else if (error?.error) {
    if (typeof error.error === "string") {
      return error.error;
    } else if (error.error?.message) {
      return error.error.message;
    }
  } else if (error?.message) {
    return error.message;
  }
  return defaultMessage;
};

// Helper function to truncate long error messages for toast notifications
const truncateErrorMessage = (message: string, maxLength: number = 150): string => {
  return message.length > maxLength 
    ? message.substring(0, maxLength) + "..." 
    : message;
};

// Event dispatcher for LLM provider changes
const LLM_PROVIDER_CHANGE_EVENT = "llm-provider-change";

// Dispatches a custom event when the LLM provider changes
export function dispatchLLMProviderChangeEvent(provider: LLMProvider) {
  const event = new CustomEvent(LLM_PROVIDER_CHANGE_EVENT, {
    detail: { provider },
  });
  window.dispatchEvent(event);
  console.log("[SettingsContext] Dispatched LLM provider change event:", provider);
}

// Hook to listen for LLM provider changes
export function useLLMProviderChangeListener(
  callback: (provider: LLMProvider) => void
) {
  useEffect(() => {
    const handler = (event: Event) => {
      const customEvent = event as CustomEvent;
      callback(customEvent.detail.provider);
    };

    window.addEventListener(LLM_PROVIDER_CHANGE_EVENT, handler);
    return () => {
      window.removeEventListener(LLM_PROVIDER_CHANGE_EVENT, handler);
    };
  }, [callback]);
}

interface SettingsContextType {
  isContinuousPlayback: boolean;
  setContinuousPlayback: (enabled: boolean) => Promise<void>;
  chatGPTModel: ChatGPTModel;
  setChatGPTModel: (model: ChatGPTModel) => Promise<void>;
  llmProvider: LLMProvider;
  setLLMProvider: (provider: LLMProvider) => Promise<void>;
}

const SettingsContext = createContext<SettingsContextType | undefined>(
  undefined,
);

export function SettingsProvider({ children }: { children: React.ReactNode }) {
  const [isContinuousPlayback, setIsContinuousPlaybackState] = useState(false);
  const [chatGPTModel, setChatGPTModelState] = useState<ChatGPTModel>("gpt-4o");
  const [llmProvider, setLLMProviderState] = useState<LLMProvider>("openai");
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

        // Load LLM provider from backend
        const savedProvider = await GetLLMProvider();
        if (savedProvider && ["openai", "gemini"].includes(savedProvider)) {
          setLLMProviderState(savedProvider as LLMProvider);
          console.log(
            "[SettingsContext] Loaded LLM provider setting:",
            savedProvider,
          );
        }
      } catch (error) {
        console.error("[SettingsContext] Error loading settings:", error);
        const errorMessage = parseErrorMessage(error, "Failed to load settings");
        enqueueSnackbar(truncateErrorMessage(errorMessage), { variant: "error" });
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
        const errorMessage = parseErrorMessage(error, "Failed to update continuous playback setting");
        enqueueSnackbar(truncateErrorMessage(errorMessage), {
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
        const errorMessage = parseErrorMessage(error, "Failed to update ChatGPT model setting");
        enqueueSnackbar(truncateErrorMessage(errorMessage), {
          variant: "error",
        });
      }
    },
    [enqueueSnackbar],
  );

  // Update LLM provider setting
  const setLLMProvider = useCallback(
    async (provider: LLMProvider) => {
      try {
        console.log("[SettingsContext] Setting LLM provider:", provider);
        await SetLLMProvider(provider);
        setLLMProviderState(provider);
        
        // Dispatch event to notify components about the provider change
        dispatchLLMProviderChangeEvent(provider);
      } catch (error) {
        console.error("[SettingsContext] Error setting LLM provider:", error);
        const errorMessage = parseErrorMessage(error, "Failed to update LLM provider setting");
        enqueueSnackbar(truncateErrorMessage(errorMessage), {
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
    llmProvider,
    setLLMProvider,
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
