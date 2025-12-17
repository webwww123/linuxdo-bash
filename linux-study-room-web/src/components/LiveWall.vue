<template>
  <div class="flex flex-col h-full bg-galaxy-surface/0">
    <!-- Header -->
    <div class="h-16 border-b border-galaxy-border flex items-center px-4 shrink-0">
      <h2 class="font-medium text-galaxy-text text-sm tracking-wide">Live Sessions</h2>
      <span class="ml-auto text-xs text-galaxy-accent bg-galaxy-accent/10 px-2 py-0.5 rounded-full ring-1 ring-galaxy-accent/20">{{ onlineCount }} active</span>
    </div>
    
    <!-- User Grid -->
    <div class="flex-1 overflow-y-auto p-4 space-y-4 min-h-0">
      <!-- Session Card with xterm.js mini-terminal -->
      <div v-for="session in displaySessions" :key="session.containerId || session.id" class="group relative" @dblclick="openSession(session)">
        <!-- Pinned Badge -->
        <div v-if="session.pinCount > 0" class="absolute -top-2 -right-2 z-10 bg-galaxy-accent text-galaxy-bg text-[10px] font-bold px-1.5 py-0.5 rounded-full flex items-center gap-1 shadow-lg">
          <span>📌</span>
          <span>{{ session.pinCount }}</span>
        </div>
        <div class="absolute inset-0 bg-gradient-to-r from-galaxy-primary/20 to-galaxy-accent/20 rounded-xl blur opacity-0 group-hover:opacity-100 transition-opacity duration-500"></div>
        <div class="relative bg-galaxy-bg border border-galaxy-border rounded-xl overflow-hidden hover:border-galaxy-textMuted/30 transition-colors cursor-zoom-in" :class="{'ring-2 ring-galaxy-accent/50': session.pinCount > 0}">
          <!-- Mini Terminal Preview using xterm.js -->
          <div class="h-36 bg-[#0a0a0a] overflow-hidden pointer-events-none">
            <div :ref="el => setTerminalRef(session.containerId, el)" class="w-full h-full"></div>
          </div>
          
          <!-- User Info Overlay -->
          <div class="bg-galaxy-surfaceHighlight/50 backdrop-blur-sm px-3 py-2 flex items-center justify-between border-t border-galaxy-border/50">
            <div class="flex items-center gap-2 flex-1 min-w-0">
              <img :src="session.avatar" class="w-5 h-5 rounded-full bg-galaxy-bg shrink-0" />
               <!-- Name: show name if available, fallback to username. Show 'myself' if it's me -->
              <div class="flex items-center gap-1.5">
                <span class="text-xs font-medium text-galaxy-text truncate" :title="session.username">
                  {{ (session.username === currentUser?.username ? (currentUser?.name || 'Myself') : (session.name || session.username)) }}
                </span>
                <span v-if="session.username === currentUser?.username" class="text-[10px] text-galaxy-textMuted">(Me)</span>
              </div>
              <!-- Show helpers badge if someone is controlling -->
              <span 
                v-if="session.helpers && session.helpers.length > 0" 
                class="text-[10px] bg-purple-500/20 text-purple-400 px-1.5 py-0.5 rounded-full flex items-center gap-1 shrink-0"
                :title="'被协助控制: ' + session.helpers.join(', ')"
              >
                🎮 {{ session.helpers[0] }}
              </span>
            </div>
            <div class="flex items-center gap-1">
              <!-- Like Button -->
              <button 
                @click.stop="handleLike(session)"
                class="p-1 rounded hover:bg-galaxy-primary/20 transition-colors text-galaxy-textMuted hover:text-red-400 active:scale-125"
                title="Send love"
              >
                <span class="text-sm">❤️</span>
              </button>
              <!-- Pin Button -->
              <button 
                @click.stop="handlePin(session)"
                class="p-1 rounded hover:bg-galaxy-accent/20 transition-colors"
                :class="isPinned(session) ? 'text-galaxy-accent' : 'text-galaxy-textMuted hover:text-galaxy-accent'"
                :title="isPinned(session) ? 'Unpin' : 'Pin to top'"
              >
                <span class="text-sm">{{ isPinned(session) ? '📍' : '📌' }}</span>
              </button>
              <!-- Invite Button (only show if I have an active session and this is not my session) -->
              <button 
                v-if="canInvite(session)"
                @click.stop="handleInvite(session)"
                class="p-1 rounded hover:bg-purple-500/20 transition-colors text-galaxy-textMuted hover:text-purple-400"
                title="邀请协助控制"
              >
                <span class="text-sm">🎮</span>
              </button>
              <span class="text-[10px] border border-galaxy-border px-1 rounded uppercase ml-1">{{ session.os || 'linux' }}</span>
            </div>
          </div>
        </div>
        <!-- Flying Hearts Container -->
        <div class="flying-hearts-container absolute inset-0 pointer-events-none overflow-hidden" :id="`hearts-${session.containerId}`"></div>
      </div>
      
      <!-- Empty State -->
      <div v-if="displaySessions.length === 0" class="text-center py-8 text-galaxy-textMuted text-xs">
        <p>No other active sessions</p>
        <p class="opacity-50 mt-1">Be the first to start coding!</p>
      </div>
    </div>

    <!-- Full Screen Zoom Modal -->
    <Teleport to="body">
      <Transition
        enter-active-class="transition duration-300 ease-out"
        enter-from-class="opacity-0"
        enter-to-class="opacity-100"
        leave-active-class="transition duration-200 ease-in"
        leave-from-class="opacity-100"
        leave-to-class="opacity-0"
      >
        <div v-if="activeSession" class="fixed inset-0 z-[200] flex items-center justify-center bg-black/80 backdrop-blur-md p-8" @click.self="activeSession = null" @keydown.esc="activeSession = null">
          <Transition
            enter-active-class="transition duration-300 ease-out"
            enter-from-class="opacity-0 scale-90"
            enter-to-class="opacity-100 scale-100"
            leave-active-class="transition duration-200 ease-in"
            leave-from-class="opacity-100 scale-100"
            leave-to-class="opacity-0 scale-90"
          >
            <div v-if="activeSession" class="bg-[#0a0a0a] w-full max-w-4xl rounded-2xl border border-galaxy-border shadow-2xl shadow-galaxy-primary/20 overflow-hidden flex flex-col max-h-[80vh]">
              <!-- Modal Header -->
              <div class="flex items-center justify-between px-5 py-4 border-b border-galaxy-border bg-galaxy-surface/30">
                <div class="flex items-center gap-4">
                  <img :src="activeSession.avatar" class="w-10 h-10 rounded-full bg-galaxy-bg border-2 border-galaxy-primary/30" />
                  <div>
                    <div class="text-base font-bold text-galaxy-text">{{ activeSession.username }}</div>
                    <div class="text-xs text-galaxy-textMuted flex items-center gap-2">
                      <span class="w-2 h-2 rounded-full bg-galaxy-primary animate-pulse"></span>
                      <span>Live Session</span>
                      <span class="px-1.5 py-0.5 rounded bg-galaxy-surface border border-galaxy-border text-[10px] uppercase">{{ activeSession.os }}</span>
                    </div>
                  </div>
                </div>
                <button class="p-2 rounded-lg hover:bg-galaxy-surface text-galaxy-textMuted hover:text-galaxy-text transition-colors" @click="activeSession = null">
                  <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 18L18 6M6 6l12 12"></path></svg>
                </button>
              </div>
              
              <!-- Large Terminal View -->
              <div class="flex-1 min-h-[400px]" ref="modalTerminalRef"></div>
              
              <!-- Footer Info -->
              <div class="px-5 py-3 border-t border-galaxy-border bg-galaxy-surface/20 flex justify-between items-center">
                <span class="text-[10px] text-galaxy-textMuted">🔄 Auto-refreshing every 3s</span>
                <span class="text-[10px] text-galaxy-textMuted italic">Double-click card to view • ESC or click outside to close</span>
              </div>
            </div>
          </Transition>
        </div>
      </Transition>
    </Teleport>

    <!-- Vertical Resizer -->
    <div 
      @mousedown="startVerticalResize"
      class="h-1 bg-galaxy-border hover:bg-galaxy-accent/50 cursor-row-resize transition-colors shrink-0"
      :class="{'bg-galaxy-accent': isVerticalResizing}"
    ></div>

    <!-- Chat Area -->
    <div class="border-t border-galaxy-border bg-galaxy-bg/30 backdrop-blur-sm flex flex-col shrink-0" :style="{height: chatHeight + 'px'}">
       <div class="flex-1 p-4 space-y-3 overflow-y-auto text-xs" ref="chatContainer">
          <div v-for="(msg, index) in messages" :key="index" class="flex gap-2 animate-fadeIn">
             <span 
               class="font-bold shrink-0 cursor-pointer hover:underline" 
               :class="msg.isMe ? 'text-galaxy-accent' : 'text-galaxy-primary'"
               @click="mentionUser(msg.user)"
               :title="'点击@' + msg.user"
             >{{ msg.user }}</span>
             <div class="flex-1 min-w-0">
               <img v-if="isImage(msg.content)" :src="msg.content" class="max-w-[200px] max-h-[150px] rounded border border-galaxy-border cursor-pointer hover:border-galaxy-accent hover:scale-105 transition-all" @click="openImagePreview(msg.content)" />
               <span v-else class="text-galaxy-text leading-relaxed break-all">{{ msg.content }}</span>
             </div>
          </div>
       </div>
       <div class="p-3 border-t border-galaxy-border/50">
          <div v-if="isUploading" class="text-center text-xs text-galaxy-accent py-2">
            <span class="animate-pulse">Uploading image...</span>
          </div>
          <div v-else-if="cooldown > 0" class="text-center text-xs text-galaxy-textMuted py-2">
            Please wait {{ cooldown }}s before sending again
          </div>
          <input 
             v-else-if="currentUser?.provider !== 'guest'"
             v-model="inputMessage"
             @keyup.enter="sendMessage"
             @paste="handlePaste"
             type="text" 
             placeholder="Type a message or Ctrl+V paste image..." 
             class="w-full bg-galaxy-surfaceHighlight/50 border border-galaxy-border rounded-lg px-3 py-2 text-xs text-galaxy-text focus:outline-none focus:ring-1 focus:ring-galaxy-primary/50 transition-all placeholder-galaxy-textMuted/50"
           />
          <div v-else class="w-full bg-galaxy-surface/30 border border-galaxy-border/30 rounded-lg px-3 py-2 text-xs text-galaxy-textMuted text-center cursor-not-allowed select-none">
            Login to participate in chat
          </div>
       </div>
    </div>

    <!-- Image Preview Modal -->
    <Teleport to="body">
      <Transition
        enter-active-class="transition duration-300 ease-out"
        enter-from-class="opacity-0"
        enter-to-class="opacity-100"
        leave-active-class="transition duration-200 ease-in"
        leave-from-class="opacity-100"
        leave-to-class="opacity-0"
      >
        <div v-if="previewImage" class="fixed inset-0 z-[300] flex items-center justify-center bg-black/90 backdrop-blur-sm p-8" @click="closeImagePreview">
          <Transition
            enter-active-class="transition duration-300 ease-out"
            enter-from-class="opacity-0 scale-75"
            enter-to-class="opacity-100 scale-100"
            leave-active-class="transition duration-200 ease-in"
            leave-from-class="opacity-100 scale-100"
            leave-to-class="opacity-0 scale-75"
          >
            <img v-if="previewImage" :src="previewImage" class="max-w-[90vw] max-h-[90vh] rounded-lg shadow-2xl object-contain" @click.stop />
          </Transition>
          <button class="absolute top-4 right-4 text-white/70 hover:text-white p-2 rounded-full hover:bg-white/10 transition-colors" @click="closeImagePreview">
            <svg class="w-8 h-8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 18L18 6M6 6l12 12"></path></svg>
          </button>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<script setup lang="ts">
import { ref, nextTick, onMounted, onBeforeUnmount, watch, computed } from 'vue'
import { Terminal } from '@xterm/xterm'
import { FitAddon } from '@xterm/addon-fit'
import '@xterm/xterm/css/xterm.css'
import { createLobbySocket } from '../api'

interface Session {
  id: number
  containerId?: string
  username: string
  name?: string // Added name field
  os: string
  avatar: string
  snapshot?: string
  rawSnapshot?: string
  pinCount?: number
  helpers?: string[]  // List of usernames helping this session
}

const props = defineProps<{
  currentUser: {
    username: string;
    avatar: string | null;
    provider: string;
    os?: string;
    containerId?: string;  // Need this to check if user has active session
  } | null
}>()

const emit = defineEmits<{
  'invite-received': [data: { from: string; containerId: string }]
  'invite-accepted': [data: { helper: string; containerId: string }]
  'invite-rejected': [data: { helper: string }]
  'control-revoked': [data: { owner: string }]
  'helper-left': [data: { helper: string }]
  'helpers-updated': [helpers: string[]]  // New: current user's helpers list
  'send-invite': [data: { targetUsername: string }]
  'accept-invite': [data: { containerId: string }]
  'reject-invite': [data: { containerId: string }]
  'leave-helping': [data: { containerId: string }]
}>()

const activeSession = ref<Session | null>(null)
const modalTerminalRef = ref<HTMLElement | null>(null)
let modalTerminal: Terminal | null = null
let modalFitAddon: FitAddon | null = null

// Mini terminal instances map: containerId -> { term, fitAddon, lastSnapshot }
const miniTerminals = new Map<string, { term: Terminal, fitAddon: FitAddon, lastSnapshot: string }>()
const terminalRefs = new Map<string, HTMLElement>()

const setTerminalRef = (containerId: string | undefined, el: HTMLElement | null) => {
  if (containerId && el) {
    terminalRefs.set(containerId, el)
  }
}

const createMiniTerminal = (containerId: string, element: HTMLElement): { term: Terminal, fitAddon: FitAddon } => {
  const term = new Terminal({
    fontSize: 11,
    fontFamily: 'JetBrains Mono, Consolas, monospace',
    theme: {
      background: '#0a0a0a',
      foreground: '#e5e7eb',
      cursor: 'transparent',
      cursorAccent: 'transparent',
      selectionBackground: 'transparent',
    },
    cursorBlink: false,
    cursorStyle: 'bar',
    disableStdin: true,
    scrollback: 100,
    convertEol: true,
  })
  
  const fitAddon = new FitAddon()
  term.loadAddon(fitAddon)
  term.open(element)
  
  // Use setTimeout to ensure element is ready
  setTimeout(() => {
    try {
      fitAddon.fit()
    } catch (e) {
      // Ignore fit errors for small elements
    }
  }, 50)
  
  return { term, fitAddon }
}

const updateMiniTerminals = () => {
  for (const session of displaySessions.value) {
    if (!session.containerId || !session.rawSnapshot) continue
    
    const element = terminalRefs.get(session.containerId)
    if (!element) continue
    
    let termData = miniTerminals.get(session.containerId)
    
    // Create terminal if not exists
    if (!termData) {
      const { term, fitAddon } = createMiniTerminal(session.containerId, element)
      termData = { term, fitAddon, lastSnapshot: '' }
      miniTerminals.set(session.containerId, termData)
    }
    
    // Only update if snapshot changed
    if (session.rawSnapshot !== termData.lastSnapshot) {
      termData.term.clear()
      termData.term.write(session.rawSnapshot)
      termData.lastSnapshot = session.rawSnapshot
    }
  }
  
  // Clean up terminals for removed sessions
  const currentIds = new Set(displaySessions.value.map(s => s.containerId).filter(Boolean))
  for (const [id, data] of miniTerminals.entries()) {
    if (!currentIds.has(id)) {
      data.term.dispose()
      miniTerminals.delete(id)
    }
  }
}

const openSession = (session: Session) => {
  activeSession.value = session
  
  // Create modal terminal after next tick
  nextTick(() => {
    if (modalTerminalRef.value && session.rawSnapshot) {
      if (modalTerminal) {
        modalTerminal.dispose()
      }
      
      modalTerminal = new Terminal({
        fontSize: 14,
        fontFamily: 'JetBrains Mono, Consolas, monospace',
        theme: {
          background: '#030712',
          foreground: '#e5e7eb',
          cursor: 'transparent',
        },
        cursorBlink: false,
        disableStdin: true,
        scrollback: 500,
        convertEol: true,
      })
      
      modalFitAddon = new FitAddon()
      modalTerminal.loadAddon(modalFitAddon)
      modalTerminal.open(modalTerminalRef.value)
      
      setTimeout(() => {
        modalFitAddon?.fit()
        modalTerminal?.write(session.rawSnapshot || '')
      }, 100)
    }
  })
}

// Watch for active session updates
watch(() => activeSession.value?.containerId, () => {
  // Close modal terminal when session changes
}, { immediate: true })

// Chat State
const inputMessage = ref('')
const chatContainer = ref<HTMLElement | null>(null)
const messages = ref<{user: string; content: string; isMe: boolean}[]>([
  { user: 'System', content: 'Welcome to the study room!', isMe: false },
])

// Vertical resizer for chat area
const chatHeight = ref(256) // 16rem = 256px
const isVerticalResizing = ref(false)
const minChatHeight = 120
const maxChatHeight = 400

const startVerticalResize = (e: MouseEvent) => {
  isVerticalResizing.value = true
  document.addEventListener('mousemove', doVerticalResize)
  document.addEventListener('mouseup', stopVerticalResize)
  document.body.style.cursor = 'row-resize'
  document.body.style.userSelect = 'none'
}

const doVerticalResize = (e: MouseEvent) => {
  if (!isVerticalResizing.value) return
  const container = document.querySelector('.flex.flex-col.h-full')
  if (!container) return
  const rect = container.getBoundingClientRect()
  const newHeight = rect.bottom - e.clientY
  chatHeight.value = Math.min(maxChatHeight, Math.max(minChatHeight, newHeight))
}

const stopVerticalResize = () => {
  isVerticalResizing.value = false
  document.removeEventListener('mousemove', doVerticalResize)
  document.removeEventListener('mouseup', stopVerticalResize)
  document.body.style.cursor = ''
  document.body.style.userSelect = ''
}

// Image preview modal
const previewImage = ref<string | null>(null)

const openImagePreview = (src: string) => {
  previewImage.value = src
}

const closeImagePreview = () => {
  previewImage.value = null
}

// Lobby State
const onlineCount = ref(0)
const sessions = ref<Session[]>([])
const myPinnedSessions = ref<Set<string>>(new Set()) // Track sessions pinned by current user
let lobbySocket: ReturnType<typeof createLobbySocket> | null = null

// Sort sessions: self first, then pinned by me, then others
const displaySessions = computed(() => {
  if (!props.currentUser) return sessions.value
  
  const myName = props.currentUser.username
  // Sort: self first, then my pinned sessions, then others by username
  return [...sessions.value].sort((a, b) => {
    // Self always first
    if (a.username === myName) return -1
    if (b.username === myName) return 1
    
    // Then by my local pinned status (pinned first)
    const aIsPinned = a.containerId && myPinnedSessions.value.has(a.containerId)
    const bIsPinned = b.containerId && myPinnedSessions.value.has(b.containerId)
    if (aIsPinned && !bIsPinned) return -1
    if (!aIsPinned && bIsPinned) return 1
    
    // Then by username alphabetically
    return a.username.localeCompare(b.username)
  })
})

// Update active session and mini terminals when snapshots update
watch(sessions, (newSessions) => {
  if (activeSession.value) {
    const updated = newSessions.find(s => s.containerId === activeSession.value?.containerId)
    if (updated) {
      activeSession.value = { ...updated }
      // Update modal terminal
      if (modalTerminal && updated.rawSnapshot) {
        modalTerminal.clear()
        modalTerminal.write(updated.rawSnapshot)
      }
    }
  }
  
  // Update mini terminals
  nextTick(() => {
    updateMiniTerminals()
  })
}, { deep: true })

const connectLobby = () => {
  if (!props.currentUser) return
  
  lobbySocket = createLobbySocket(
    props.currentUser.username,
    props.currentUser.os || 'linux',
    {
      onUsers: (count, sessionList) => {
        onlineCount.value = count
        sessions.value = sessionList || []
        
        // Find current user's session and emit helpers update
        if (props.currentUser) {
          const mySession = sessionList?.find(s => s.username === props.currentUser?.username)
          if (mySession && mySession.helpers) {
            emit('helpers-updated', mySession.helpers)
          } else {
            emit('helpers-updated', [])
          }
        }
      },
      onChat: (user, content, ts) => {
        messages.value.push({
          user,
          content,
          isMe: user === props.currentUser?.username
        })
        scrollToBottom()
      },
      onLike: (user, targetContainerId, targetUsername) => {
        // Show flying heart animation on the target card (no chat message)
        createFlyingHeart(targetContainerId)
      },
      onPin: (user, targetContainerId, targetUsername) => {
        // Silently handle pin (no chat message)
      },
      onUnpin: (user, targetContainerId) => {
        // Silently handle unpin
      },
      onHistory: (historyMessages) => {
        // Load historical messages at the beginning
        const historyList = historyMessages.map(m => ({
          user: m.user,
          content: m.content,
          isMe: m.user === props.currentUser?.username
        }))
        // Insert history at the beginning, keep welcome message first
        messages.value = [messages.value[0], ...historyList]
        scrollToBottom()
      },
      // Invite control callbacks
      onInvite: (from, fromContainerId) => {
        emit('invite-received', { from, containerId: fromContainerId })
      },
      onInviteAccepted: (helper, containerId) => {
        emit('invite-accepted', { helper, containerId })
      },
      onInviteRejected: (helper) => {
        emit('invite-rejected', { helper })
      },
      // New: invite sent confirmation
      onInviteSent: (content, inviteTo) => {
        messages.value.push({
          user: 'System',
          content: `✅ ${content}`,
          isMe: false
        })
        scrollToBottom()
      },
      // New: invite error (cooldown)
      onInviteError: (content, cooldownRemaining) => {
        messages.value.push({
          user: 'System',
          content: `⏳ ${content} (${cooldownRemaining}s)`,
          isMe: false
        })
        scrollToBottom()
      },
      // New: someone rejected our invite
      onInviteRejectedNotify: (rejecter, content) => {
        messages.value.push({
          user: 'System',
          content: `❌ ${content}`,
          isMe: false
        })
        scrollToBottom()
      },
      onControlRevoked: (owner) => {
        emit('control-revoked', { owner })
      },
      onHelperLeft: (helper) => {
        emit('helper-left', { helper })
      },
      // New: owner cancelled
      onOwnerCancel: (owner, content) => {
        messages.value.push({
          user: 'System',
          content: `🚫 ${content}`,
          isMe: false
        })
        scrollToBottom()
      },
      onError: (err) => {
        console.error('Lobby WS error:', err)
      }
    },
    (props.currentUser as any).name || props.currentUser.username,  // Pass display name
    props.currentUser.avatar || ''  // Pass avatar URL
  )
}

const sendMessage = async () => {
    if (!inputMessage.value.trim() || !lobbySocket) return
    if (cooldown.value > 0) return
    
    lobbySocket.sendChat(inputMessage.value)
    inputMessage.value = ''
    startCooldown()
}

// Anti-spam cooldown
const cooldown = ref(0)
const COOLDOWN_SECONDS = 3
let cooldownTimer: number | null = null

const startCooldown = () => {
  cooldown.value = COOLDOWN_SECONDS
  cooldownTimer = window.setInterval(() => {
    cooldown.value--
    if (cooldown.value <= 0 && cooldownTimer) {
      clearInterval(cooldownTimer)
      cooldownTimer = null
    }
  }, 1000)
}

// Image paste handling
const isUploading = ref(false)

const handlePaste = async (e: ClipboardEvent) => {
  const items = e.clipboardData?.items
  if (!items) return
  
  for (const item of items) {
    if (item.type.startsWith('image/')) {
      e.preventDefault()
      const file = item.getAsFile()
      if (!file) return
      
      // Convert to base64 and send as data URL
      isUploading.value = true
      try {
        const base64 = await fileToBase64(file)
        if (lobbySocket && cooldown.value === 0) {
          lobbySocket.sendChat(base64)
          startCooldown()
        }
      } catch (err) {
        console.error('Failed to process image:', err)
      } finally {
        isUploading.value = false
      }
      break
    }
  }
}

const fileToBase64 = (file: File): Promise<string> => {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result as string)
    reader.onerror = reject
    reader.readAsDataURL(file)
  })
}

// Like functionality with 10 second cooldown
const likeCooldown = ref(0)
let likeCooldownTimer: number | null = null

const handleLike = (session: Session) => {
  if (!lobbySocket || !session.containerId) return
  if (likeCooldown.value > 0) return // Cooldown active
  
  lobbySocket.sendLike(session.containerId)
  // Show local heart immediately for feedback
  createFlyingHeart(session.containerId)
  
  // Start 10 second cooldown
  likeCooldown.value = 10
  likeCooldownTimer = window.setInterval(() => {
    likeCooldown.value--
    if (likeCooldown.value <= 0 && likeCooldownTimer) {
      clearInterval(likeCooldownTimer)
      likeCooldownTimer = null
    }
  }, 1000)
}

// Pin functionality
const handlePin = (session: Session) => {
  if (!lobbySocket || !session.containerId) return
  const containerId = session.containerId
  
  if (myPinnedSessions.value.has(containerId)) {
    // Unpin
    lobbySocket.sendUnpin(containerId)
    myPinnedSessions.value.delete(containerId)
  } else {
    // Pin
    lobbySocket.sendPin(containerId)
    myPinnedSessions.value.add(containerId)
  }
}

const isPinned = (session: Session): boolean => {
  return session.containerId ? myPinnedSessions.value.has(session.containerId) : false
}

// Invite control functionality
const canInvite = (session: Session): boolean => {
  // Can invite if:
  // 1. Current user has an active session (containerId)
  // 2. This is not our own session
  if (!props.currentUser?.containerId) return false
  if (session.username === props.currentUser?.username) return false
  return true
}

const handleInvite = (session: Session) => {
  console.log('🎮 handleInvite called:', { session, lobbySocket: !!lobbySocket })
  if (!lobbySocket || !session.username) {
    console.log('❌ handleInvite aborted: lobbySocket or username missing')
    return
  }
  console.log('✅ Sending invite to:', session.username)
  lobbySocket.sendInvite(session.username)
  // Note: System message is now broadcasted by backend, no need to add locally
}

// Mention user - insert @username into input field
const mentionUser = (username: string) => {
  if (username === 'System') return // Don't mention system
  if (!inputMessage.value.includes(`@${username}`)) {
    inputMessage.value = `@${username} ${inputMessage.value}`.trim()
  }
}

// Flying heart animation
const createFlyingHeart = (containerId: string) => {
  const container = document.getElementById(`hearts-${containerId}`)
  if (!container) return
  
  // Create multiple hearts
  for (let i = 0; i < 5; i++) {
    setTimeout(() => {
      const heart = document.createElement('span')
      heart.className = 'flying-heart'
      heart.textContent = '❤️'
      heart.style.left = `${20 + Math.random() * 60}%`
      heart.style.bottom = '10px'
      container.appendChild(heart)
      
      // Remove after animation completes
      setTimeout(() => heart.remove(), 1500)
    }, i * 100)
  }
}

// Basic image URL detection (including base64 data URLs)
const isImage = (content: string) => {
  return content.startsWith('data:image/') ||
         /\.(jpg|jpeg|png|gif|webp|svg)$/i.test(content) || 
         /^https?:\/\/.*\.(jpg|jpeg|png|gif|webp|svg)(\?.*)?$/i.test(content);
}

const scrollToBottom = async () => {
    await nextTick()
    if (chatContainer.value) {
        chatContainer.value.scrollTop = chatContainer.value.scrollHeight
    }
}

// Expose methods for parent component to call
const sendInviteAccept = (containerId: string) => {
  if (lobbySocket) {
    lobbySocket.sendInviteAccept(containerId)
  }
}

const sendInviteReject = (containerId: string) => {
  if (lobbySocket) {
    lobbySocket.sendInviteReject(containerId)
  }
}

const sendHelperLeave = (containerId: string) => {
  if (lobbySocket) {
    lobbySocket.sendHelperLeave(containerId)
  }
}

const sendControlRevoke = (helperUsername: string) => {
  if (lobbySocket) {
    lobbySocket.sendControlRevoke(helperUsername)
  }
}

defineExpose({
  sendInviteAccept,
  sendInviteReject,
  sendHelperLeave,
  sendControlRevoke
})

watch(() => props.currentUser, (newUser, oldUser) => {
  if (newUser) {
    // Close existing connection before creating new one
    if (lobbySocket) {
      lobbySocket.close()
      lobbySocket = null
    }
    connectLobby()
  }
}, { immediate: true })

onMounted(() => {
    scrollToBottom()
})

onBeforeUnmount(() => {
  lobbySocket?.close()
  
  // Dispose all terminals
  for (const data of miniTerminals.values()) {
    data.term.dispose()
  }
  miniTerminals.clear()
  
  if (modalTerminal) {
    modalTerminal.dispose()
  }
})
</script>

<style scoped>
.animate-fadeIn {
    animation: fadeIn 0.3s ease-out;
}
@keyframes fadeIn {
    from { opacity: 0; transform: translateY(5px); }
    to { opacity: 1; transform: translateY(0); }
}

/* Hide scrollbar in mini terminals */
:deep(.xterm-viewport) {
  overflow: hidden !important;
}
:deep(.xterm-scroll-area) {
  visibility: hidden;
}

/* Flying hearts animation */
.flying-heart {
  position: absolute;
  font-size: 1.5rem;
  animation: flyUp 1.5s ease-out forwards;
  pointer-events: none;
  z-index: 100;
}

@keyframes flyUp {
  0% {
    opacity: 1;
    transform: translateY(0) scale(0.5) rotate(0deg);
  }
  50% {
    opacity: 1;
    transform: translateY(-60px) scale(1.2) rotate(-15deg);
  }
  100% {
    opacity: 0;
    transform: translateY(-120px) scale(0.8) rotate(15deg);
  }
}
</style>
