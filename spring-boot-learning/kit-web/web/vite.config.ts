import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

// In development the browser talks to Vite, and Vite forwards /api to the Spring Boot app, so there's no CORS to
// configure. In the image, nginx does the same job (see Dockerfile and nginx/default.conf.template).
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: { '/api': process.env.API_UPSTREAM ?? 'http://localhost:8080' },
  },
});
