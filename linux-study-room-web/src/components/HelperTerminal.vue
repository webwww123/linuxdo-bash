<template>
  <div class="relative w-full h-full flex flex-col">
    <!-- Helper Mode Header Banner -->
    <div class="bg-gradient-to-r from-galaxy-accent/20 to-galaxy-primary/20 border-b border-galaxy-accent/30 px-4 py-3 flex items-center justify-between shrink-0">
      <div class="flex items-center gap-3">
        <span class="text-xl">🎮</span>
        <div>
          <span class="text-sm font-medium text-galaxy-text">正在协助控制</span>
          <span class="text-sm font-bold text-galaxy-accent ml-1">{{ ownerUsername }}</span>
          <span class="text-sm text-galaxy-textMuted ml-1">的终端</span>
        </div>
      </div>
      <div class="flex items-center gap-3">
        <div class="flex items-center gap-2 text-xs text-galaxy-textMuted">
          <span class="w-2 h-2 rounded-full bg-galaxy-primary animate-pulse"></span>
          <span>实时连接</span>
        </div>
        <button
          @click="handleExit"
          class="px-3 py-1.5 rounded-lg bg-galaxy-bg/50 border border-galaxy-border text-galaxy-textMuted hover:text-red-400 hover:border-red-400/50 transition-colors text-xs font-medium flex items-center gap-1.5"
        >
          <svg class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
            <polyline points="16 17 21 12 16 7" />
            <line x1="21" y1="12" x2="9" y2="12" />
          </svg>
          退出协助
        </button>
      </div>
    </div>

    <!-- Connection Status Overlay -->
    <div v-if="connectionState !== 'connected'" class="absolute inset-0 top-[52px] bg-galaxy-bg/90 backdrop-blur-sm z-20 flex items-center justify-center">
      <div class="text-center">
        <div v-if="connectionState === 'connecting'" class="animate-spin w-8 h-8 border-2 border-galaxy-accent border-t-transparent rounded-full mx-auto mb-4"></div>
        <p class="text-sm text-galaxy-textMuted" v-if="connectionState === 'connecting'">正在连接到终端...</p>
        <p class="text-sm text-red-400" v-if="connectionState === 'error'">连接失败: {{ errorMessage }}</p>
        <p class="text-sm text-galaxy-textMuted" v-if="connectionState === 'revoked'">控制权已被撤销</p>
        <button 
          v-if="connectionState === 'error' || connectionState === 'revoked'" 
          @click="handleExit" 
          class="mt-4 px-4 py-2 bg-galaxy-primary text-black text-xs font-bold rounded-lg"
        >
          返回
        </button>
      </div>
    </div>

    <!-- Terminal Container -->
    <div ref="terminalContainer" class="flex-1 w-full overflow-hidden"></div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount, watch } from 'vue'
import { Terminal } from '@xterm/xterm'
import { FitAddon } from '@xterm/addon-fit'
import '@xterm/xterm/css/xterm.css'
import { createHelperTerminalSocket } from '../api'

const props = defineProps<{
  containerId: string
  ownerUsername: string
  helperUsername: string
}>()

const emit = defineEmits<{
  exit: []
}>()

const terminalContainer = ref<HTMLElement | null>(null)
const connectionState = ref<'connecting' | 'connected' | 'error' | 'revoked'>('connecting')
const errorMessage = ref('')

let term: Terminal | null = null
let fitAddon: FitAddon | null = null
let helperSocket: ReturnType<typeof createHelperTerminalSocket> | null = null

const initTerminal = () => {
  if (!terminalContainer.value) return

  term = new Terminal({
    fontFamily: '"JetBrains Mono", "Cascadia Code", "Fira Code", Consolas, monospace',
    fontSize: 14,
    theme: {
      background: '#030712',
      foreground: '#e5e7eb',
      cursor: '#22d3ee',
      cursorAccent: '#030712',
      selectionBackground: '#22d3ee40',
      black: '#030712',
      red: '#f87171',
      green: '#4ade80',
      yellow: '#facc15',
      blue: '#60a5fa',
      magenta: '#c084fc',
      cyan: '#22d3ee',
      white: '#e5e7eb',
      brightBlack: '#6b7280',
      brightRed: '#fca5a5',
      brightGreen: '#86efac',
      brightYellow: '#fde047',
      brightBlue: '#93c5fd',
      brightMagenta: '#d8b4fe',
      brightCyan: '#67e8f9',
      brightWhite: '#f9fafb',
    },
    cursorBlink: true,
    cursorStyle: 'bar',
    scrollback: 5000,
    allowTransparency: true,
    convertEol: true,
  })

  fitAddon = new FitAddon()
  term.loadAddon(fitAddon)

  term.open(terminalContainer.value)

  setTimeout(() => {
    fitAddon?.fit()
    connectToTerminal()
  }, 100)

  // Handle user input
  term.onData((data) => {
    if (helperSocket?.isConnected()) {
      helperSocket.send(data)
    }
  })

  // Handle resize
  window.addEventListener('resize', handleResize)
}

const connectToTerminal = () => {
  if (!props.containerId || !props.helperUsername) return

  connectionState.value = 'connecting'

  helperSocket = createHelperTerminalSocket(
    props.containerId,
    props.helperUsername,
    {
      onOpen: () => {
        connectionState.value = 'connected'
        term?.write('\r\n🎮 已连接到协助控制模式\r\n')
        // Send resize after connection
        if (fitAddon && term) {
          helperSocket?.resize(term.cols, term.rows)
        }
      },
      onOutput: (data) => {
        term?.write(data)
      },
      onStatus: (status) => {
        if (status === 'revoked') {
          connectionState.value = 'revoked'
          term?.write('\r\n\r\n🚫 控制权已被撤销\r\n')
        } else if (status.startsWith('error:')) {
          connectionState.value = 'error'
          errorMessage.value = status.replace('error: ', '')
        }
      },
      onError: () => {
        connectionState.value = 'error'
        errorMessage.value = '连接失败'
      },
      onClose: () => {
        if (connectionState.value === 'connected') {
          connectionState.value = 'error'
          errorMessage.value = '连接已断开'
        }
      }
    }
  )
}

const handleResize = () => {
  fitAddon?.fit()
  if (term && helperSocket?.isConnected()) {
    helperSocket.resize(term.cols, term.rows)
  }
}

const handleExit = () => {
  emit('exit')
}

watch(() => props.containerId, (newId) => {
  if (newId) {
    // Reconnect if container ID changes
    helperSocket?.close()
    connectToTerminal()
  }
})

onMounted(() => {
  setTimeout(initTerminal, 100)
})

onBeforeUnmount(() => {
  helperSocket?.close()
  term?.dispose()
  window.removeEventListener('resize', handleResize)
})
</script>
