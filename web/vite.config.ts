import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// In dev, proxy the API to the Django backend so the app stays same-origin.
// In production the nginx container serves this app and proxies /api itself.
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': 'http://localhost:8000',
    },
  },
})
