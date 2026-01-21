<template>
  <AdminLayout>
    <div class="px-4 sm:px-6 lg:px-8">
      <!-- Header -->
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">Admin Dashboard</h1>
        <p class="mt-2 text-sm text-gray-600">System-wide overview and analytics</p>
      </div>

      <!-- Loading State -->
      <div v-if="loading" class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-red-600"></div>
        <p class="mt-2 text-sm text-gray-600">Loading dashboard...</p>
      </div>

      <!-- Dashboard Content -->
      <div v-else-if="dashboard" class="space-y-6">
        <!-- Overview Stats -->
        <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
          <div class="card p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-8 w-8 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Total Tenants</dt>
                  <dd class="flex items-baseline">
                    <div class="text-2xl font-semibold text-gray-900">
                      {{ dashboard.overview.total_tenants }}
                    </div>
                    <div class="ml-2 text-sm text-green-600">
                      {{ dashboard.overview.active_tenants }} active
                    </div>
                  </dd>
                </dl>
              </div>
            </div>
          </div>

          <div class="card p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-8 w-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Total Users</dt>
                  <dd class="flex items-baseline">
                    <div class="text-2xl font-semibold text-gray-900">
                      {{ dashboard.overview.total_users }}
                    </div>
                    <div class="ml-2 text-sm text-green-600">
                      {{ dashboard.overview.active_users }} active
                    </div>
                  </dd>
                </dl>
              </div>
            </div>
          </div>

          <div class="card p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-8 w-8 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">Trial Tenants</dt>
                  <dd class="flex items-baseline">
                    <div class="text-2xl font-semibold text-gray-900">
                      {{ dashboard.overview.trial_tenants }}
                    </div>
                  </dd>
                </dl>
              </div>
            </div>
          </div>

          <div class="card p-6">
            <div class="flex items-center">
              <div class="flex-shrink-0">
                <svg class="h-8 w-8 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <div class="ml-5 w-0 flex-1">
                <dl>
                  <dt class="text-sm font-medium text-gray-500 truncate">MRR</dt>
                  <dd class="flex items-baseline">
                    <div class="text-2xl font-semibold text-gray-900">
                      ${{ dashboard.revenue.mrr }}
                    </div>
                  </dd>
                </dl>
              </div>
            </div>
          </div>
        </div>

        <!-- Tenant Stats -->
        <div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
          <!-- By Plan -->
          <div class="card p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Tenants by Plan</h3>
            <div class="space-y-3">
              <div v-for="(count, plan) in dashboard.tenants.by_plan" :key="plan" class="flex items-center justify-between">
                <span class="text-sm font-medium text-gray-700 capitalize">{{ plan }}</span>
                <span class="text-sm font-semibold text-gray-900">{{ count }}</span>
              </div>
            </div>
          </div>

          <!-- By Status -->
          <div class="card p-6">
            <h3 class="text-lg font-medium text-gray-900 mb-4">Tenants by Status</h3>
            <div class="space-y-3">
              <div v-for="(count, status) in dashboard.tenants.by_status" :key="status" class="flex items-center justify-between">
                <span class="text-sm font-medium text-gray-700 capitalize">{{ status }}</span>
                <span :class="[
                  'text-sm font-semibold',
                  status === 'active' ? 'text-green-600' : status === 'suspended' ? 'text-red-600' : 'text-gray-600'
                ]">{{ count }}</span>
              </div>
            </div>
          </div>
        </div>

        <!-- User Stats -->
        <div class="card p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Users by Role</h3>
          <div class="grid grid-cols-2 md:grid-cols-5 gap-4">
            <div v-for="(count, role) in dashboard.users.by_role" :key="role" class="text-center">
              <div class="text-2xl font-bold text-gray-900">{{ count }}</div>
              <div class="text-sm text-gray-600 capitalize">{{ role }}</div>
            </div>
          </div>
        </div>

        <!-- Revenue Metrics -->
        <div class="grid grid-cols-1 gap-6 lg:grid-cols-3">
          <div class="card p-6">
            <h4 class="text-sm font-medium text-gray-500">Monthly Recurring Revenue</h4>
            <p class="mt-2 text-3xl font-bold text-gray-900">${{ dashboard.revenue.mrr }}</p>
          </div>
          <div class="card p-6">
            <h4 class="text-sm font-medium text-gray-500">Annual Recurring Revenue</h4>
            <p class="mt-2 text-3xl font-bold text-gray-900">${{ dashboard.revenue.arr }}</p>
          </div>
          <div class="card p-6">
            <h4 class="text-sm font-medium text-gray-500">Paying Tenants</h4>
            <p class="mt-2 text-3xl font-bold text-gray-900">{{ dashboard.revenue.paying_tenants }}</p>
          </div>
        </div>

        <!-- Recent Activity -->
        <div class="card p-6">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Recent Activity</h3>
          <div class="flow-root">
            <ul role="list" class="-mb-8">
              <li v-for="(activity, idx) in dashboard.activity.slice(0, 10)" :key="activity.id">
                <div class="relative pb-8">
                  <span v-if="idx !== dashboard.activity.slice(0, 10).length - 1" class="absolute top-4 left-4 -ml-px h-full w-0.5 bg-gray-200" aria-hidden="true"></span>
                  <div class="relative flex space-x-3">
                    <div>
                      <span class="h-8 w-8 rounded-full bg-gray-200 flex items-center justify-center ring-8 ring-white">
                        <svg class="h-5 w-5 text-gray-500" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clip-rule="evenodd" />
                        </svg>
                      </span>
                    </div>
                    <div class="flex min-w-0 flex-1 justify-between space-x-4 pt-1.5">
                      <div>
                        <p class="text-sm text-gray-500">
                          <span class="font-medium text-gray-900">{{ activity.user?.name || 'System' }}</span>
                          performed
                          <span class="font-medium text-gray-900">{{ activity.action }}</span>
                        </p>
                      </div>
                      <div class="whitespace-nowrap text-right text-sm text-gray-500">
                        {{ formatDate(activity.created_at) }}
                      </div>
                    </div>
                  </div>
                </div>
              </li>
            </ul>
          </div>
        </div>
      </div>

      <!-- Error State -->
      <div v-else-if="error" class="card p-6 text-center">
        <svg class="mx-auto h-12 w-12 text-red-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">Failed to load dashboard</h3>
        <p class="mt-1 text-sm text-gray-500">{{ error }}</p>
        <div class="mt-6">
          <button @click="loadDashboard" class="btn-primary">Try Again</button>
        </div>
      </div>
    </div>
  </AdminLayout>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AdminLayout from '@/components/AdminLayout.vue'
import adminApi from '@/utils/admin-api'

const dashboard = ref<any>(null)
const loading = ref(true)
const error = ref('')

onMounted(() => {
  loadDashboard()
})

async function loadDashboard() {
  loading.value = true
  error.value = ''
  try {
    const response = await adminApi.getDashboard()
    dashboard.value = response.data
  } catch (err: any) {
    error.value = err.response?.data?.message || 'Failed to load dashboard'
    console.error(err)
  } finally {
    loading.value = false
  }
}

function formatDate(dateString: string) {
  const date = new Date(dateString)
  const now = new Date()
  const diffMs = now.getTime() - date.getTime()
  const diffMins = Math.floor(diffMs / 60000)

  if (diffMins < 1) return 'Just now'
  if (diffMins < 60) return `${diffMins}m ago`
  if (diffMins < 1440) return `${Math.floor(diffMins / 60)}h ago`
  return date.toLocaleDateString()
}
</script>
