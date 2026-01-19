<template>
  <router-view />
</template>

<script setup lang="ts">
import { onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'

const authStore = useAuthStore()

onMounted(async () => {
  // Fetch user data if token exists
  if (authStore.token) {
    await authStore.fetchUser()
  }
})
</script>
