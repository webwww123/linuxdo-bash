<template>
  <div 
    v-if="isOpen && inviterName" 
    class="fixed inset-0 z-[250] flex items-center justify-center bg-black/70 backdrop-blur-sm p-4"
    @click.self="handleReject"
  >
    <div class="bg-galaxy-surface border border-galaxy-border rounded-2xl shadow-2xl shadow-galaxy-primary/20 max-w-sm w-full overflow-hidden">
      <!-- Header -->
      <div class="bg-gradient-to-r from-galaxy-primary/20 to-galaxy-accent/20 px-6 py-4 border-b border-galaxy-border">
        <div class="flex items-center gap-3">
          <span class="text-2xl">🎮</span>
          <h3 class="text-lg font-bold text-galaxy-text">协助控制邀请</h3>
        </div>
      </div>

      <!-- Content -->
      <div class="p-6 space-y-4">
        <div class="flex items-center gap-4">
          <img 
            :src="`https://api.dicebear.com/7.x/avataaars/svg?seed=${inviterName}`" 
            class="w-12 h-12 rounded-full bg-galaxy-bg border-2 border-galaxy-primary/30"
          />
          <div>
            <p class="text-galaxy-text font-medium">{{ inviterName }}</p>
            <p class="text-sm text-galaxy-textMuted">邀请你协助控制他的终端</p>
          </div>
        </div>

        <div class="bg-galaxy-bg/50 rounded-lg px-4 py-3 text-xs text-galaxy-textMuted space-y-1">
          <p>✓ 你可以在对方的终端中输入命令</p>
          <p>✓ 对方可以随时撤销你的控制权</p>
          <p>✓ 你也可以随时主动退出</p>
        </div>

        <!-- Countdown -->
        <div class="text-center text-xs text-galaxy-textMuted">
          <span>⏱️ 自动拒绝倒计时: </span>
          <span class="text-galaxy-accent font-mono">{{ countdown }}s</span>
        </div>
      </div>

      <!-- Actions -->
      <div class="px-6 pb-6 flex gap-3">
        <button
          @click="handleReject"
          class="flex-1 px-4 py-2.5 rounded-lg bg-galaxy-bg border border-galaxy-border text-galaxy-textMuted hover:text-galaxy-text hover:border-galaxy-textMuted/50 transition-colors text-sm font-medium"
        >
          拒绝
        </button>
        <button
          @click="handleAccept"
          class="flex-1 px-4 py-2.5 rounded-lg bg-gradient-to-r from-galaxy-primary to-galaxy-accent text-white font-medium text-sm hover:opacity-90 transition-opacity shadow-lg shadow-galaxy-primary/20"
        >
          同意协助
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, onBeforeUnmount } from 'vue'

const props = defineProps<{
  isOpen: boolean
  inviterName: string
  inviterContainerId: string
}>()

const emit = defineEmits<{
  accept: [containerId: string]
  reject: [containerId: string]
}>()

const countdown = ref(30)
let countdownTimer: number | null = null

const startCountdown = () => {
  countdown.value = 30
  stopCountdown()
  countdownTimer = window.setInterval(() => {
    countdown.value--
    if (countdown.value <= 0) {
      handleReject()
    }
  }, 1000)
}

const stopCountdown = () => {
  if (countdownTimer) {
    clearInterval(countdownTimer)
    countdownTimer = null
  }
}

const handleAccept = () => {
  stopCountdown()
  emit('accept', props.inviterContainerId)
}

const handleReject = () => {
  stopCountdown()
  emit('reject', props.inviterContainerId)
}

watch(() => props.isOpen, (open) => {
  if (open && props.inviterName) {
    startCountdown()
  } else {
    stopCountdown()
  }
}, { immediate: true })

onBeforeUnmount(() => {
  stopCountdown()
})
</script>
