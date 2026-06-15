import { useContext } from 'react';
import { InAppBrowserContext, type InAppBrowserValue } from './inAppBrowserContext';

export function useInAppBrowser(): InAppBrowserValue {
  const ctx = useContext(InAppBrowserContext);
  if (!ctx) throw new Error('useInAppBrowser must be used within InAppBrowserProvider');
  return ctx;
}
