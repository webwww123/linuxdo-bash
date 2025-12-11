<template>
  <Teleport to="body">
    <Transition
      enter-active-class="transition duration-300 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition duration-200 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div v-if="isOpen" class="fixed inset-0 z-[100] flex items-center justify-center bg-black/60 backdrop-blur-sm p-4" @click.self="$emit('close')">
        <Transition
          enter-active-class="transition duration-300 ease-out"
          enter-from-class="opacity-0 scale-95 translate-y-4"
          enter-to-class="opacity-100 scale-100 translate-y-0"
          leave-active-class="transition duration-200 ease-in"
          leave-from-class="opacity-100 scale-100 translate-y-0"
          leave-to-class="opacity-0 scale-95 translate-y-4"
        >
          <div v-if="isOpen" class="bg-galaxy-surface border border-galaxy-border rounded-xl shadow-2xl w-full max-w-md overflow-hidden flex flex-col max-h-[80vh]">
            <!-- Header -->
            <div class="px-6 py-4 border-b border-galaxy-border bg-galaxy-card/50 flex flex-col items-center relative">
               <button class="absolute right-4 top-4 p-2 rounded-lg hover:bg-galaxy-bg text-galaxy-textMuted hover:text-galaxy-text transition-colors" @click="$emit('close')">
                <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 18L18 6M6 6l12 12"></path></svg>
              </button>
              
              <div class="w-16 h-16 rounded-full bg-yellow-500/10 flex items-center justify-center mb-3 ring-1 ring-yellow-500/30">
                <span class="text-3xl">👑</span>
              </div>
              <h2 class="text-xl font-bold text-galaxy-text bg-clip-text text-transparent bg-gradient-to-r from-yellow-200 to-yellow-500">Linux 之王</h2>
              <p class="text-xs text-galaxy-textMuted mt-1">在线时长排行榜 Top 10</p>
            </div>

            <!-- List -->
            <div class="flex-1 overflow-y-auto p-4 space-y-2">
              <div v-if="loading" class="flex justify-center py-8">
                <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-galaxy-accent"></div>
              </div>
              
              <div v-else-if="entries.length === 0" class="text-center py-8 text-galaxy-textMuted">
                <p>暂无数据</p>
              </div>

              <div v-else v-for="(entry, index) in entries" :key="index" 
                class="flex items-center gap-3 p-3 rounded-lg border border-transparent transition-all hover:bg-galaxy-bg/50"
                :class="{'bg-galaxy-accent/10 border-galaxy-accent/20': index === 0, 'bg-galaxy-primary/5 border-galaxy-primary/10': index === 1 || index === 2}"
              >
                <!-- Rank -->
                <div class="w-8 h-8 flex items-center justify-center font-bold text-sm shrink-0" 
                  :class="{
                    'text-yellow-400 text-lg': index === 0,
                    'text-gray-300 text-base': index === 1,
                    'text-amber-600 text-base': index === 2,
                    'text-galaxy-textMuted': index > 2
                  }"
                >
                  {{ index + 1 }}
                </div>

                <!-- Avatar -->
                <img :src="entry.avatar" class="w-10 h-10 rounded-full bg-galaxy-bg border border-galaxy-border" />

                <!-- Info -->
                <div class="flex-1 min-w-0">
                  <div class="font-medium text-sm text-galaxy-text truncate">{{ entry.username }}</div>
                  <div class="text-[10px] text-galaxy-textMuted flex items-center gap-1">
                   <div class="flex-1 h-1.5 bg-galaxy-bg rounded-full overflow-hidden">
                      <div class="h-full bg-gradient-to-r from-galaxy-primary to-galaxy-accent rounded-full" :style="{width: getProgress(entry.totalSeconds) + '%'}"></div>
                   </div>
                  </div>
                </div>

                <!-- Time -->
                <div class="text-xs font-mono text-galaxy-accent shrink-0">
                  {{ entry.formattedTime }}
                </div>
              </div>
            </div>
            
            <!-- Footer -->
             <div class="px-6 py-3 border-t border-galaxy-border bg-galaxy-bg/30 text-[10px] text-galaxy-textMuted text-center">
              努力学习，成为 Linux 之王！
            </div>
          </div>
        </Transition>
      </div>
    </Transition>
  </Teleport>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { leaderboardApi } from '../api'

const props = defineProps<{
  isOpen: boolean
}>()

defineEmits(['close'])

interface LeaderboardEntry {
  rank: number
  username: string
  avatar: string
  totalSeconds: number
  formattedTime: string
}

const loading = ref(false)
const entries = ref<LeaderboardEntry[]>([])

const fetchLeaderboard = async () => {
  loading.value = true
  try {
    const data = await leaderboardApi.getLeaderboard()
    entries.value = data.entries || []
  } catch (e) {
    console.error('Failed to fetch leaderboard', e)
    entries.value = []
  } finally {
    loading.value = false
  }
}

// Fetch when opened
watch(() => props.isOpen, (newVal) => {
  if (newVal) {
    fetchLeaderboard()
  }
})

// Calculate progress bar relative to top user
const getProgress = (seconds: number) => {
  if (entries.value.length === 0) return 0
  const max = entries.value[0].totalSeconds
  return max > 0 ? (seconds / max) * 100 : 0
}
</script>
