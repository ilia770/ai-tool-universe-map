import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  build: {
    chunkSizeWarningLimit: 1200,
    rollupOptions: {
      output: {
        manualChunks: (id) => {
          if (id.includes('node_modules/three/')) return 'three-core';
          if (
            id.includes('node_modules/@react-three/fiber') ||
            id.includes('node_modules/@react-three/drei') ||
            id.includes('node_modules/@react-three/postprocessing') ||
            id.includes('node_modules/postprocessing') ||
            id.includes('node_modules/camera-controls')
          ) {
            return 'three-r3f';
          }
          return undefined;
        },
      },
    },
  },
});
