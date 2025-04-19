import { useState, useEffect } from 'react';
import { EventsOn, EventsOff } from '@wailsjs/runtime/runtime';
import { HasValidCredentials as CheckMovieCredentials } from '@wailsjs/go/bindings/Movies';
import { HasValidCredentials as CheckTVCredentials } from '@wailsjs/go/bindings/TVShows';
import { HasValidCredentials as CheckGameCredentials } from '@wailsjs/go/bindings/Games';

export type CredentialType = 'tmdb' | 'openai' | 'rawg' | 'gemini';
export type CredentialAction = 'save' | 'clear';

export interface CredentialEvent {
  type: CredentialType;
  action: CredentialAction;
}

/**
 * Hook for listening to credential changes from the backend
 * @param types Array of credential types to listen for, or undefined for all types
 * @returns Object containing the state of each credential type
 */
export function useCredentials(types?: CredentialType[]) {
  // Store the validity state of each credential type
  const [credentialState, setCredentialState] = useState<Record<CredentialType, boolean>>({
    tmdb: false,
    openai: false,
    rawg: false,
    gemini: false,
  });

  // Set initial values
  useEffect(() => {
    // We'll check the credentials on mount and subscribe to events
    const checkCredentials = async () => {
      try {
        // Check TMDB credentials
        const hasTMDB = await CheckMovieCredentials();
        
        // Check RAWG credentials
        const hasRAWG = await CheckGameCredentials();
        
        // Update state with all checks
        setCredentialState(prev => ({
          ...prev,
          tmdb: hasTMDB,
          rawg: hasRAWG,
          // We don't have direct checks for these yet
          openai: prev.openai,
          gemini: prev.gemini,
        }));
      } catch (error) {
        console.error("Error checking credentials:", error);
      }
    };

    checkCredentials();

    // Set up event listeners
    const handleCredentialChange = (event: CredentialEvent) => {
      setCredentialState(prevState => ({
        ...prevState,
        [event.type]: event.action === 'save',
      }));
    };

    // Listen for all credential changes
    EventsOn('credential-change', handleCredentialChange);

    return () => {
      // Clean up event listeners on unmount
      EventsOff('credential-change');
    };
  }, []);

  // If specific types are requested, filter the state
  if (types) {
    const filteredState: Record<CredentialType, boolean> = {} as Record<CredentialType, boolean>;
    types.forEach(type => {
      filteredState[type] = credentialState[type];
    });
    return filteredState;
  }

  return credentialState;
}

/**
 * Hook for listening to a specific credential type
 * @param type The credential type to listen for
 * @returns Boolean indicating if the credential is valid
 */
export function useCredential(type: CredentialType): boolean {
  const [isValid, setIsValid] = useState<boolean>(false);

  useEffect(() => {
    // Check the credential on mount
    const checkCredential = async () => {
      try {
        let isCredentialValid = false;
        
        switch (type) {
          case 'tmdb':
            isCredentialValid = await CheckMovieCredentials();
            break;
          case 'rawg':
            isCredentialValid = await CheckGameCredentials();
            break;
          case 'openai':
          case 'gemini':
            // For types we don't have direct checks for yet
            break;
        }
        
        setIsValid(isCredentialValid);
      } catch (error) {
        console.error(`Error checking ${type} credential:`, error);
        setIsValid(false);
      }
    };
    
    checkCredential();
  
    // Set up event listeners for the specific credential type
    const eventName = `credential-${type}`;
    
    const handleCredentialChange = (event: CredentialEvent) => {
      setIsValid(event.action === 'save');
    };

    // Listen for specific credential type changes
    EventsOn(eventName, handleCredentialChange);
    
    // Also listen for the general event in case it's dispatched there
    EventsOn('credential-change', (event: CredentialEvent) => {
      if (event.type === type) {
        setIsValid(event.action === 'save');
      }
    });

    return () => {
      // Clean up event listeners on unmount
      EventsOff(eventName);
      EventsOff('credential-change');
    };
  }, [type]);

  return isValid;
} 