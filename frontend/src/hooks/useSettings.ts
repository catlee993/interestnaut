import { useState, useEffect, useCallback } from 'react';
import { 
  GetContinuousPlayback, 
  SetContinuousPlayback, 
  GetChatGPTModel, 
  SetChatGPTModel,
  GetLLMProvider,
  SetLLMProvider,
  GetGeminiModel,
  SetGeminiModel
} from '@wailsjs/go/bindings/Settings';
import { useSnackbar } from 'notistack';

export type ChatGPTModel = 'gpt-4o' | 'gpt-4o-mini' | 'gpt-4-turbo';
export type LLMProvider = 'openai' | 'gemini';
export type GeminiModel = 'gemini-1.5-pro' | 'gemini-2.0-flash' | 'gemini-2.0-flash-lite';

export function useSettings() {
  const [chatGPTModel, setChatGPTModel] = useState<ChatGPTModel>('gpt-4o');
  const [geminiModel, setGeminiModel] = useState<GeminiModel>('gemini-1.5-pro');
  const [llmProvider, setLLMProvider] = useState<LLMProvider>('openai');
  const [continuousPlayback, setContinuousPlaybackState] = useState<boolean>(false);
  const [isLoading, setIsLoading] = useState(true);
  const { enqueueSnackbar } = useSnackbar();

  useEffect(() => {
    const loadSettings = async () => {
      try {
        setIsLoading(true);
        
        const isContinuousPlayback = await GetContinuousPlayback();
        setContinuousPlaybackState(isContinuousPlayback);
        
        const model = await GetChatGPTModel();
        const validModel = ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo'].includes(model) 
          ? model as ChatGPTModel 
          : 'gpt-4o';
        setChatGPTModel(validModel);
        
        const provider = await GetLLMProvider();
        const validProvider = ['openai', 'gemini'].includes(provider)
          ? provider as LLMProvider
          : 'openai';
        setLLMProvider(validProvider);
        
        const gemModel = await GetGeminiModel();
        const validGeminiModel = [
          'gemini-1.5-pro', 
          'gemini-2.0-flash', 
          'gemini-2.0-flash-lite'
        ].includes(gemModel)
          ? gemModel as GeminiModel
          : 'gemini-1.5-pro';
        setGeminiModel(validGeminiModel);
        
        console.log(`[useSettings] Loaded settings: continuousPlayback=${isContinuousPlayback}, chatGPTModel=${model}, llmProvider=${provider}, geminiModel=${gemModel}`);
      } catch (error) {
        console.error('Failed to load settings:', error);
        enqueueSnackbar('Failed to load settings', { variant: 'error' });
      } finally {
        setIsLoading(false);
      }
    };

    loadSettings();
  }, [enqueueSnackbar]);

  const updateChatGPTModel = useCallback(async (model: ChatGPTModel) => {
    try {
      setIsLoading(true);
      
      await SetChatGPTModel(model);
      setChatGPTModel(model);
      console.log(`[useSettings] Updated ChatGPT model to ${model}`);
      
      enqueueSnackbar(`ChatGPT model updated to ${model}`, { variant: 'success' });
    } catch (error) {
      console.error('Failed to update ChatGPT model:', error);
      enqueueSnackbar('Failed to update ChatGPT model', { variant: 'error' });
    } finally {
      setIsLoading(false);
    }
  }, [enqueueSnackbar]);
  
  const updateGeminiModel = useCallback(async (model: GeminiModel) => {
    try {
      setIsLoading(true);
      
      await SetGeminiModel(model);
      setGeminiModel(model);
      console.log(`[useSettings] Updated Gemini model to ${model}`);
      
      enqueueSnackbar(`Gemini model updated to ${model}`, { variant: 'success' });
    } catch (error) {
      console.error('Failed to update Gemini model:', error);
      enqueueSnackbar('Failed to update Gemini model', { variant: 'error' });
    } finally {
      setIsLoading(false);
    }
  }, [enqueueSnackbar]);
  
  const updateLLMProvider = useCallback(async (provider: LLMProvider) => {
    try {
      setIsLoading(true);
      
      await SetLLMProvider(provider);
      setLLMProvider(provider);
      console.log(`[useSettings] Updated LLM provider to ${provider}`);
      
      enqueueSnackbar(`LLM provider updated to ${provider}`, { variant: 'success' });
    } catch (error) {
      console.error('Failed to update LLM provider:', error);
      enqueueSnackbar('Failed to update LLM provider', { variant: 'error' });
    } finally {
      setIsLoading(false);
    }
  }, [enqueueSnackbar]);

  const setContinuousPlayback = useCallback(async (enabled: boolean) => {
    try {
      setIsLoading(true);
      await SetContinuousPlayback(enabled);
      setContinuousPlaybackState(enabled);
      console.log(`[useSettings] Updated continuous playback to ${enabled}`);
      
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
    geminiModel,
    updateGeminiModel,
    llmProvider,
    updateLLMProvider,
    continuousPlayback,
    setContinuousPlayback,
    isLoading
  };
} 