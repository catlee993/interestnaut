import { useState, useEffect, useCallback } from 'react';
import { GetContinuousPlayback, SetContinuousPlayback } from '@wailsjs/go/bindings/Settings';
import { useSnackbar } from 'notistack';

export type ChatGPTModel = 'gpt-4o' | 'gpt-4o-mini' | 'gpt-4-turbo';

export function useSettings() {
  const [chatGPTModel, setChatGPTModel] = useState<ChatGPTModel>('gpt-4o');
  const [continuousPlayback, setContinuousPlaybackState] = useState<boolean>(false);
  const [isLoading, setIsLoading] = useState(true);
  const { enqueueSnackbar } = useSnackbar();

  // Load settings on component mount
  useEffect(() => {
    const loadSettings = async () => {
      try {
        setIsLoading(true);
        
        // Load continuous playback setting from backend
        const isContinuousPlayback = await GetContinuousPlayback();
        setContinuousPlaybackState(isContinuousPlayback);
        
        // For now, we'll use the default value until the Go bindings are updated
        setChatGPTModel('gpt-4o');
      } catch (error) {
        console.error('Failed to load settings:', error);
        enqueueSnackbar('Failed to load settings', { variant: 'error' });
      } finally {
        setIsLoading(false);
      }
    };

    loadSettings();
  }, [enqueueSnackbar]);

  // Handle model change
  const updateChatGPTModel = useCallback(async (model: ChatGPTModel) => {
    try {
      setIsLoading(true);
      // This will be implemented when the Go bindings are updated
      // For now, we'll just update the local state
      setChatGPTModel(model);
      enqueueSnackbar(`ChatGPT model updated to ${model}`, { variant: 'success' });
    } catch (error) {
      console.error('Failed to update ChatGPT model:', error);
      enqueueSnackbar('Failed to update ChatGPT model', { variant: 'error' });
    } finally {
      setIsLoading(false);
    }
  }, [enqueueSnackbar]);

  // Handle continuous playback toggle
  const setContinuousPlayback = useCallback(async (enabled: boolean) => {
    try {
      setIsLoading(true);
      await SetContinuousPlayback(enabled);
      setContinuousPlaybackState(enabled);
      enqueueSnackbar(
        `Continuous playback ${enabled ? 'enabled' : 'disabled'}`,
        { variant: 'success' }
      );
    } catch (error) {
      console.error('Failed to update continuous playback setting:', error);
      enqueueSnackbar(
        `Failed to ${enabled ? 'enable' : 'disable'} continuous playback`, 
        { variant: 'error' }
      );
    } finally {
      setIsLoading(false);
    }
  }, [enqueueSnackbar]);

  return {
    chatGPTModel,
    updateChatGPTModel,
    continuousPlayback,
    setContinuousPlayback,
    isLoading
  };
} 