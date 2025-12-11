<template>
  <Transition
    enter-active-class="transition duration-500 ease-out"
    enter-from-class="opacity-0"
    enter-to-class="opacity-100"
    leave-active-class="transition duration-300 ease-in"
    leave-from-class="opacity-100"
    leave-to-class="opacity-0"
  >
    <div v-if="isOpen" class="fixed inset-0 z-[100] flex items-center justify-center p-4">
      <!-- Backdrop -->
      <div class="absolute inset-0 bg-[#020408] bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-galaxy-primary/20 via-galaxy-bg to-galaxy-bg">
         <div class="absolute inset-0 opacity-30" style="background-image: url('data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI0MDAiIGhlaWdodD0iNDAwIj48cmVjdCB3aWR0aD0iNDAwIj48L3JlY3Q+PGNpcmNsZSBjeD0iMjAwIiBjeT0iMjAwIiByPSIxIiBmaWxsPSJ3aGl0ZSIgb3BhY2l0eT0iMC41Ii8+PC9zdmc+')"></div>
      </div>

      <!-- Modal Card -->
      <div class="relative w-full max-w-md bg-galaxy-bg/80 backdrop-blur-xl border border-galaxy-border rounded-2xl shadow-[0_0_50px_rgba(45,212,191,0.1)] overflow-hidden flex flex-col z-10 transform transition-all duration-500">
        
        <div class="absolute top-0 left-0 w-full h-1 bg-gradient-to-r from-galaxy-primary via-galaxy-accent to-galaxy-primary animate-pulse"></div>

        <!-- STEP 1: LOGIN -->
        <div v-if="step === 'login'" class="p-10 flex flex-col items-center text-center animate-fadeIn">
            <div class="w-20 h-20 rounded-full bg-galaxy-surfaceHighlight flex items-center justify-center mb-8 shadow-inner ring-1 ring-galaxy-border group">
                <span class="text-4xl group-hover:scale-110 transition-transform duration-300">🚀</span>
            </div>

            <h2 class="text-3xl font-bold text-galaxy-text mb-3 tracking-tight font-sans">Linux Study Room</h2>
            <p class="text-base text-galaxy-textMuted mb-10 leading-relaxed max-w-xs">
              Collaborative Cloud Terminal.<br>
              <span class="text-xs opacity-70">Connect, Share, and Code together.</span>
            </p>

            <div class="w-full space-y-4">
                <button class="w-full py-3 px-4 bg-[#24292e] hover:bg-[#2f363d] text-white rounded-xl font-medium text-sm flex items-center justify-center gap-3 transition-all border border-galaxy-border/50 group shadow-lg hover:shadow-xl" @click="handleLogin('linuxdo')">
                    <svg class="w-5 h-5 fill-current" viewBox="0 0 24 24"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
                    <span>Login with LinuxDo</span>
                </button>

                <button class="w-full py-3 px-4 bg-galaxy-primary/10 hover:bg-galaxy-primary/20 text-galaxy-primary rounded-xl font-medium text-sm border border-galaxy-primary/20 transition-all hover:shadow-[0_0_15px_rgba(45,212,191,0.2)]" @click="handleLogin('guest')">
                    Enter as Guest
                </button>
            </div>
            
            <div class="mt-8 flex items-center gap-4 text-xs text-galaxy-textMuted opacity-60">
                <span>Free Tier</span>
                <span>•</span>
                <span>{{ onlineCount }} Online</span>
            </div>
        </div>

        <!-- STEP 2: SETUP (OS Selection) -->
        <div v-else-if="step === 'setup'" class="p-8 flex flex-col animate-fadeIn">
            <h2 class="text-xl font-bold text-galaxy-text mb-2">Initialize Environment</h2>
            <p class="text-xs text-galaxy-textMuted mb-6">Select your container distribution.</p>

            <div class="space-y-3 mb-6">
                <div 
                    class="p-4 rounded-xl border cursor-pointer transition-all flex items-center gap-4 hover:bg-galaxy-surfaceHighlight/30"
                    :class="selectedOS === 'alpine' ? 'border-galaxy-accent bg-galaxy-accent/10' : 'border-galaxy-border bg-galaxy-surface/20'"
                    @click="selectedOS = 'alpine'"
                >
                    <div class="w-10 h-10 rounded-full bg-blue-900/50 flex items-center justify-center text-blue-200 font-bold border border-blue-500/30">A</div>
                    <div class="flex-1">
                        <div class="flex items-center justify-between">
                            <span class="font-medium text-sm text-galaxy-text">Alpine Linux</span>
                            <span class="text-[10px] px-2 py-0.5 rounded-full bg-galaxy-surface border border-galaxy-border text-galaxy-textMuted">5MB</span>
                        </div>
                        <p class="text-xs text-galaxy-textMuted mt-1">Minimalist, secure, and fast.</p>
                    </div>
                </div>

                <div 
                    class="p-4 rounded-xl border cursor-pointer transition-all flex items-center gap-4 hover:bg-galaxy-surfaceHighlight/30"
                    :class="selectedOS === 'debian' ? 'border-galaxy-accent bg-galaxy-accent/10' : 'border-galaxy-border bg-galaxy-surface/20'"
                    @click="selectedOS = 'debian'"
                >
                     <div class="w-10 h-10 rounded-full bg-red-900/50 flex items-center justify-center text-red-200 font-bold border border-red-500/30">D</div>
                    <div class="flex-1">
                        <div class="flex items-center justify-between">
                            <span class="font-medium text-sm text-galaxy-text">Debian Slim</span>
                            <span class="text-[10px] px-2 py-0.5 rounded-full bg-galaxy-primary/20 border border-galaxy-primary/30 text-galaxy-primary">Recommended</span>
                        </div>
                        <p class="text-xs text-galaxy-textMuted mt-1">Stable, glibc-based, user friendly.</p>
                    </div>
                </div>
            </div>

            <!-- Lifecycle Info -->
            <div class="bg-galaxy-surface/30 rounded-lg p-3 border border-galaxy-border/30 mb-6">
                <h4 class="text-xs font-bold text-galaxy-text mb-1 flex items-center gap-2">
                    <span class="w-1.5 h-1.5 rounded-full bg-green-500"></span> Container Policy
                </h4>
                <ul class="text-[10px] text-galaxy-textMuted space-y-1 pl-3 list-disc">
                    <li>Each user has <span class="text-galaxy-text">one persistent container</span>.</li>
                    <li>Container stops on disconnect and resumes on reconnect.</li>
                </ul>
            </div>

            <button 
                :disabled="isLaunching"
                class="w-full py-3 bg-galaxy-primary hover:bg-galaxy-accent text-black font-bold rounded-xl transition-all shadow-[0_0_20px_rgba(45,212,191,0.3)] disabled:opacity-50 disabled:cursor-wait flex items-center justify-center gap-2" 
                @click="launchContainer"
            >
                <span v-if="isLaunching" class="w-4 h-4 border-2 border-black border-t-transparent rounded-full animate-spin"></span>
                <span>{{ isLaunching ? 'Launching...' : 'Launch Container' }}</span>
            </button>
            
            <p v-if="launchError" class="mt-3 text-xs text-galaxy-danger text-center">{{ launchError }}</p>
        </div>

      </div>
    </div>
  </Transition>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue'
import { containerApi, authApi } from '../api'

const props = defineProps<{
  isOpen: boolean,
  initialStep?: 'login' | 'setup'
}>()

const emit = defineEmits(['login'])

const step = ref<'login' | 'setup'>('login')
const selectedOS = ref<'alpine' | 'debian'>('debian')
const isLaunching = ref(false)
const launchError = ref('')
const onlineCount = ref(1337) // Will be updated via lobby WS

watch(() => props.isOpen, (newVal) => {
    if (newVal) {
        step.value = props.initialStep || 'login'
        launchError.value = ''
    }
})

watch(() => props.initialStep, (newVal) => {
    if (newVal) {
        step.value = newVal
    }
})

// Get or create stable username (persisted in localStorage for testing)
const getStableUsername = () => {
    const stored = localStorage.getItem('lsr_username')
    if (stored) return stored
    const newUsername = 'User_' + Math.random().toString(36).substring(2, 8)
    localStorage.setItem('lsr_username', newUsername)
    return newUsername
}

const handleLogin = async (provider: string) => {
    if (provider === 'guest') {
        // Guest skips setup
         emit('login', {
            username: 'Guest_' + Math.floor(Math.random() * 9999),
            name: 'Guest User',
            avatar: null,
            provider: 'guest',
            containerId: null
        })
    } else if (provider === 'linuxdo') {
        // Redirect to LinuxDo OAuth
        window.location.href = authApi.getLoginUrl()
    } else {
        // Fallback: Use stable username (from localStorage or generate new)
        const username = getStableUsername()
        
        try {
            // Check if user already has a container
            const checkResult = await containerApi.check(username)
            
            if (checkResult.has_container) {
                // User has existing container, start it directly
                isLaunching.value = true
                const result = await containerApi.launch(checkResult.os_type, username)
                isLaunching.value = false
                
                if (result.error) {
                    throw new Error(result.error)
                }
                
                emit('login', {
                    username: result.username || username,
                    name: username, // Will be updated by App.vue from API if possible, but here we fallback
                    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=' + username,
                    provider: 'linuxdo',
                    containerId: result.container_id,
                    os: result.os_type
                })
                return
            }
        } catch (err) {
            console.log('Check failed, showing setup:', err)
        }
        
        // No existing container, show setup
        step.value = 'setup'
    }
}

const launchContainer = async () => {
    isLaunching.value = true
    launchError.value = ''
    
    // Use stable username (same as handleLogin)
    const username = getStableUsername()
    
    try {
        const result = await containerApi.launch(selectedOS.value, username)
        
        if (result.error) {
            throw new Error(result.error)
        }
        
        emit('login', {
            username: result.username || username,
            name: username,
            avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=' + username,
            provider: 'linuxdo',
            containerId: result.container_id,
            os: selectedOS.value
        })
    } catch (err) {
        launchError.value = (err as Error).message || 'Failed to launch container'
    } finally {
        isLaunching.value = false
    }
}
</script>

<style scoped>
.animate-fadeIn {
    animation: fadeIn 0.4s ease-out;
}
@keyframes fadeIn {
    from { opacity: 0; transform: translateY(5px); }
    to { opacity: 1; transform: translateY(0); }
}
</style>
