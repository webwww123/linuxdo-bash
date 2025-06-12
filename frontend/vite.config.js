import { defineConfig, loadEnv } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd())
  return {
    plugins: [react()],
    server: {
      port: 5173,
      proxy: {
        // 仍然代理到本机端口，方便热更新
        '/api': {
          target: 'http://localhost:3001',
          changeOrigin: true
        },
        '/socket.io': {
          target: 'http://localhost:3001',
          changeOrigin: true,
          ws: true
        },
        '/webssh': {
          target: 'http://localhost:3002',
          changeOrigin: true,
          ws: true
        },
        '/grafana': {
          target: 'http://localhost:8080',
          changeOrigin: true
        }
      }
    },
    build: {
      outDir: 'dist',
      assetsDir: 'assets'
    },
    define: {
      // 编译期注入基路径（开发用 http://localhost:5173，生产是相对路径 '/api'）
      __API_BASE__: JSON.stringify(env.VITE_API_BASE || '/api')
    }
  }
})
