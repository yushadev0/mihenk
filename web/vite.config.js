import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Served at https://yusa.app/mihenk/ (see ../viewer/deploy.sh).
export default defineConfig({
  base: '/mihenk/',
  plugins: [react()],
});
