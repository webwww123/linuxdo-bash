<script setup lang="ts">
import { ref, onMounted } from 'vue'
import Terminal from './components/Terminal.vue'
import LiveWall from './components/LiveWall.vue'
import VirtualKeyboard from './components/VirtualKeyboard.vue'
import AuthModal from './components/AuthModal.vue'
import LeaderboardModal from './components/LeaderboardModal.vue'
import InviteModal from './components/InviteModal.vue'
import HelperTerminal from './components/HelperTerminal.vue'
import { authApi, containerApi } from './api'

// Defines user type
interface User {
  username: string;
  name?: string;
  avatar: string | null;
  provider: string;
  containerId?: string;
  os?: string;
  linuxdoId?: number;
  trustLevel?: number;
}

const currentUser = ref<User | null>(null)
// Mandatory login: Open by default
const isAuthModalOpen = ref(true)
const authModalStep = ref<'login' | 'setup'>('login')

// Handle OAuth callback on mount
onMounted(async () => {
  const urlParams = new URLSearchParams(window.location.search)
  const token = urlParams.get('token')
  const error = urlParams.get('error')
  
  // Clear URL params
  if (token || error) {
    window.history.replaceState({}, '', window.location.pathname)
  }
  
  if (error) {
    console.error('OAuth error:', error)
    return
  }
  
  if (token) {
    try {
      // Store token
      localStorage.setItem('lsr_token', token)
      
      // Get user info
      const userInfo = await authApi.me(token)
      console.log('LinuxDo user:', userInfo)
      
      // Build avatar URL from template
      let avatar = userInfo.avatar
      if (avatar && avatar.includes('{size}')) {
        avatar = 'https://linux.do' + avatar.replace('{size}', '120')
      }
      
      // Check if user has container
      const username = userInfo.username
      localStorage.setItem('lsr_username', username)
      
      try {
        const checkResult = await containerApi.check(username)
        if (checkResult.has_container) {
          // User has container, launch directly
          const result = await containerApi.launch(checkResult.os_type, username)
          
          currentUser.value = {
            username: username,
            name: userInfo.name,
            avatar: avatar,
            provider: 'linuxdo',
            containerId: result.container_id,
            os: result.os_type,
            linuxdoId: userInfo.id,
            trustLevel: userInfo.trust_level
          }
          isAuthModalOpen.value = false
          return
        }
      } catch (err) {
        console.log('No existing container, show setup')
      }
      
      // Store user info for setup step
      currentUser.value = {
        username: username,
        name: userInfo.name,
        avatar: avatar,
        provider: 'linuxdo',
        linuxdoId: userInfo.id,
        trustLevel: userInfo.trust_level
      }
      authModalStep.value = 'setup'
      
    } catch (err) {
      console.error('Failed to get user info:', err)
      localStorage.removeItem('lsr_token')
    }
  }
})

const handleLoginSuccess = (user: User) => {
  currentUser.value = user
  isAuthModalOpen.value = false
}

const openSetupWizard = () => {
    authModalStep.value = 'setup'
    isAuthModalOpen.value = true
}

const showAnnouncement = ref(true)
const isLeaderboardOpen = ref(false)

// Resizable sidebar
const sidebarWidth = ref(384) // 24rem = 384px
const isResizing = ref(false)
const minWidth = 280
const maxWidth = 600

const startResize = (e: MouseEvent) => {
  isResizing.value = true
  document.addEventListener('mousemove', doResize)
  document.addEventListener('mouseup', stopResize)
  document.body.style.cursor = 'col-resize'
  document.body.style.userSelect = 'none'
}

const doResize = (e: MouseEvent) => {
  if (!isResizing.value) return
  const newWidth = window.innerWidth - e.clientX
  sidebarWidth.value = Math.min(maxWidth, Math.max(minWidth, newWidth))
}

const stopResize = () => {
  isResizing.value = false
  document.removeEventListener('mousemove', doResize)
  document.removeEventListener('mouseup', stopResize)
  document.body.style.cursor = ''
  document.body.style.userSelect = ''
}

// ===== Invite Control State =====
const isInviteModalOpen = ref(false)
const pendingInvite = ref<{ from: string; containerId: string } | null>(null)

// Helper mode state
const isHelperMode = ref(false)
const helpingContainerId = ref<string | null>(null)
const helpingOwnerUsername = ref<string | null>(null)

// LiveWall ref for calling methods
const liveWallRef = ref<InstanceType<typeof LiveWall> | null>(null)

// Handle incoming invite
const handleInviteReceived = (data: { from: string; containerId: string }) => {
  console.log('🎮 App.vue: handleInviteReceived called with:', data)
  console.log('🎮 Current state - isInviteModalOpen:', isInviteModalOpen.value, 'pendingInvite:', pendingInvite.value)
  pendingInvite.value = data
  isInviteModalOpen.value = true
  console.log('🎮 After update - isInviteModalOpen:', isInviteModalOpen.value, 'pendingInvite:', pendingInvite.value)
}

// Accept invite - send to backend first, then enter helper mode
const handleInviteAccept = (containerId: string) => {
  isInviteModalOpen.value = false
  
  // Send accept message to backend via LiveWall's lobbySocket
  if (liveWallRef.value && pendingInvite.value) {
    liveWallRef.value.sendInviteAccept(containerId)
    
    // Wait a bit for backend to process, then enter helper mode
    setTimeout(() => {
      helpingContainerId.value = containerId
      helpingOwnerUsername.value = pendingInvite.value!.from
      isHelperMode.value = true
      pendingInvite.value = null
    }, 300)
  }
}

// Reject invite
const handleInviteReject = (containerId: string) => {
  isInviteModalOpen.value = false
  if (liveWallRef.value) {
    liveWallRef.value.sendInviteReject(containerId)
  }
  pendingInvite.value = null
}

// Exit helper mode (voluntary or revoked)
const handleExitHelperMode = () => {
  // Notify backend if we're leaving voluntarily
  if (helpingContainerId.value && liveWallRef.value) {
    liveWallRef.value.sendHelperLeave(helpingContainerId.value)
  }
  isHelperMode.value = false
  helpingContainerId.value = null
  helpingOwnerUsername.value = null
}

// Handle control revoked by owner
const handleControlRevoked = (data: { owner: string }) => {
  // Don't send helper_leave since we were revoked
  isHelperMode.value = false
  helpingContainerId.value = null
  helpingOwnerUsername.value = null
}

// Handle terminal container ready - update currentUser with containerId
const handleContainerReady = (containerId: string) => {
  if (currentUser.value) {
    currentUser.value = { ...currentUser.value, containerId }
  }
}
</script>

<template>
  <div class="h-screen w-screen bg-galaxy-bg text-galaxy-text flex overflow-hidden font-sans antialiased selection:bg-galaxy-primary/30 selection:text-galaxy-primary">
    
    <!-- Main Focus Area -->
    <main class="flex-1 min-w-0 flex flex-col relative z-10 transition-all duration-300 ease-in-out overflow-hidden">
      <!-- Full Width Glass Header -->
      <header class="absolute top-0 left-0 right-0 h-16 px-6 flex items-center justify-between z-50 bg-galaxy-bg/10 backdrop-blur-md border-b border-galaxy-border/20">
        
        <!-- Left: Brand -->
        <div class="flex items-center gap-3">
          <div class="w-2.5 h-2.5 rounded-full bg-galaxy-accent animate-pulse shadow-[0_0_10px_rgba(45,212,191,0.5)]"></div>
          <span class="font-sans font-medium text-sm tracking-wide text-galaxy-text">Linux Study Room</span>
        </div>

        <!-- Right: Actions -->
         <div class="flex items-center gap-4 text-sm font-medium">
            <span class="text-galaxy-textMuted flex items-center gap-2 px-3 py-1 rounded hover:bg-galaxy-surface/50 transition-colors cursor-default">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path></svg>
              Online
              Online
            </span>

            <button @click="isLeaderboardOpen = true" class="text-galaxy-textMuted hover:text-yellow-400 flex items-center gap-2 px-3 py-1 rounded hover:bg-galaxy-surface/50 transition-colors" title="Leaderboard">
              <span>🏆</span>
              <span class="hidden sm:inline">Leaderboard</span>
            </button>
            
            <template v-if="currentUser">
              <div class="flex items-center gap-3 pl-4 border-l border-galaxy-border/30">
                <div class="flex flex-col items-end leading-none">
                  <span class="text-xs font-bold text-galaxy-text">{{ currentUser.name || currentUser.username }}</span>
                  <span class="text-[10px] text-galaxy-accent uppercase tracking-wider">{{ currentUser.os || 'Guest' }}</span>
                </div>
                <img :src="currentUser.avatar || `https://api.dicebear.com/7.x/avataaars/svg?seed=${currentUser.username}`" class="w-8 h-8 rounded-full bg-galaxy-surface border border-galaxy-primary/30" />
              </div>
            </template>
        </div>
      </header>
      
      <!-- Announcement Banner -->
      <Transition
        enter-active-class="transition duration-300 ease-out"
        enter-from-class="-translate-y-full opacity-0"
        enter-to-class="translate-y-0 opacity-100"
        leave-active-class="transition duration-200 ease-in"
        leave-from-class="translate-y-0 opacity-100"
        leave-to-class="-translate-y-full opacity-0"
      >
        <div v-if="showAnnouncement" class="absolute top-16 left-0 right-0 z-40 bg-galaxy-accent/10 border-b border-galaxy-accent/20 backdrop-blur-md px-4 py-1.5 flex items-center justify-between shadow-[0_4px_20px_rgba(45,212,191,0.05)]">
            <div class="flex items-center gap-3 overflow-hidden">
                <span class="text-lg">📢</span>
                <div class="text-xs text-galaxy-text truncate flex items-center gap-1">
                   <span class="font-bold text-galaxy-accent">Notice:</span>
                   <!-- TODO: 暂时禁用清理功能提示 -->
                   <!-- <span>Please save your work locally. Containers are recycled after 20 mins of idle time.</span> -->
                   <span>Welcome to Linux Study Room! Practice Linux commands in a safe environment.</span>
                   <span class="opacity-50 mx-1">|</span>
                   <span class="italic text-galaxy-textMuted font-mono">by 不吃香菜</span>
                </div>
            </div>
            <button @click="showAnnouncement = false" class="text-galaxy-textMuted hover:text-galaxy-text transition-colors p-1">
                <svg class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 18L18 6M6 6l12 12"></path></svg>
            </button>
        </div>
      </Transition>

      <!-- Terminal Container -->
      <div class="flex-1 pt-12 pb-2 px-2 md:px-4 md:pt-[5.5rem] relative transition-all" :class="showAnnouncement ? 'mt-8' : 'mt-0'">
        <!-- Show helper terminal when in helper mode -->
        <HelperTerminal 
          v-if="isHelperMode && helpingContainerId && helpingOwnerUsername" 
          :key="'helper-' + helpingContainerId"
          :container-id="helpingContainerId" 
          :owner-username="helpingOwnerUsername"
          :helper-username="currentUser?.username || ''"
          @exit="handleExitHelperMode"
        />
        <!-- Own terminal - use v-show to keep WebSocket alive when in helper mode -->
        <Terminal 
          v-show="!isHelperMode"
          :key="'terminal-' + (currentUser?.containerId || 'none')"
          :user="currentUser" 
          @request-setup="openSetupWizard" 
          @container-ready="handleContainerReady"
        />
      </div>

      <!-- Virtual Keyboard (Mobile Only, User Only) -->
      <VirtualKeyboard v-if="currentUser?.provider !== 'guest'" class="md:hidden" />
    </main>

    <!-- Resizable Divider -->
    <div 
      @mousedown="startResize"
      class="w-1 bg-galaxy-border hover:bg-galaxy-accent/50 cursor-col-resize hidden md:block transition-colors z-30 flex-shrink-0"
      :class="{'bg-galaxy-accent': isResizing}"
    ></div>

    <!-- Side Wall (Desktop Only) -->
    <aside 
      class="border-l border-galaxy-border bg-galaxy-surface/10 backdrop-blur-xl hidden md:flex flex-col z-20 shadow-2xl flex-shrink-0"
      :style="{width: sidebarWidth + 'px'}"
    >
       <LiveWall 
         ref="liveWallRef"
         :current-user="currentUser" 
         @invite-received="handleInviteReceived"
         @control-revoked="handleControlRevoked"
       />
    </aside>

    <!-- Global Modals -->
    <AuthModal :is-open="isAuthModalOpen" :initial-step="authModalStep" @login="handleLoginSuccess" />
    <LeaderboardModal :is-open="isLeaderboardOpen" @close="isLeaderboardOpen = false" />
    
    <!-- Invite Modal -->
    <InviteModal 
      :is-open="isInviteModalOpen" 
      :inviter-name="pendingInvite?.from || ''"
      :inviter-container-id="pendingInvite?.containerId || ''"
      @accept="handleInviteAccept"
      @reject="handleInviteReject"
    />
  </div>
</template>
