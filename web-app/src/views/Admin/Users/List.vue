<template>
  <AdminLayout>
    <div class="px-4 sm:px-6 lg:px-8">
      <!-- Header -->
      <div class="sm:flex sm:items-center sm:justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">User Management</h1>
          <p class="mt-2 text-sm text-gray-700">Manage users across all tenants</p>
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
              placeholder="Name or email..."
              class="input"
              @input="debouncedSearch"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Role</label>
            <select v-model="filters.role" @change="loadUsers" class="input">
              <option value="">All Roles</option>
              <option value="admin">Admin</option>
              <option value="accountant">Accountant</option>
              <option value="manager">Manager</option>
              <option value="user">User</option>
              <option value="viewer">Viewer</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Status</label>
            <select v-model="filters.is_active" @change="loadUsers" class="input">
              <option value="">All</option>
              <option value="true">Active</option>
              <option value="false">Inactive</option>
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
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Tenant</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Role</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
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
            <tr v-else-if="users.length === 0">
              <td colspan="6" class="px-6 py-4 text-center text-sm text-gray-500">
                No users found
              </td>
            </tr>
            <tr v-else v-for="user in users" :key="user.id" class="hover:bg-gray-50">
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center">
                  <div>
                    <div class="text-sm font-medium text-gray-900">{{ user.name }}</div>
                    <div class="text-sm text-gray-500">{{ user.email }}</div>
                  </div>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm text-gray-900">{{ user.tenant?.name }}</div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span :class="getRoleBadgeClass(user.role)" class="badge">
                  {{ user.role }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span :class="user.is_active ? 'badge bg-green-100 text-green-800' : 'badge bg-red-100 text-red-800'">
                  {{ user.is_active ? 'Active' : 'Inactive' }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {{ formatDate(user.created_at) }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <div class="flex justify-end gap-2">
                  <button
                    v-if="user.is_active"
                    @click="deactivateUser(user)"
                    class="text-red-600 hover:text-red-900"
                  >
                    Deactivate
                  </button>
                  <button
                    v-else
                    @click="activateUser(user)"
                    class="text-green-600 hover:text-green-900"
                  >
                    Activate
                  </button>
                  <button
                    @click="impersonateUser(user)"
                    class="text-blue-600 hover:text-blue-900"
                  >
                    Impersonate
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

const users = ref<any[]>([])
const loading = ref(false)
const filters = ref({
  search: '',
  role: '',
  is_active: '',
})
const pagination = ref<any>(null)

let searchTimeout: any = null

onMounted(() => {
  loadUsers()
})

async function loadUsers(page = 1) {
  loading.value = true
  try {
    const params: any = { page, per_page: 20 }
    if (filters.value.search) params.search = filters.value.search
    if (filters.value.role) params.role = filters.value.role
    if (filters.value.is_active) params.is_active = filters.value.is_active

    const response = await adminApi.getUsers(params)
    users.value = response.data.data
    pagination.value = {
      current_page: response.data.current_page,
      last_page: response.data.last_page,
      total: response.data.total,
    }
  } catch (error: any) {
    console.error('Failed to load users:', error)
  } finally {
    loading.value = false
  }
}

function debouncedSearch() {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {
    loadUsers()
  }, 500)
}

function resetFilters() {
  filters.value = { search: '', role: '', is_active: '' }
  loadUsers()
}

function goToPage(page: number) {
  loadUsers(page)
}

async function deactivateUser(user: any) {
  if (!confirm(`Are you sure you want to deactivate ${user.name}?`)) return

  try {
    await adminApi.deactivateUser(user.id)
    user.is_active = false
  } catch (error: any) {
    alert('Failed to deactivate user: ' + (error.response?.data?.message || error.message))
  }
}

async function activateUser(user: any) {
  try {
    await adminApi.activateUser(user.id)
    user.is_active = true
  } catch (error: any) {
    alert('Failed to activate user: ' + (error.response?.data?.message || error.message))
  }
}

async function impersonateUser(user: any) {
  if (!confirm(`Impersonate ${user.name}? You will be logged in as this user.`)) return

  try {
    const response = await adminApi.impersonateUser(user.id)
    const { token, tenant } = response.data

    // Save impersonation token
    localStorage.setItem('token', token)
    localStorage.setItem('tenant_id', tenant.id)

    // Redirect to tenant dashboard
    window.location.href = '/dashboard'
  } catch (error: any) {
    alert('Failed to impersonate user: ' + (error.response?.data?.message || error.message))
  }
}

function getRoleBadgeClass(role: string) {
  const classes: any = {
    admin: 'bg-red-100 text-red-800',
    accountant: 'bg-blue-100 text-blue-800',
    manager: 'bg-purple-100 text-purple-800',
    user: 'bg-green-100 text-green-800',
    viewer: 'bg-gray-100 text-gray-800',
  }
  return classes[role] || 'bg-gray-100 text-gray-800'
}

function formatDate(dateString: string) {
  return new Date(dateString).toLocaleDateString()
}
</script>
