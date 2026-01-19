<template>
  <AppLayout>
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex justify-between items-center">
        <h1 class="text-2xl font-bold text-gray-900">Customers</h1>
        <button @click="showCreateModal = true" class="btn btn-primary">
          Add Customer
        </button>
      </div>

      <!-- Search Bar -->
      <div class="card">
        <input
          v-model="searchQuery"
          type="text"
          class="input"
          placeholder="Search customers by name, email, or phone..."
          @input="debouncedFetch"
        />
      </div>

      <!-- Loading State -->
      <div v-if="isLoading" class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
        <p class="mt-2 text-gray-500">Loading customers...</p>
      </div>

      <!-- Customers Grid -->
      <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div v-if="customers.length === 0" class="col-span-full text-center py-12 card">
          <p class="text-gray-500">No customers found. Add your first customer to get started.</p>
        </div>

        <div
          v-for="customer in customers"
          :key="customer.id"
          class="card hover:shadow-lg transition-shadow cursor-pointer"
          @click="viewCustomer(customer)"
        >
          <div class="flex items-start justify-between">
            <div class="flex-1">
              <h3 class="text-lg font-medium text-gray-900">{{ customer.name }}</h3>
              <p class="text-sm text-gray-500 mt-1">{{ customer.email }}</p>
              <p v-if="customer.phone" class="text-sm text-gray-500">{{ customer.phone }}</p>
            </div>
            <span :class="customer.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'" class="px-2 py-1 text-xs rounded-full">
              {{ customer.is_active ? 'Active' : 'Inactive' }}
            </span>
          </div>

          <div class="mt-4 pt-4 border-t border-gray-200">
            <div class="grid grid-cols-2 gap-4 text-sm">
              <div>
                <p class="text-gray-500">Total Invoices</p>
                <p class="font-medium text-gray-900">{{ customer.invoices_count || 0 }}</p>
              </div>
              <div>
                <p class="text-gray-500">Balance Due</p>
                <p class="font-medium text-gray-900">{{ formatCurrency(customer.balance || 0) }}</p>
              </div>
            </div>
          </div>

          <div class="mt-4 flex space-x-2">
            <button
              @click.stop="editCustomer(customer)"
              class="flex-1 btn btn-secondary text-sm"
            >
              Edit
            </button>
            <button
              @click.stop="viewStatement(customer.id)"
              class="flex-1 btn btn-secondary text-sm"
            >
              Statement
            </button>
          </div>
        </div>
      </div>

      <!-- Pagination -->
      <div v-if="pagination.total > 0" class="card flex items-center justify-between">
        <div class="text-sm text-gray-700">
          Showing {{ pagination.from }} to {{ pagination.to }} of {{ pagination.total }} customers
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

    <!-- Create/Edit Customer Modal -->
    <div
      v-if="showCreateModal || editingCustomer"
      class="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center z-50"
      @click.self="closeModal"
    >
      <div class="bg-white rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        <div class="p-6">
          <h2 class="text-xl font-bold text-gray-900 mb-4">
            {{ editingCustomer ? 'Edit Customer' : 'Add Customer' }}
          </h2>

          <form @submit.prevent="saveCustomer" class="space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="label">Name *</label>
                <input
                  v-model="customerForm.name"
                  type="text"
                  required
                  class="input"
                  placeholder="Customer name"
                />
              </div>

              <div>
                <label class="label">Email *</label>
                <input
                  v-model="customerForm.email"
                  type="email"
                  required
                  class="input"
                  placeholder="customer@example.com"
                />
              </div>

              <div>
                <label class="label">Phone</label>
                <input
                  v-model="customerForm.phone"
                  type="tel"
                  class="input"
                  placeholder="+256700000000"
                />
              </div>

              <div>
                <label class="label">Tax ID / TIN</label>
                <input
                  v-model="customerForm.tax_id"
                  type="text"
                  class="input"
                  placeholder="Tax identification number"
                />
              </div>
            </div>

            <div>
              <label class="label">Address</label>
              <textarea
                v-model="customerForm.address"
                rows="3"
                class="input"
                placeholder="Street address, city, country"
              ></textarea>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="label">Payment Terms</label>
                <select v-model="customerForm.payment_terms" class="input">
                  <option value="">Default (Net 30)</option>
                  <option value="immediate">Due on Receipt</option>
                  <option value="15">Net 15</option>
                  <option value="30">Net 30</option>
                  <option value="60">Net 60</option>
                  <option value="90">Net 90</option>
                </select>
              </div>

              <div>
                <label class="label">Credit Limit</label>
                <input
                  v-model.number="customerForm.credit_limit"
                  type="number"
                  step="0.01"
                  min="0"
                  class="input"
                  placeholder="0.00"
                />
              </div>
            </div>

            <div class="flex items-center">
              <input
                v-model="customerForm.is_active"
                type="checkbox"
                id="is_active"
                class="h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded"
              />
              <label for="is_active" class="ml-2 text-sm text-gray-700">
                Active customer
              </label>
            </div>

            <div v-if="formError" class="rounded-md bg-red-50 p-4">
              <div class="text-sm text-red-700">{{ formError }}</div>
            </div>

            <div class="flex justify-end space-x-3 pt-4 border-t">
              <button type="button" @click="closeModal" class="btn btn-secondary">
                Cancel
              </button>
              <button type="submit" :disabled="isSaving" class="btn btn-primary">
                {{ isSaving ? 'Saving...' : 'Save Customer' }}
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
import { useRouter } from 'vue-router'
import AppLayout from '@/components/AppLayout.vue'
import api from '@/utils/api'

interface Customer {
  id: number
  name: string
  email: string
  phone: string | null
  address: string | null
  tax_id: string | null
  payment_terms: string | null
  credit_limit: number
  balance: number
  is_active: boolean
  invoices_count?: number
}

const router = useRouter()
const isLoading = ref(false)
const isSaving = ref(false)
const showCreateModal = ref(false)
const editingCustomer = ref<Customer | null>(null)
const formError = ref<string | null>(null)
const searchQuery = ref('')
const customers = ref<Customer[]>([])

const pagination = ref({
  current_page: 1,
  last_page: 1,
  per_page: 15,
  total: 0,
  from: 0,
  to: 0,
})

const customerForm = ref({
  name: '',
  email: '',
  phone: '',
  address: '',
  tax_id: '',
  payment_terms: '',
  credit_limit: 0,
  is_active: true,
})

let debounceTimer: number | null = null

function debouncedFetch() {
  if (debounceTimer) clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => {
    fetchCustomers()
  }, 500)
}

async function fetchCustomers() {
  try {
    isLoading.value = true
    const params: any = {
      page: pagination.value.current_page,
      per_page: pagination.value.per_page,
    }

    if (searchQuery.value) params.search = searchQuery.value

    const response = await api.getCustomers(params)
    const data = response.data

    customers.value = data.data
    pagination.value = {
      current_page: data.pagination.current_page,
      last_page: data.pagination.last_page,
      per_page: data.pagination.per_page,
      total: data.pagination.total,
      from: (data.pagination.current_page - 1) * data.pagination.per_page + 1,
      to: Math.min(data.pagination.current_page * data.pagination.per_page, data.pagination.total),
    }
  } catch (error) {
    console.error('Failed to fetch customers:', error)
  } finally {
    isLoading.value = false
  }
}

function goToPage(page: number) {
  pagination.value.current_page = page
  fetchCustomers()
}

function viewCustomer(customer: Customer) {
  // Navigate to customer detail view
  console.log('View customer:', customer)
}

function editCustomer(customer: Customer) {
  editingCustomer.value = customer
  customerForm.value = {
    name: customer.name,
    email: customer.email,
    phone: customer.phone || '',
    address: customer.address || '',
    tax_id: customer.tax_id || '',
    payment_terms: customer.payment_terms || '',
    credit_limit: customer.credit_limit,
    is_active: customer.is_active,
  }
}

function viewStatement(customerId: number) {
  console.log('View statement for customer:', customerId)
  alert('Customer statement feature coming soon!')
}

function closeModal() {
  showCreateModal.value = false
  editingCustomer.value = null
  formError.value = null
  customerForm.value = {
    name: '',
    email: '',
    phone: '',
    address: '',
    tax_id: '',
    payment_terms: '',
    credit_limit: 0,
    is_active: true,
  }
}

async function saveCustomer() {
  formError.value = null
  isSaving.value = true

  try {
    if (editingCustomer.value) {
      await api.updateCustomer(editingCustomer.value.id, customerForm.value)
      alert('Customer updated successfully!')
    } else {
      await api.createCustomer(customerForm.value)
      alert('Customer created successfully!')
    }

    closeModal()
    fetchCustomers()
  } catch (err: any) {
    formError.value = err.response?.data?.message || 'Failed to save customer. Please try again.'
    console.error('Customer save error:', err)
  } finally {
    isSaving.value = false
  }
}

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('en-UG', {
    style: 'currency',
    currency: 'UGX',
    minimumFractionDigits: 0,
  }).format(amount)
}

onMounted(() => {
  fetchCustomers()
})
</script>
