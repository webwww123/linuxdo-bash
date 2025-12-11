<template>
  <div class="virtual-keyboard-bar bg-galaxy-bg/95 backdrop-blur border-t border-galaxy-border pb-safe z-50">
    <!-- Functional Keys -->
    <div class="flex text-galaxy-text text-sm">
      <button v-for="key in ['ESC', 'TAB', 'CTRL', 'ALT']" :key="key" 
              class="flex-1 py-3 active:bg-galaxy-surfaceHighlight border-r border-galaxy-border last:border-r-0 font-medium transition-colors text-galaxy-textMuted hover:text-galaxy-text">
        {{ key }}
      </button>
    </div>
    <!-- Symbol Keys -->
    <div class="flex bg-galaxy-surface/50 text-galaxy-accent text-lg">
       <button v-for="char in ['/', '-', '|', '>', 'PWD', 'LS']" :key="char" 
               class="flex-1 py-3 active:bg-galaxy-surfaceHighlight border-r border-galaxy-border border-t border-galaxy-border last:border-r-0 font-mono transition-colors hover:text-galaxy-primary">
        {{ char }}
      </button>
    </div>
  </div>
</template>

<script setup lang="ts">
// Logic for emitting key events would go here
</script>

<style scoped>
.pb-safe {
  padding-bottom: env(safe-area-inset-bottom);
}
</style>
