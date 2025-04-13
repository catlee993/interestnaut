import { useSnackbar, VariantType } from 'notistack';

export function useToast() {
  const { enqueueSnackbar } = useSnackbar();

  const showToast = (message: string, type: VariantType = 'default') => {
    enqueueSnackbar(message, {
      variant: type,
      anchorOrigin: { vertical: 'top', horizontal: 'center' },
      style: {
        fontSize: '1.1rem',
        padding: '12px 24px',
      }
    });
  };

  return showToast;
} 