<template>
  <div class="min-h-screen bg-gray-50">
    <!-- Navigation -->
    <nav class="bg-white shadow-sm">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex">
            <div class="flex-shrink-0 flex items-center">
              <router-link to="/dashboard" class="text-2xl font-bold text-primary-600">
                ThirdBooks
              </router-link>
            </div>
            <div class="hidden sm:ml-6 sm:flex sm:space-x-8">
              <router-link
                to="/dashboard"
                class="border-transparent hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium"
                active-class="!border-primary-500 !text-gray-900"
              >
                Dashboard
              </router-link>
              <router-link
                to="/invoices"
                class="border-transparent hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium"
                active-class="!border-primary-500 !text-gray-900"
              >
                Invoices
              </router-link>
              <router-link
                to="/customers"
                class="border-transparent hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium"
                active-class="!border-primary-500 !text-gray-900"
              >
                Customers
              </router-link>
              <router-link
                to="/bills"
                class="border-transparent hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium"
                active-class="!border-primary-500 !text-gray-900"
              >
                Bills
              </router-link>
              <router-link
                to="/vendors"
                class="border-transparent hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium"
                active-class="!border-primary-500 !text-gray-900"
              >
                Vendors
              </router-link>
              <router-link
                to="/accounts"
                class="border-transparent hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium"
                active-class="!border-primary-500 !text-gray-900"
              >
                Accounts
              </router-link>
              <router-link
                to="/reports"
                class="border-transparent hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium"
                active-class="!border-primary-500 !text-gray-900"
              >
                Reports
              </router-link>
            </div>
          </div>
          <div class="flex items-center space-x-4">
            <div class="text-sm text-gray-700">
              <div class="font-medium">{{ authStore.user?.name }}</div>
              <div class="text-xs text-gray-500">{{ authStore.tenant?.name }}</div>
            </div>
            <button
              @click="handleLogout"
              class="text-sm text-gray-500 hover:text-gray-700"
            >
              Logout
            </button>
          </div>
        </div>
      </div>
    </nav>

    <!-- Page Content -->
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
      <slot />
    </main>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const authStore = useAuthStore()

async function handleLogout() {
  await authStore.logout()
  router.push('/login')
}
</script>
