<template>
  <div class="relative w-full h-full flex flex-col group">
      <!-- Container Toolbar (Visible on Hover, Non-Guest Only) -->
      <div v-if="props.user?.provider !== 'guest'" class="absolute top-2 right-4 z-10 flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity duration-300">
          
          <template v-if="containerStatus === 'destroyed'">
             <button 
                @click="emit('request-setup')"
                class="px-3 py-1.5 rounded bg-galaxy-primary hover:bg-galaxy-accent text-black font-bold text-xs shadow-[0_0_15px_rgba(45,212,191,0.3)] flex items-center gap-2 transition-all animate-pulse"
             >
                <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z"/></svg>
                Start Container
             </button>
          </template>
          
          <template v-else>
              <!-- Status Badge -->
              <div class="px-2 py-1 rounded bg-galaxy-bg/80 backdrop-blur border border-galaxy-border flex items-center gap-2">
                  <span class="w-1.5 h-1.5 rounded-full" :class="containerStatus === 'running' ? 'bg-galaxy-primary animate-pulse' : 'bg-galaxy-danger'"></span>
                  <span class="text-[10px] uppercase tracking-wider font-bold text-galaxy-textMuted">{{ containerStatus }}</span>
              </div>

              <!-- Actions -->
              <button 
                @click="handleRestart"
                :disabled="isProcessing"
                class="p-1.5 rounded bg-galaxy-bg/80 backdrop-blur border border-galaxy-border hover:bg-galaxy-surfaceHighlight hover:text-galaxy-primary text-galaxy-textMuted transition-colors disabled:opacity-50" 
                title="Restart Container">
                 <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"></path></svg>
              </button>

              <button 
                @click="handleDestroy"
                :disabled="isProcessing"
                class="p-1.5 rounded bg-galaxy-bg/80 backdrop-blur border border-galaxy-border hover:bg-galaxy-danger/20 hover:border-galaxy-danger/30 hover:text-galaxy-danger text-galaxy-textMuted transition-colors disabled:opacity-50" 
                title="Destroy / Reset Factory Settings">
                 <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
              </button>
          </template>
      </div>

      <!-- Connection Status Overlay -->
      <div v-if="connectionState !== 'connected' || isInstalling" class="absolute inset-0 bg-galaxy-bg/90 backdrop-blur-sm z-20 flex items-center justify-center">
          <div class="text-center">
              <template v-if="isInstalling">
                  <div class="w-12 h-12 mx-auto mb-4 relative">
                      <div class="absolute inset-0 border-2 border-galaxy-primary/30 rounded-full"></div>
                      <div class="absolute inset-0 border-2 border-galaxy-primary border-t-transparent rounded-full animate-spin"></div>
                      <div class="absolute inset-2 border-2 border-galaxy-accent border-b-transparent rounded-full animate-spin" style="animation-direction: reverse; animation-duration: 0.8s;"></div>
                  </div>
                  <p class="text-sm text-galaxy-text font-medium mb-1">🐟 Installing Fish Shell...</p>
                  <p class="text-xs text-galaxy-textMuted">Setting up your environment</p>
                  <div class="mt-4 w-48 h-1 bg-galaxy-surface rounded-full overflow-hidden mx-auto">
                      <div class="h-full bg-gradient-to-r from-galaxy-primary to-galaxy-accent animate-pulse" :style="{width: installProgress + '%'}"></div>
                  </div>
              </template>
              <template v-else>
                  <div v-if="connectionState === 'connecting'" class="animate-spin w-8 h-8 border-2 border-galaxy-primary border-t-transparent rounded-full mx-auto mb-4"></div>
                  <div v-else class="w-8 h-8 text-galaxy-danger mx-auto mb-4">⚠️</div>
                  <p class="text-sm text-galaxy-textMuted">{{ connectionMessage }}</p>
                  <button v-if="connectionState === 'error'" @click="reconnect" class="mt-4 px-4 py-2 bg-galaxy-primary text-black text-xs font-bold rounded-lg">
                      Retry Connection
                  </button>
              </template>
          </div>
      </div>

      <div ref="terminalContainer" class="flex-1 w-full overflow-hidden rounded-lg"></div>
  </div>
</template>

<script setup lang="ts">
import { onMounted, onBeforeUnmount, ref, watch } from 'vue'
import { Terminal } from 'xterm'
import { FitAddon } from 'xterm-addon-fit'
import { WebLinksAddon } from 'xterm-addon-web-links'
import 'xterm/css/xterm.css'
import { containerApi, createTerminalSocket } from '../api'

const props = defineProps<{
  user: {
    username: string;
    name?: string;
    avatar: string | null;
    provider: string;
    containerId?: string;
  } | null
}>()

const emit = defineEmits(['request-setup', 'container-ready'])

const terminalContainer = ref<HTMLElement | null>(null)
let term: Terminal | null = null
let fitAddon: FitAddon | null = null
let termSocket: ReturnType<typeof createTerminalSocket> | null = null
let inputHandlerRegistered = false

// State
const isProcessing = ref(false)
const containerStatus = ref<'running' | 'stopped' | 'destroyed' | 'starting'>('starting')
const connectionState = ref<'connecting' | 'connected' | 'error'>('connecting')
const connectionMessage = ref('Connecting to terminal...')
const containerId = ref<string | null>(null)
const isInstalling = ref(false)
const installProgress = ref(0)
let installTimer: number | null = null

const initTerminal = () => {
  if (!terminalContainer.value) return

  term = new Terminal({
    cursorBlink: true,
    fontFamily: '"JetBrains Mono", "Fira Code", monospace',
    fontSize: 16,
    letterSpacing: 0,
    lineHeight: 1.1,
    theme: {
      background: '#030712',
      foreground: '#f3f4f6',
      cursor: '#818cf8',
      selectionBackground: 'rgba(129, 140, 248, 0.3)',
      black: '#030712', red: '#ef4444', green: '#22c55e', yellow: '#eab308',
      blue: '#3b82f6', magenta: '#a855f7', cyan: '#06b6d4', white: '#f3f4f6',
      brightBlack: '#4b5563', brightRed: '#f87171', brightGreen: '#4ade80', brightYellow: '#fde047',
      brightBlue: '#60a5fa', brightMagenta: '#c084fc', brightCyan: '#22d3ee', brightWhite: '#ffffff',
    },
    allowTransparency: true,
    allowProposedApi: true
  })

  fitAddon = new FitAddon()
  term.loadAddon(fitAddon)
  term.loadAddon(new WebLinksAddon())

  term.open(terminalContainer.value)
  fitAddon.fit()
  
  // Register input/resize handlers ONCE
  if (!inputHandlerRegistered) {
    term.onData(data => {
      if (containerStatus.value !== 'running') return
      termSocket?.send(data)
    })

    term.onResize(({ cols, rows }) => {
      termSocket?.resize(cols, rows)
    })
    inputHandlerRegistered = true
  }
  
  // Guest mode: read-only
  if (props.user?.provider === 'guest') {
    term.writeln('\x1b[33m⚠ Guest Mode: Terminal is read-only\x1b[0m')
    term.writeln('Login to get your own container.')
    connectionState.value = 'connected'
    containerStatus.value = 'running'
    return
  }

  // Connect to backend
  connectToContainer()
  
  window.addEventListener('resize', handleResize)
}

const connectToContainer = async () => {
  if (!term) return
  
  connectionState.value = 'connecting'
  connectionMessage.value = 'Connecting to terminal...'

  const cid = props.user?.containerId || containerId.value
  
  if (!cid) {
    connectionState.value = 'error'
    connectionMessage.value = 'No container available. Click "Start Container" to create one.'
    containerStatus.value = 'destroyed'
    return
  }

  containerId.value = cid

  // Close existing socket before creating new one
  termSocket?.close()

  try {
    // Get username and OS from user props
    const username = props.user?.username || 'Guest'
    const name = props.user?.name || username // Use nickname if available
    const os = props.user?.os || 'linux' // Use actual OS type (alpine/debian)
    
    termSocket = createTerminalSocket(cid, username, os, {
      onOpen: () => {
        connectionState.value = 'connected'
        containerStatus.value = 'running'
        
        // Emit containerId so parent can track which container is active
        emit('container-ready', cid)
        
        // Show installation overlay for 10 seconds
        isInstalling.value = true
        installProgress.value = 0
        
        // Animate progress bar
        let progress = 0
        installTimer = window.setInterval(() => {
          progress += 10
          installProgress.value = Math.min(progress, 100)
          if (progress >= 100) {
            if (installTimer) clearInterval(installTimer)
            isInstalling.value = false
            term?.writeln('\x1b[32m✔ Environment ready!\x1b[0m')
            
            // Send initial resize
            if (fitAddon) {
              const dims = fitAddon.proposeDimensions()
              if (dims) termSocket?.resize(dims.cols, dims.rows)
            }
          }
        }, 300) // 10 steps x 0.3 seconds = 3 seconds (fish is pre-installed)
      },
      onOutput: (data) => {
        term?.write(data)
      },
      onStatus: (status) => {
        if (status === 'stopped') {
          containerStatus.value = 'stopped'
          term?.writeln('\r\n\x1b[33m⏸ Container stopped due to inactivity\x1b[0m')
        }
      },
      onError: () => {
        connectionState.value = 'error'
        connectionMessage.value = 'Connection lost. Click Retry to reconnect.'
      },
      onClose: () => {
        if (containerStatus.value === 'running') {
          connectionState.value = 'error'
          connectionMessage.value = 'Connection closed unexpectedly.'
        }
      }
    }, name)

  } catch (err) {
    connectionState.value = 'error'
    connectionMessage.value = 'Failed to connect: ' + (err as Error).message
  }
}

const reconnect = () => {
  termSocket?.close()
  connectToContainer()
}

const handleResize = () => {
  fitAddon?.fit()
}

const handleRestart = async () => {
  if (!containerId.value || isProcessing.value) return
  isProcessing.value = true
  
  term?.writeln('\r\n\x1b[33m➔ Restarting container...\x1b[0m')
  
  try {
    await containerApi.restart(containerId.value)
    reconnect()
  } catch (err) {
    term?.writeln('\x1b[31mFailed to restart: ' + (err as Error).message + '\x1b[0m')
  }
  
  isProcessing.value = false
}

const handleDestroy = async () => {
  if (!containerId.value || isProcessing.value) return
  isProcessing.value = true
  
  term?.writeln('\r\n\x1b[31m⚠ Destroying container...\x1b[0m')
  
  try {
    await containerApi.reset(containerId.value)
    termSocket?.close()
    term?.reset()
    term?.writeln('\x1b[90mContainer destroyed.\x1b[0m')
    term?.writeln('Click "Start Container" to create a new one.')
    containerStatus.value = 'destroyed'
    containerId.value = null
  } catch (err) {
    term?.writeln('\x1b[31mFailed to destroy: ' + (err as Error).message + '\x1b[0m')
  }
  
  isProcessing.value = false
}

// Watch for container ID changes (e.g., after setup wizard)
watch(() => props.user?.containerId, (newId) => {
  if (newId && newId !== containerId.value) {
    containerId.value = newId
    reconnect()
  }
})

onMounted(() => {
  setTimeout(initTerminal, 100)
})

onBeforeUnmount(() => {
  termSocket?.close()
  term?.dispose()
  window.removeEventListener('resize', handleResize)
})
</script>
