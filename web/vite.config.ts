import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

// In dev, proxy /api to a Django backend so the app stays same-origin.
// Default target is the local backend; set PROXY_TARGET (e.g. in web/.env.local)
// to point the dev server at the live API instead, for example:
//   PROXY_TARGET=https://chilternview.lumatechsolutions.co.uk
// In production the nginx container serves this app and proxies /api itself.
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '')
  const target = env.PROXY_TARGET || 'http://localhost:8000'
  return {
    plugins: [react()],
    server: {
      proxy: {
        '/api': {
          target,
          changeOrigin: true,
        },
      },
    },
  }
})
