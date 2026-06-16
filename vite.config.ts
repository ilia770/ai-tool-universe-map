import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  build: {
    chunkSizeWarningLimit: 1200,
    rollupOptions: {
      // Isolated second entry for the visualization prototype lab; the
      // production app (index.html) is untouched.
      input: {
        // Production entry chunk is emitted as `main-*.js`; the bundle-size
        // guard (scripts/check-bundle-size.mjs) budgets `main-`/`playground-`.
        main: 'index.html',
        playground: 'playground.html',
      },
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
