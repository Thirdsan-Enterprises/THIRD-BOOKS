<template>
  <AdminLayout>
    <div class="px-4 sm:px-6 lg:px-8">
      <!-- Header -->
      <div class="sm:flex sm:items-center sm:justify-between mb-6">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Audit Logs</h1>
          <p class="mt-2 text-sm text-gray-700">Complete activity trail across all tenants</p>
        </div>
        <div class="mt-4 sm:mt-0">
          <button @click="exportLogs" class="btn-primary">
            Export to CSV
          </button>
        </div>
      </div>

      <!-- Filters -->
      <div class="card mb-6">
        <div class="grid grid-cols-1 gap-4 sm:grid-cols-5">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Search</label>
            <input
              v-model="filters.search"
              type="text"
              placeholder="Action, entity..."
              class="input"
              @input="debouncedSearch"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Action</label>
            <select v-model="filters.action" @change="loadLogs" class="input">
              <option value="">All Actions</option>
              <option value="tenant.created">Tenant Created</option>
              <option value="tenant.suspended">Tenant Suspended</option>
              <option value="tenant.activated">Tenant Activated</option>
              <option value="user.created">User Created</option>
              <option value="user.updated">User Updated</option>
              <option value="user.deleted">User Deleted</option>
              <option value="user.deactivated">User Deactivated</option>
              <option value="user.activated">User Activated</option>
              <option value="user.impersonated">User Impersonated</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">From Date</label>
            <input
              v-model="filters.from_date"
              type="date"
              class="input"
              @change="loadLogs"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">To Date</label>
            <input
              v-model="filters.to_date"
              type="date"
              class="input"
              @change="loadLogs"
            />
          </div>
          <div class="flex items-end">
            <button @click="resetFilters" class="btn-secondary w-full">Reset Filters</button>
          </div>
        </div>
      </div>

      <!-- Statistics -->
      <div v-if="statistics" class="grid grid-cols-1 gap-5 sm:grid-cols-3 mb-6">
        <div class="card p-6">
          <dl>
            <dt class="text-sm font-medium text-gray-500">Total Logs (30d)</dt>
            <dd class="text-2xl font-semibold text-gray-900">
              {{ statistics.total_logs }}
            </dd>
          </dl>
        </div>
        <div class="card p-6">
          <dl>
            <dt class="text-sm font-medium text-gray-500">Top Action</dt>
            <dd class="text-lg font-semibold text-gray-900">
              {{ getTopAction() }}
            </dd>
          </dl>
        </div>
        <div class="card p-6">
          <dl>
            <dt class="text-sm font-medium text-gray-500">Critical Actions (30d)</dt>
            <dd class="text-2xl font-semibold text-red-600">
              {{ statistics.recent_critical }}
            </dd>
          </dl>
        </div>
      </div>

      <!-- Table -->
      <div class="card overflow-hidden">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Timestamp</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">User</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Action</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Entity</th>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">IP Address</th>
              <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Details</th>
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
            <tr v-else-if="logs.length === 0">
              <td colspan="6" class="px-6 py-4 text-center text-sm text-gray-500">
                No audit logs found
              </td>
            </tr>
            <tr v-else v-for="log in logs" :key="log.id" class="hover:bg-gray-50">
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                {{ formatDateTime(log.created_at) }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm font-medium text-gray-900">
                  {{ log.user?.name || 'System' }}
                </div>
                <div class="text-sm text-gray-500">{{ log.user?.email }}</div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span :class="getActionBadgeClass(log.action)" class="badge">
                  {{ log.action }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                <div v-if="log.entity_type">
                  <div class="font-medium text-gray-900">{{ log.entity_type }}</div>
                  <div class="text-xs text-gray-500">ID: {{ log.entity_id }}</div>
                </div>
                <div v-else class="text-gray-400">-</div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {{ log.ip_address || '-' }}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <button
                  @click="showDetails(log)"
                  class="text-blue-600 hover:text-blue-900"
                >
                  View Details
                </button>
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
                  ({{ pagination.total }} total)
                </p>
              </div>
              <div>
                <nav class="relative z-0 inline-flex rounded-md shadow-sm -space-x-px">
                  <button
                    v-for="page in visiblePages"
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

    <!-- Details Modal -->
    <div
      v-if="selectedLog"
      class="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center z-50"
      @click="selectedLog = null"
    >
      <div class="bg-white rounded-lg shadow-xl max-w-2xl w-full m-4 max-h-[90vh] overflow-auto" @click.stop>
        <div class="px-6 py-4 border-b border-gray-200">
          <h3 class="text-lg font-medium text-gray-900">Audit Log Details</h3>
        </div>
        <div class="px-6 py-4">
          <dl class="grid grid-cols-1 gap-4">
            <div>
              <dt class="text-sm font-medium text-gray-500">ID</dt>
              <dd class="mt-1 text-sm text-gray-900">{{ selectedLog.id }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Action</dt>
              <dd class="mt-1">
                <span :class="getActionBadgeClass(selectedLog.action)" class="badge">
                  {{ selectedLog.action }}
                </span>
              </dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">User</dt>
              <dd class="mt-1 text-sm text-gray-900">
                {{ selectedLog.user?.name || 'System' }}
                <span v-if="selectedLog.user" class="text-gray-500">({{ selectedLog.user.email }})</span>
              </dd>
            </div>
            <div v-if="selectedLog.entity_type">
              <dt class="text-sm font-medium text-gray-500">Entity</dt>
              <dd class="mt-1 text-sm text-gray-900">
                {{ selectedLog.entity_type }} (ID: {{ selectedLog.entity_id }})
              </dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Timestamp</dt>
              <dd class="mt-1 text-sm text-gray-900">{{ formatDateTime(selectedLog.created_at) }}</dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">IP Address</dt>
              <dd class="mt-1 text-sm text-gray-900">{{ selectedLog.ip_address || 'N/A' }}</dd>
            </div>
            <div v-if="selectedLog.user_agent">
              <dt class="text-sm font-medium text-gray-500">User Agent</dt>
              <dd class="mt-1 text-sm text-gray-900 break-all">{{ selectedLog.user_agent }}</dd>
            </div>
            <div v-if="selectedLog.changes">
              <dt class="text-sm font-medium text-gray-500">Changes</dt>
              <dd class="mt-1">
                <pre class="text-xs bg-gray-50 p-3 rounded overflow-auto">{{ JSON.stringify(selectedLog.changes, null, 2) }}</pre>
              </dd>
            </div>
            <div v-if="selectedLog.metadata">
              <dt class="text-sm font-medium text-gray-500">Metadata</dt>
              <dd class="mt-1">
                <pre class="text-xs bg-gray-50 p-3 rounded overflow-auto">{{ JSON.stringify(selectedLog.metadata, null, 2) }}</pre>
              </dd>
            </div>
          </dl>
        </div>
        <div class="px-6 py-4 border-t border-gray-200 flex justify-end">
          <button @click="selectedLog = null" class="btn-secondary">Close</button>
        </div>
      </div>
    </div>
  </AdminLayout>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import AdminLayout from '@/components/AdminLayout.vue'
import adminApi from '@/utils/admin-api'

const logs = ref<any[]>([])
const statistics = ref<any>(null)
const loading = ref(false)
const selectedLog = ref<any>(null)
const filters = ref({
  search: '',
  action: '',
  from_date: '',
  to_date: '',
})
const pagination = ref<any>(null)

let searchTimeout: any = null

onMounted(() => {
  loadLogs()
  loadStatistics()
})

const visiblePages = computed(() => {
  if (!pagination.value) return []

  const current = pagination.value.current_page
  const last = pagination.value.last_page
  const pages: number[] = []

  // Show current page and 2 pages on each side
  for (let i = Math.max(1, current - 2); i <= Math.min(last, current + 2); i++) {
    pages.push(i)
  }

  return pages
})

async function loadLogs(page = 1) {
  loading.value = true
  try {
    const params: any = { page, per_page: 50 }
    if (filters.value.search) params.search = filters.value.search
    if (filters.value.action) params.action = filters.value.action
    if (filters.value.from_date) params.from_date = filters.value.from_date
    if (filters.value.to_date) params.to_date = filters.value.to_date

    const response = await adminApi.getAuditLogs(params)
    logs.value = response.data.data
    pagination.value = {
      current_page: response.data.current_page,
      last_page: response.data.last_page,
      total: response.data.total,
    }
  } catch (error: any) {
    console.error('Failed to load audit logs:', error)
  } finally {
    loading.value = false
  }
}

async function loadStatistics() {
  try {
    const response = await adminApi.getAuditLogStatistics()
    statistics.value = response.data
  } catch (error: any) {
    console.error('Failed to load statistics:', error)
  }
}

function debouncedSearch() {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {
    loadLogs()
  }, 500)
}

function resetFilters() {
  filters.value = { search: '', action: '', from_date: '', to_date: '' }
  loadLogs()
}

function goToPage(page: number) {
  loadLogs(page)
}

function showDetails(log: any) {
  selectedLog.value = log
}

async function exportLogs() {
  try {
    const params: any = {}
    if (filters.value.from_date) params.from_date = filters.value.from_date
    if (filters.value.to_date) params.to_date = filters.value.to_date

    const response = await adminApi.exportAuditLogs(params)

    // Create download link
    const url = window.URL.createObjectURL(new Blob([response.data]))
    const link = document.createElement('a')
    link.href = url
    link.setAttribute('download', `audit_logs_${new Date().toISOString().split('T')[0]}.csv`)
    document.body.appendChild(link)
    link.click()
    link.remove()
  } catch (error: any) {
    alert('Failed to export logs: ' + (error.response?.data?.message || error.message))
  }
}

function getActionBadgeClass(action: string) {
  if (action.includes('created')) return 'bg-green-100 text-green-800'
  if (action.includes('updated')) return 'bg-blue-100 text-blue-800'
  if (action.includes('deleted') || action.includes('suspended')) return 'bg-red-100 text-red-800'
  if (action.includes('activated')) return 'bg-green-100 text-green-800'
  if (action.includes('impersonated')) return 'bg-purple-100 text-purple-800'
  return 'bg-gray-100 text-gray-800'
}

function formatDateTime(dateString: string) {
  const date = new Date(dateString)
  return date.toLocaleString()
}

function getTopAction() {
  if (!statistics.value?.by_action) return 'N/A'
  const actions = statistics.value.by_action
  const entries = Object.entries(actions)
  if (entries.length === 0) return 'N/A'
  const [action, count] = entries[0] as [string, number]
  return `${action} (${count})`
}
</script>
