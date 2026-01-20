<template>
  <div class="conflicts-page">
    <!-- Header -->
    <div class="flex justify-between items-center mb-6">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Sync Conflicts</h1>
        <p class="text-sm text-gray-600 mt-1">Resolve synchronization conflicts from multiple devices</p>
      </div>
      <div class="flex gap-3">
        <button
          v-if="hasSelectedConflicts"
          @click="showBulkResolveModal = true"
          class="btn-secondary"
        >
          Bulk Resolve ({{ selectedConflicts.length }})
        </button>
        <button @click="refreshConflicts" class="btn-secondary">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          Refresh
        </button>
      </div>
    </div>

    <!-- Statistics -->
    <div v-if="statistics" class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
      <div class="card p-4">
        <div class="text-sm text-gray-600">Total Conflicts</div>
        <div class="text-2xl font-bold text-gray-900 mt-1">{{ statistics.total }}</div>
      </div>
      <div class="card p-4">
        <div class="text-sm text-gray-600">Pending</div>
        <div class="text-2xl font-bold text-orange-600 mt-1">{{ statistics.pending }}</div>
      </div>
      <div class="card p-4">
        <div class="text-sm text-gray-600">Resolved</div>
        <div class="text-2xl font-bold text-green-600 mt-1">{{ statistics.resolved }}</div>
      </div>
      <div class="card p-4">
        <div class="text-sm text-gray-600">Auto-Resolved</div>
        <div class="text-2xl font-bold text-blue-600 mt-1">{{ autoResolvedCount }}</div>
      </div>
    </div>

    <!-- Filters -->
    <div class="card mb-6">
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Status</label>
          <select v-model="filters.status" class="input">
            <option value="">All Statuses</option>
            <option value="pending">Pending</option>
            <option value="resolved">Resolved</option>
            <option value="ignored">Ignored</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Entity Type</label>
          <select v-model="filters.aggregate_type" class="input">
            <option value="">All Types</option>
            <option value="invoice">Invoices</option>
            <option value="bill">Bills</option>
            <option value="customer">Customers</option>
            <option value="vendor">Vendors</option>
            <option value="payment">Payments</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Conflict Type</label>
          <select v-model="filters.conflict_type" class="input">
            <option value="">All Conflict Types</option>
            <option value="concurrent_update">Concurrent Update</option>
            <option value="delete_modified">Delete-Modify Conflict</option>
          </select>
        </div>
      </div>
    </div>

    <!-- Conflicts List -->
    <div v-if="loading" class="text-center py-12">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
      <p class="mt-2 text-sm text-gray-600">Loading conflicts...</p>
    </div>

    <div v-else-if="conflicts.length === 0" class="card text-center py-12">
      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      <h3 class="mt-2 text-sm font-medium text-gray-900">No conflicts found</h3>
      <p class="mt-1 text-sm text-gray-500">All synchronization conflicts have been resolved.</p>
    </div>

    <div v-else class="space-y-4">
      <div v-for="conflict in conflicts" :key="conflict.id" class="card hover:shadow-md transition-shadow">
        <div class="flex items-start justify-between">
          <div class="flex items-start flex-1">
            <!-- Checkbox -->
            <input
              v-if="conflict.status === 'pending'"
              type="checkbox"
              :value="conflict.id"
              v-model="selectedConflicts"
              class="mt-1 mr-4"
            />

            <!-- Conflict Details -->
            <div class="flex-1">
              <div class="flex items-center gap-3 mb-2">
                <span :class="getStatusBadgeClass(conflict.status)" class="badge">
                  {{ conflict.status }}
                </span>
                <span :class="getTypeBadgeClass(conflict.conflict_type)" class="badge">
                  {{ formatConflictType(conflict.conflict_type) }}
                </span>
                <span class="text-sm font-medium text-gray-900">
                  {{ formatAggregateType(conflict.aggregate_type) }}
                </span>
              </div>

              <div class="text-sm text-gray-600 mb-3">
                <p>Aggregate ID: <code class="text-xs bg-gray-100 px-2 py-1 rounded">{{ conflict.aggregate_id }}</code></p>
                <p class="mt-1">Devices: {{ conflict.server_device_id || 'Server' }} ⟷ {{ conflict.client_device_id }}</p>
                <p class="mt-1">Created: {{ formatDate(conflict.created_at) }}</p>
                <p v-if="conflict.resolved_at" class="mt-1">Resolved: {{ formatDate(conflict.resolved_at) }} by {{ conflict.resolved_by }}</p>
              </div>

              <!-- Conflict Fields -->
              <div v-if="conflict.conflict_fields && conflict.conflict_fields.length > 0" class="mb-3">
                <div class="text-xs font-medium text-gray-700 mb-1">Conflicting Fields:</div>
                <div class="flex flex-wrap gap-1">
                  <span
                    v-for="field in conflict.conflict_fields"
                    :key="field"
                    class="text-xs bg-red-50 text-red-700 px-2 py-1 rounded"
                  >
                    {{ field }}
                  </span>
                </div>
              </div>

              <!-- Data Comparison -->
              <div v-if="conflict.status === 'pending'" class="grid grid-cols-2 gap-4 mt-4">
                <div class="border border-blue-200 rounded-lg p-3 bg-blue-50">
                  <div class="text-xs font-medium text-blue-900 mb-2">Server Version</div>
                  <pre class="text-xs text-blue-800 overflow-auto max-h-32">{{ JSON.stringify(conflict.server_data, null, 2) }}</pre>
                </div>
                <div class="border border-purple-200 rounded-lg p-3 bg-purple-50">
                  <div class="text-xs font-medium text-purple-900 mb-2">Client Version</div>
                  <pre class="text-xs text-purple-800 overflow-auto max-h-32">{{ JSON.stringify(conflict.client_data, null, 2) }}</pre>
                </div>
              </div>

              <!-- Resolved Data -->
              <div v-if="conflict.status === 'resolved' && conflict.resolved_data" class="mt-4">
                <div class="border border-green-200 rounded-lg p-3 bg-green-50">
                  <div class="text-xs font-medium text-green-900 mb-2">
                    Resolved Data ({{ conflict.resolution_strategy }})
                  </div>
                  <pre class="text-xs text-green-800 overflow-auto max-h-32">{{ JSON.stringify(conflict.resolved_data, null, 2) }}</pre>
                </div>
              </div>
            </div>
          </div>

          <!-- Actions -->
          <div v-if="conflict.status === 'pending'" class="ml-4 flex gap-2">
            <button
              @click="resolveWithServer(conflict.id)"
              class="btn-sm btn-secondary"
              title="Use server version"
            >
              Use Server
            </button>
            <button
              @click="resolveWithClient(conflict.id)"
              class="btn-sm btn-secondary"
              title="Use client version"
            >
              Use Client
            </button>
            <button
              @click="openMergeModal(conflict)"
              class="btn-sm btn-primary"
              title="Merge manually"
            >
              Merge
            </button>
            <button
              @click="ignoreConflict(conflict.id)"
              class="btn-sm btn-secondary text-gray-600"
              title="Ignore this conflict"
            >
              Ignore
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Pagination -->
    <div v-if="pagination && pagination.last_page > 1" class="mt-6 flex justify-center">
      <nav class="flex gap-2">
        <button
          v-for="page in pagination.last_page"
          :key="page"
          @click="goToPage(page)"
          :class="[
            'px-4 py-2 rounded-lg text-sm font-medium transition-colors',
            page === pagination.current_page
              ? 'bg-primary-600 text-white'
              : 'bg-white text-gray-700 hover:bg-gray-50 border'
          ]"
        >
          {{ page }}
        </button>
      </nav>
    </div>

    <!-- Merge Modal -->
    <div v-if="showMergeModal && selectedConflict" class="modal-overlay" @click.self="showMergeModal = false">
      <div class="modal-content max-w-4xl">
        <div class="flex justify-between items-center mb-4">
          <h3 class="text-lg font-semibold">Merge Conflict Data</h3>
          <button @click="showMergeModal = false" class="text-gray-400 hover:text-gray-600">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">Merged Data (JSON)</label>
          <textarea
            v-model="mergedDataJson"
            class="input font-mono text-xs"
            rows="15"
            placeholder="Edit the JSON to create the merged version"
          ></textarea>
        </div>

        <div class="flex justify-end gap-3">
          <button @click="showMergeModal = false" class="btn-secondary">Cancel</button>
          <button @click="submitMerge" class="btn-primary">Resolve with Merged Data</button>
        </div>
      </div>
    </div>

    <!-- Bulk Resolve Modal -->
    <div v-if="showBulkResolveModal" class="modal-overlay" @click.self="showBulkResolveModal = false">
      <div class="modal-content">
        <div class="flex justify-between items-center mb-4">
          <h3 class="text-lg font-semibold">Bulk Resolve Conflicts</h3>
          <button @click="showBulkResolveModal = false" class="text-gray-400 hover:text-gray-600">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <p class="text-sm text-gray-600 mb-4">
          Resolve {{ selectedConflicts.length }} selected conflict(s) with a single strategy:
        </p>

        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-2">Resolution Strategy</label>
          <select v-model="bulkStrategy" class="input">
            <option value="server_wins">Server Wins (Keep server version)</option>
            <option value="client_wins">Client Wins (Keep client version)</option>
            <option value="last_write_wins">Last Write Wins (Most recent timestamp)</option>
          </select>
        </div>

        <div class="flex justify-end gap-3">
          <button @click="showBulkResolveModal = false" class="btn-secondary">Cancel</button>
          <button @click="submitBulkResolve" class="btn-primary">Resolve All</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { apiClient } from '@/lib/api-client'
import { toast } from '@/lib/toast'

const conflicts = ref([])
const statistics = ref(null)
const loading = ref(false)
const filters = ref({
  status: 'pending',
  aggregate_type: '',
  conflict_type: ''
})
const pagination = ref(null)
const currentPage = ref(1)

// Selection and modals
const selectedConflicts = ref([])
const showMergeModal = ref(false)
const showBulkResolveModal = ref(false)
const selectedConflict = ref(null)
const mergedDataJson = ref('')
const bulkStrategy = ref('server_wins')

const hasSelectedConflicts = computed(() => selectedConflicts.value.length > 0)
const autoResolvedCount = computed(() => {
  return statistics.value?.resolved - (statistics.value?.pending || 0) || 0
})

onMounted(async () => {
  await Promise.all([fetchConflicts(), fetchStatistics()])
})

watch(filters, () => {
  currentPage.value = 1
  fetchConflicts()
}, { deep: true })

async function fetchConflicts() {
  loading.value = true
  try {
    const params = new URLSearchParams()
    if (filters.value.status) params.append('status', filters.value.status)
    if (filters.value.aggregate_type) params.append('aggregate_type', filters.value.aggregate_type)
    params.append('page', currentPage.value.toString())

    const response = await apiClient.get(`/conflicts?${params.toString()}`)
    conflicts.value = response.data.data
    pagination.value = {
      current_page: response.data.current_page,
      last_page: response.data.last_page,
      total: response.data.total
    }
  } catch (error) {
    toast.error('Failed to load conflicts')
    console.error(error)
  } finally {
    loading.value = false
  }
}

async function fetchStatistics() {
  try {
    const response = await apiClient.get('/conflicts/statistics')
    statistics.value = response.data
  } catch (error) {
    console.error('Failed to load statistics:', error)
  }
}

async function resolveWithServer(conflictId: string) {
  try {
    await apiClient.post(`/conflicts/${conflictId}/resolve/server`)
    toast.success('Conflict resolved with server data')
    await refreshConflicts()
  } catch (error) {
    toast.error('Failed to resolve conflict')
    console.error(error)
  }
}

async function resolveWithClient(conflictId: string) {
  try {
    await apiClient.post(`/conflicts/${conflictId}/resolve/client`)
    toast.success('Conflict resolved with client data')
    await refreshConflicts()
  } catch (error) {
    toast.error('Failed to resolve conflict')
    console.error(error)
  }
}

function openMergeModal(conflict: any) {
  selectedConflict.value = conflict
  // Pre-populate with server data
  mergedDataJson.value = JSON.stringify(conflict.server_data, null, 2)
  showMergeModal.value = true
}

async function submitMerge() {
  try {
    const mergedData = JSON.parse(mergedDataJson.value)
    await apiClient.post(`/conflicts/${selectedConflict.value.id}/resolve/merge`, {
      merged_data: mergedData
    })
    toast.success('Conflict resolved with merged data')
    showMergeModal.value = false
    await refreshConflicts()
  } catch (error) {
    if (error instanceof SyntaxError) {
      toast.error('Invalid JSON format')
    } else {
      toast.error('Failed to resolve conflict')
    }
    console.error(error)
  }
}

async function ignoreConflict(conflictId: string) {
  try {
    await apiClient.post(`/conflicts/${conflictId}/ignore`)
    toast.success('Conflict ignored')
    await refreshConflicts()
  } catch (error) {
    toast.error('Failed to ignore conflict')
    console.error(error)
  }
}

async function submitBulkResolve() {
  try {
    await apiClient.post('/conflicts/bulk-resolve', {
      conflict_ids: selectedConflicts.value,
      strategy: bulkStrategy.value
    })
    toast.success(`Resolved ${selectedConflicts.value.length} conflicts`)
    selectedConflicts.value = []
    showBulkResolveModal.value = false
    await refreshConflicts()
  } catch (error) {
    toast.error('Failed to bulk resolve conflicts')
    console.error(error)
  }
}

async function refreshConflicts() {
  selectedConflicts.value = []
  await Promise.all([fetchConflicts(), fetchStatistics()])
}

function goToPage(page: number) {
  currentPage.value = page
  fetchConflicts()
}

function getStatusBadgeClass(status: string) {
  const classes = {
    pending: 'bg-orange-100 text-orange-800',
    resolved: 'bg-green-100 text-green-800',
    ignored: 'bg-gray-100 text-gray-800'
  }
  return classes[status] || 'bg-gray-100 text-gray-800'
}

function getTypeBadgeClass(type: string) {
  const classes = {
    concurrent_update: 'bg-blue-100 text-blue-800',
    delete_modified: 'bg-red-100 text-red-800'
  }
  return classes[type] || 'bg-purple-100 text-purple-800'
}

function formatConflictType(type: string) {
  return type.split('_').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ')
}

function formatAggregateType(type: string) {
  return type.charAt(0).toUpperCase() + type.slice(1)
}

function formatDate(date: string) {
  return new Date(date).toLocaleString()
}
</script>

<style scoped>
.modal-overlay {
  @apply fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50;
}

.modal-content {
  @apply bg-white rounded-lg p-6 max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto;
}

code {
  @apply font-mono;
}
</style>
