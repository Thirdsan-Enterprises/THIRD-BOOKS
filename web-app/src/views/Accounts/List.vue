<template>
  <AppLayout>
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex justify-between items-center">
        <h1 class="text-2xl font-bold text-gray-900">Chart of Accounts</h1>
        <button @click="showCreateModal = true" class="btn btn-primary">
          Add Account
        </button>
      </div>

      <!-- Search & Filter -->
      <div class="card">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div class="md:col-span-2">
            <label class="label">Search</label>
            <input
              v-model="searchQuery"
              type="text"
              class="input"
              placeholder="Search by code, name, or description..."
              @input="debouncedFetch"
            />
          </div>
          <div>
            <label class="label">Account Type</label>
            <select v-model="filterType" class="input" @change="fetchAccounts">
              <option value="">All Types</option>
              <option value="asset">Assets</option>
              <option value="liability">Liabilities</option>
              <option value="equity">Equity</option>
              <option value="income">Income</option>
              <option value="expense">Expenses</option>
              <option value="cogs">Cost of Goods Sold</option>
            </select>
          </div>
        </div>
      </div>

      <!-- Loading State -->
      <div v-if="isLoading" class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
        <p class="mt-2 text-gray-500">Loading accounts...</p>
      </div>

      <!-- Accounts Table -->
      <div v-else class="card overflow-hidden">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Code
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Account Name
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Type
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Category
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Balance
                </th>
                <th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr v-if="accounts.length === 0">
                <td colspan="7" class="px-6 py-12 text-center text-gray-500">
                  No accounts found. Run seeders to populate the chart of accounts.
                </td>
              </tr>
              <tr v-for="account in accounts" :key="account.id" class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  <span class="text-sm font-mono font-medium text-gray-900">{{ account.code }}</span>
                </td>
                <td class="px-6 py-4">
                  <div class="text-sm font-medium text-gray-900">{{ account.name }}</div>
                  <div v-if="account.description" class="text-xs text-gray-500 mt-1">{{ account.description }}</div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span :class="getTypeClass(account.type)" class="px-2 py-1 text-xs rounded-full">
                    {{ formatType(account.type) }}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                  {{ account.category || '-' }}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900 text-right font-mono">
                  {{ formatCurrency(account.balance || 0) }}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-center">
                  <span :class="account.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'" class="px-2 py-1 text-xs rounded-full">
                    {{ account.is_active ? 'Active' : 'Inactive' }}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <button
                    @click="viewTransactions(account.id)"
                    class="text-primary-600 hover:text-primary-900 mr-4"
                  >
                    View
                  </button>
                  <button
                    @click="editAccount(account)"
                    class="text-blue-600 hover:text-blue-900"
                  >
                    Edit
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Pagination -->
        <div v-if="pagination.total > 0" class="bg-gray-50 px-6 py-3 flex items-center justify-between border-t border-gray-200">
          <div class="text-sm text-gray-700">
            Showing {{ pagination.from }} to {{ pagination.to }} of {{ pagination.total }} accounts
          </div>
          <div class="flex space-x-2">
            <button
              @click="goToPage(pagination.current_page - 1)"
              :disabled="pagination.current_page === 1"
              class="btn btn-secondary disabled:opacity-50"
            >
              Previous
            </button>
            <button
              @click="goToPage(pagination.current_page + 1)"
              :disabled="pagination.current_page === pagination.last_page"
              class="btn btn-secondary disabled:opacity-50"
            >
              Next
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Create/Edit Account Modal -->
    <div
      v-if="showCreateModal || editingAccount"
      class="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center z-50"
      @click.self="closeModal"
    >
      <div class="bg-white rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        <div class="p-6">
          <h2 class="text-xl font-bold text-gray-900 mb-4">
            {{ editingAccount ? 'Edit Account' : 'Add Account' }}
          </h2>

          <form @submit.prevent="saveAccount" class="space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="label">Account Code *</label>
                <input
                  v-model="accountForm.code"
                  type="text"
                  required
                  class="input font-mono"
                  placeholder="1000"
                />
              </div>

              <div>
                <label class="label">Account Type *</label>
                <select v-model="accountForm.type" required class="input">
                  <option value="">Select type</option>
                  <option value="asset">Asset</option>
                  <option value="liability">Liability</option>
                  <option value="equity">Equity</option>
                  <option value="income">Income</option>
                  <option value="expense">Expense</option>
                  <option value="cogs">Cost of Goods Sold</option>
                </select>
              </div>

              <div class="md:col-span-2">
                <label class="label">Account Name *</label>
                <input
                  v-model="accountForm.name"
                  type="text"
                  required
                  class="input"
                  placeholder="Cash on Hand"
                />
              </div>

              <div>
                <label class="label">Category</label>
                <input
                  v-model="accountForm.category"
                  type="text"
                  class="input"
                  placeholder="Current Assets, etc."
                />
              </div>

              <div>
                <label class="label">Currency</label>
                <select v-model="accountForm.currency_id" class="input">
                  <option :value="1">UGX - Ugandan Shilling</option>
                  <option :value="2">USD - US Dollar</option>
                  <option :value="3">EUR - Euro</option>
                  <option :value="4">GBP - British Pound</option>
                </select>
              </div>

              <div class="md:col-span-2">
                <label class="label">Description</label>
                <textarea
                  v-model="accountForm.description"
                  rows="2"
                  class="input"
                  placeholder="Optional description..."
                ></textarea>
              </div>
            </div>

            <div class="flex items-center space-x-6">
              <div class="flex items-center">
                <input
                  v-model="accountForm.is_active"
                  type="checkbox"
                  id="is_active"
                  class="h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded"
                />
                <label for="is_active" class="ml-2 text-sm text-gray-700">
                  Active account
                </label>
              </div>

              <div class="flex items-center">
                <input
                  v-model="accountForm.is_system"
                  type="checkbox"
                  id="is_system"
                  :disabled="editingAccount?.is_system"
                  class="h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded disabled:opacity-50"
                />
                <label for="is_system" class="ml-2 text-sm text-gray-700">
                  System account (cannot be deleted)
                </label>
              </div>
            </div>

            <div v-if="formError" class="rounded-md bg-red-50 p-4">
              <div class="text-sm text-red-700">{{ formError }}</div>
            </div>

            <div class="flex justify-end space-x-3 pt-4 border-t">
              <button type="button" @click="closeModal" class="btn btn-secondary">
                Cancel
              </button>
              <button type="submit" :disabled="isSaving" class="btn btn-primary">
                {{ isSaving ? 'Saving...' : 'Save Account' }}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AppLayout from '@/components/AppLayout.vue'
import api from '@/utils/api'

interface Account {
  id: number
  code: string
  name: string
  type: string
  category: string | null
  description: string | null
  balance: number
  currency_id: number
  is_active: boolean
  is_system: boolean
}

const isLoading = ref(false)
const isSaving = ref(false)
const showCreateModal = ref(false)
const editingAccount = ref<Account | null>(null)
const formError = ref<string | null>(null)
const searchQuery = ref('')
const filterType = ref('')
const accounts = ref<Account[]>([])

const pagination = ref({
  current_page: 1,
  last_page: 1,
  per_page: 20,
  total: 0,
  from: 0,
  to: 0,
})

const accountForm = ref({
  code: '',
  name: '',
  type: '',
  category: '',
  description: '',
  currency_id: 1,
  is_active: true,
  is_system: false,
})

let debounceTimer: number | null = null

function debouncedFetch() {
  if (debounceTimer) clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => {
    fetchAccounts()
  }, 500)
}

async function fetchAccounts() {
  try {
    isLoading.value = true
    const params: any = {
      page: pagination.value.current_page,
      per_page: pagination.value.per_page,
    }

    if (searchQuery.value) params.search = searchQuery.value
    if (filterType.value) params.type = filterType.value

    const response = await api.getAccounts(params)
    const data = response.data

    accounts.value = data.data
    pagination.value = {
      current_page: data.pagination.current_page,
      last_page: data.pagination.last_page,
      per_page: data.pagination.per_page,
      total: data.pagination.total,
      from: (data.pagination.current_page - 1) * data.pagination.per_page + 1,
      to: Math.min(data.pagination.current_page * data.pagination.per_page, data.pagination.total),
    }
  } catch (error) {
    console.error('Failed to fetch accounts:', error)
  } finally {
    isLoading.value = false
  }
}

function goToPage(page: number) {
  pagination.value.current_page = page
  fetchAccounts()
}

function viewTransactions(accountId: number) {
  console.log('View transactions for account:', accountId)
  alert('Account transaction view coming soon!')
}

function editAccount(account: Account) {
  editingAccount.value = account
  accountForm.value = {
    code: account.code,
    name: account.name,
    type: account.type,
    category: account.category || '',
    description: account.description || '',
    currency_id: account.currency_id,
    is_active: account.is_active,
    is_system: account.is_system,
  }
}

function closeModal() {
  showCreateModal.value = false
  editingAccount.value = null
  formError.value = null
  accountForm.value = {
    code: '',
    name: '',
    type: '',
    category: '',
    description: '',
    currency_id: 1,
    is_active: true,
    is_system: false,
  }
}

async function saveAccount() {
  formError.value = null
  isSaving.value = true

  try {
    if (editingAccount.value) {
      await api.updateAccount(editingAccount.value.id, accountForm.value)
      alert('Account updated successfully!')
    } else {
      await api.createAccount(accountForm.value)
      alert('Account created successfully!')
    }

    closeModal()
    fetchAccounts()
  } catch (err: any) {
    formError.value = err.response?.data?.message || 'Failed to save account. Please try again.'
    console.error('Account save error:', err)
  } finally {
    isSaving.value = false
  }
}

function formatType(type: string): string {
  return type.charAt(0).toUpperCase() + type.slice(1).replace('_', ' ')
}

function getTypeClass(type: string): string {
  const classes: Record<string, string> = {
    asset: 'bg-blue-100 text-blue-800',
    liability: 'bg-red-100 text-red-800',
    equity: 'bg-purple-100 text-purple-800',
    income: 'bg-green-100 text-green-800',
    expense: 'bg-orange-100 text-orange-800',
    cogs: 'bg-yellow-100 text-yellow-800',
  }
  return classes[type] || 'bg-gray-100 text-gray-800'
}

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('en-UG', {
    style: 'currency',
    currency: 'UGX',
    minimumFractionDigits: 0,
  }).format(amount)
}

onMounted(() => {
  fetchAccounts()
})
</script>
