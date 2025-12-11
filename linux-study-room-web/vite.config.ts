import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  server: {
    allowedHosts: ['.dstack-pha-prod7.phala.network', '64b1f537d0ed56f536980d2b789fc1c5fb663308-4173.dstack-pha-prod7.phala.network']
  }
})
