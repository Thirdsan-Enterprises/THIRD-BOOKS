<template>
  <AdminLayout>
    <div class="px-4 sm:px-6 lg:px-8">
      <!-- Header -->
      <div class="sm:flex sm:items-center sm:justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Tenant Management</h1>
          <p class="mt-2 text-sm text-gray-700">Manage all registered tenants and subscriptions</p>
        </div>
      </div>

      <!-- Filters -->
      <div class="card mb-6">
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Search</label>
            <input
              v-model="filters.search"
              type="text"
              placeholder="Name, email, company..."
              class="input"
              @input="debouncedSearch"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
            <select v-model="filters.status" @change="loadTenants" class="input">
              <option value="">All Statuses</option>
              <option value="active">Active</option>
              <option value="suspended">Suspended</option>
              <option value="cancelled">Cancelled</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Plan</label>
            <select v-model="filters.plan" @change="loadTenants" class="input">
              <option value="">All Plans</option>
              <option value="trial">Trial</option>
              <option value="starter">Starter</option>
              <option value="professional">Professional</option>
              <option value="enterprise">Enterprise</option>
            </select>
          </div>
          <div class="flex items-end">
            <button @click="resetFilters" class="btn-secondary w-full">Reset Filters</button>
          </div>
        </div>
      </div>

      <!-- Table -->
      <div class="card overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Tenant</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Plan</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Users</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Created</th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr v-if="loading">
              <td colspan="6" class="px-6 py-4 text-center text-sm text-gray-500">
                <div class="flex justify-center">
                  <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-red-600"></div>
                </div>
              </td>
            </tr>
            <tr v-else-if="tenants.length === 0">
              <td colspan="6" class="px-6 py-4 text-center text-sm text-gray-500">
                No tenants found
              </td>
            </tr>
            <tr v-else v-for="tenant in tenants" :key="tenant.id" class="hover:bg-gray-50">
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center">
                  <div>
                    <div class="text-sm font-medium text-gray-900">{{ tenant.name }}</div>
                    <div class="text-sm text-gray-500">{{ tenant.email }}</div>
                  </div>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span :class="getPlanBadgeClass(tenant.plan)" class="badge">
                  {{ tenant.plan }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span :class="getStatusBadgeClass(tenant.status)" class="badge">
                  {{ tenant.status }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {{ tenant.users?.length || 0 }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {{ formatDate(tenant.created_at) }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <div class="flex justify-end gap-2">
                  <router-link :to="`/admin/tenants/${tenant.id}`" class="text-blue-600 hover:text-blue-900">
                    View
                  </router-link>
                  <button
                    v-if="tenant.status === 'active'"
                    @click="suspendTenant(tenant)"
                    class="text-red-600 hover:text-red-900"
                  >
                    Suspend
                  </button>
                  <button
                    v-else-if="tenant.status === 'suspended'"
                    @click="activateTenant(tenant)"
                    class="text-green-600 hover:text-green-900"
                  >
                    Activate
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <!-- Pagination -->
        <div v-if="pagination && pagination.last_page > 1" class="bg-white px-4 py-3 border-t border-gray-200 sm:px-6">
          <div class="flex items-center justify-between">
            <div class="flex-1 flex justify-between sm:hidden">
              <button
                @click="goToPage(pagination.current_page - 1)"
                :disabled="pagination.current_page === 1"
                class="btn-secondary"
              >
                Previous
              </button>
              <button
                @click="goToPage(pagination.current_page + 1)"
                :disabled="pagination.current_page === pagination.last_page"
                class="btn-secondary"
              >
                Next
              </button>
            </div>
            <div class="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
              <div>
                <p class="text-sm text-gray-700">
                  Showing page <span class="font-medium">{{ pagination.current_page }}</span> of
                  <span class="font-medium">{{ pagination.last_page }}</span>
                </p>
              </div>
              <div>
                <nav class="relative z-0 inline-flex rounded-md shadow-sm -space-x-px">
                  <button
                    v-for="page in pagination.last_page"
                    :key="page"
                    @click="goToPage(page)"
                    :class="[
                      'relative inline-flex items-center px-4 py-2 border text-sm font-medium',
                      page === pagination.current_page
                        ? 'z-10 bg-red-50 border-red-500 text-red-600'
                        : 'bg-white border-gray-300 text-gray-500 hover:bg-gray-50'
                    ]"
                  >
                    {{ page }}
                  </button>
                </nav>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </AdminLayout>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import AdminLayout from '@/components/AdminLayout.vue'
import adminApi from '@/utils/admin-api'

const router = useRouter()

const tenants = ref<any[]>([])
const loading = ref(false)
const filters = ref({
  search: '',
  status: '',
  plan: '',
})
const pagination = ref<any>(null)

let searchTimeout: any = null

onMounted(() => {
  loadTenants()
})

async function loadTenants(page = 1) {
  loading.value = true
  try {
    const params: any = { page, per_page: 20 }
    if (filters.value.search) params.search = filters.value.search
    if (filters.value.status) params.status = filters.value.status
    if (filters.value.plan) params.plan = filters.value.plan

    const response = await adminApi.getTenants(params)
    tenants.value = response.data.data
    pagination.value = {
      current_page: response.data.current_page,
      last_page: response.data.last_page,
      total: response.data.total,
    }
  } catch (error: any) {
    console.error('Failed to load tenants:', error)
  } finally {
    loading.value = false
  }
}

function debouncedSearch() {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {
    loadTenants()
  }, 500)
}

function resetFilters() {
  filters.value = { search: '', status: '', plan: '' }
  loadTenants()
}

function goToPage(page: number) {
  loadTenants(page)
}

async function suspendTenant(tenant: any) {
  if (!confirm(`Are you sure you want to suspend ${tenant.name}?`)) return

  try {
    await adminApi.suspendTenant(tenant.id)
    tenant.status = 'suspended'
  } catch (error: any) {
    alert('Failed to suspend tenant: ' + (error.response?.data?.message || error.message))
  }
}

async function activateTenant(tenant: any) {
  try {
    await adminApi.activateTenant(tenant.id)
    tenant.status = 'active'
  } catch (error: any) {
    alert('Failed to activate tenant: ' + (error.response?.data?.message || error.message))
  }
}

function getPlanBadgeClass(plan: string) {
  const classes: any = {
    trial: 'bg-yellow-100 text-yellow-800',
    starter: 'bg-blue-100 text-blue-800',
    professional: 'bg-purple-100 text-purple-800',
    enterprise: 'bg-green-100 text-green-800',
  }
  return classes[plan] || 'bg-gray-100 text-gray-800'
}

function getStatusBadgeClass(status: string) {
  const classes: any = {
    active: 'bg-green-100 text-green-800',
    suspended: 'bg-red-100 text-red-800',
    cancelled: 'bg-gray-100 text-gray-800',
  }
  return classes[status] || 'bg-gray-100 text-gray-800'
}

function formatDate(dateString: string) {
  return new Date(dateString).toLocaleDateString()
}
</script>
