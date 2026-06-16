import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { PlaygroundApp } from './PlaygroundApp';
import '../index.css';
import './playground.css';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <PlaygroundApp />
  </StrictMode>,
);
