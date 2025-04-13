import { useState, useCallback, useEffect } from 'react';

export type ToastType = 'success' | 'error' | 'dislike' | 'skip';

export interface Toast {
  message: string;
  type: ToastType;
}

export const useToast = () => {
  const [toast, setToast] = useState<Toast | null>(null);

  const showToast = useCallback((newToast: Toast | null) => {
    setToast(newToast);
  }, []);

  // Automatically clear toast after 3 seconds
  useEffect(() => {
    if (toast) {
      const timer = setTimeout(() => {
        setToast(null);
      }, 3000);
      return () => clearTimeout(timer);
    }
  }, [toast]);

  return { toast, showToast };
}; 