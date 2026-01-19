<template>
  <AppLayout>
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex justify-between items-center">
        <h1 class="text-2xl font-bold text-gray-900">Bills</h1>
        <router-link to="/bills/create" class="btn btn-primary">
          Create Bill
        </router-link>
      </div>

      <!-- Filters -->
      <div class="card">
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div>
            <label class="label">Search</label>
            <input
              v-model="filters.search"
              type="text"
              class="input"
              placeholder="Bill number, vendor..."
              @input="debouncedFetch"
            />
          </div>
          <div>
            <label class="label">Status</label>
            <select v-model="filters.status" class="input" @change="fetchBills">
              <option value="">All Statuses</option>
              <option value="draft">Draft</option>
              <option value="submitted">Submitted</option>
              <option value="approved">Approved</option>
              <option value="paid">Paid</option>
              <option value="partial">Partially Paid</option>
              <option value="overdue">Overdue</option>
              <option value="rejected">Rejected</option>
            </select>
          </div>
          <div>
            <label class="label">From Date</label>
            <input
              v-model="filters.from_date"
              type="date"
              class="input"
              @change="fetchBills"
            />
          </div>
          <div>
            <label class="label">To Date</label>
            <input
              v-model="filters.to_date"
              type="date"
              class="input"
              @change="fetchBills"
            />
          </div>
        </div>
      </div>

      <!-- Loading State -->
      <div v-if="isLoading" class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
        <p class="mt-2 text-gray-500">Loading bills...</p>
      </div>

      <!-- Bills Table -->
      <div v-else class="card overflow-hidden">
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Bill #
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Vendor
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Date
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Due Date
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Amount
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr v-if="bills.length === 0">
                <td colspan="7" class="px-6 py-12 text-center text-gray-500">
                  No bills found. Create your first bill to get started.
                </td>
              </tr>
              <tr v-for="bill in bills" :key="bill.id" class="hover:bg-gray-50">
                <td class="px-6 py-4 whitespace-nowrap">
                  <router-link
                    :to="`/bills/${bill.id}`"
                    class="text-primary-600 hover:text-primary-900 font-medium"
                  >
                    {{ bill.bill_number }}
                  </router-link>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <div class="text-sm text-gray-900">{{ bill.vendor?.name || 'N/A' }}</div>
                  <div class="text-sm text-gray-500">{{ bill.vendor?.email }}</div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {{ formatDate(bill.bill_date) }}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {{ formatDate(bill.due_date) }}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                  {{ formatCurrency(bill.total) }}
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                  <span :class="getStatusClass(bill.status)">
                    {{ bill.status }}
                  </span>
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <router-link
                    :to="`/bills/${bill.id}`"
                    class="text-primary-600 hover:text-primary-900 mr-4"
                  >
                    View
                  </router-link>
                  <button
                    v-if="bill.status === 'draft'"
                    @click="submitBill(bill.id)"
                    class="text-blue-600 hover:text-blue-900 mr-4"
                  >
                    Submit
                  </button>
                  <button
                    v-if="bill.status === 'submitted'"
                    @click="approveBill(bill.id)"
                    class="text-green-600 hover:text-green-900 mr-4"
                  >
                    Approve
                  </button>
                  <button
                    v-if="bill.status !== 'paid' && bill.status !== 'rejected'"
                    @click="deleteBill(bill.id)"
                    class="text-red-600 hover:text-red-900"
                  >
                    Delete
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Pagination -->
        <div v-if="pagination.total > 0" class="bg-gray-50 px-6 py-3 flex items-center justify-between border-t border-gray-200">
          <div class="text-sm text-gray-700">
            Showing {{ pagination.from }} to {{ pagination.to }} of {{ pagination.total }} results
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
  </AppLayout>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import AppLayout from '@/components/AppLayout.vue'
import api from '@/utils/api'

interface Bill {
  id: number
  bill_number: string
  vendor: {
    name: string
    email: string
  } | null
  bill_date: string
  due_date: string
  total: number
  status: string
}

const router = useRouter()
const isLoading = ref(false)
const bills = ref<Bill[]>([])
const filters = ref({
  search: '',
  status: '',
  from_date: '',
  to_date: '',
})

const pagination = ref({
  current_page: 1,
  last_page: 1,
  per_page: 15,
  total: 0,
  from: 0,
  to: 0,
})

let debounceTimer: number | null = null

function debouncedFetch() {
  if (debounceTimer) clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => {
    fetchBills()
  }, 500)
}

async function fetchBills() {
  try {
    isLoading.value = true
    const params: any = {
      page: pagination.value.current_page,
      per_page: pagination.value.per_page,
    }

    if (filters.value.search) params.search = filters.value.search
    if (filters.value.status) params.status = filters.value.status
    if (filters.value.from_date) params.from_date = filters.value.from_date
    if (filters.value.to_date) params.to_date = filters.value.to_date

    const response = await api.getBills(params)
    const data = response.data

    bills.value = data.data
    pagination.value = {
      current_page: data.pagination.current_page,
      last_page: data.pagination.last_page,
      per_page: data.pagination.per_page,
      total: data.pagination.total,
      from: (data.pagination.current_page - 1) * data.pagination.per_page + 1,
      to: Math.min(data.pagination.current_page * data.pagination.per_page, data.pagination.total),
    }
  } catch (error) {
    console.error('Failed to fetch bills:', error)
  } finally {
    isLoading.value = false
  }
}

function goToPage(page: number) {
  pagination.value.current_page = page
  fetchBills()
}

async function submitBill(id: number) {
  if (!confirm('Are you sure you want to submit this bill for approval?')) return

  try {
    await api.submitBill(id)
    alert('Bill submitted successfully!')
    fetchBills()
  } catch (error) {
    console.error('Failed to submit bill:', error)
    alert('Failed to submit bill. Please try again.')
  }
}

async function approveBill(id: number) {
  if (!confirm('Are you sure you want to approve this bill?')) return

  try {
    await api.approveBill(id)
    alert('Bill approved successfully!')
    fetchBills()
  } catch (error) {
    console.error('Failed to approve bill:', error)
    alert('Failed to approve bill. Please try again.')
  }
}

async function deleteBill(id: number) {
  if (!confirm('Are you sure you want to delete this bill? This action cannot be undone.')) return

  try {
    await api.deleteBill(id)
    alert('Bill deleted successfully!')
    fetchBills()
  } catch (error) {
    console.error('Failed to delete bill:', error)
    alert('Failed to delete bill. Please try again.')
  }
}

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('en-UG', {
    style: 'currency',
    currency: 'UGX',
    minimumFractionDigits: 0,
  }).format(amount)
}

function formatDate(date: string): string {
  return new Date(date).toLocaleDateString('en-UG')
}

function getStatusClass(status: string): string {
  const classes: Record<string, string> = {
    draft: 'px-2 py-1 text-xs rounded-full bg-gray-100 text-gray-800',
    submitted: 'px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800',
    approved: 'px-2 py-1 text-xs rounded-full bg-green-100 text-green-800',
    paid: 'px-2 py-1 text-xs rounded-full bg-secondary-100 text-secondary-800',
    partial: 'px-2 py-1 text-xs rounded-full bg-accent-100 text-accent-800',
    overdue: 'px-2 py-1 text-xs rounded-full bg-red-100 text-red-800',
    rejected: 'px-2 py-1 text-xs rounded-full bg-red-100 text-red-800',
  }
  return classes[status] || classes.draft
}

onMounted(() => {
  fetchBills()
})
</script>
