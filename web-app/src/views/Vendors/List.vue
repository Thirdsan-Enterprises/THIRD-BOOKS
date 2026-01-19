<template>
  <AppLayout>
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex justify-between items-center">
        <h1 class="text-2xl font-bold text-gray-900">Vendors</h1>
        <button @click="showCreateModal = true" class="btn btn-primary">
          Add Vendor
        </button>
      </div>

      <!-- Search Bar -->
      <div class="card">
        <input
          v-model="searchQuery"
          type="text"
          class="input"
          placeholder="Search vendors by name, email, or phone..."
          @input="debouncedFetch"
        />
      </div>

      <!-- Loading State -->
      <div v-if="isLoading" class="text-center py-12">
        <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
        <p class="mt-2 text-gray-500">Loading vendors...</p>
      </div>

      <!-- Vendors Grid -->
      <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div v-if="vendors.length === 0" class="col-span-full text-center py-12 card">
          <p class="text-gray-500">No vendors found. Add your first vendor to get started.</p>
        </div>

        <div
          v-for="vendor in vendors"
          :key="vendor.id"
          class="card hover:shadow-lg transition-shadow cursor-pointer"
          @click="viewVendor(vendor)"
        >
          <div class="flex items-start justify-between">
            <div class="flex-1">
              <h3 class="text-lg font-medium text-gray-900">{{ vendor.name }}</h3>
              <p class="text-sm text-gray-500 mt-1">{{ vendor.email }}</p>
              <p v-if="vendor.phone" class="text-sm text-gray-500">{{ vendor.phone }}</p>
            </div>
            <span :class="vendor.is_active ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'" class="px-2 py-1 text-xs rounded-full">
              {{ vendor.is_active ? 'Active' : 'Inactive' }}
            </span>
          </div>

          <div class="mt-4 pt-4 border-t border-gray-200">
            <div class="grid grid-cols-2 gap-4 text-sm">
              <div>
                <p class="text-gray-500">Total Bills</p>
                <p class="font-medium text-gray-900">{{ vendor.bills_count || 0 }}</p>
              </div>
              <div>
                <p class="text-gray-500">Balance Due</p>
                <p class="font-medium text-gray-900">{{ formatCurrency(vendor.balance || 0) }}</p>
              </div>
            </div>
          </div>

          <div class="mt-4 flex space-x-2">
            <button
              @click.stop="editVendor(vendor)"
              class="flex-1 btn btn-secondary text-sm"
            >
              Edit
            </button>
            <button
              @click.stop="viewStatement(vendor.id)"
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
          Showing {{ pagination.from }} to {{ pagination.to }} of {{ pagination.total }} vendors
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

    <!-- Create/Edit Vendor Modal -->
    <div
      v-if="showCreateModal || editingVendor"
      class="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center z-50"
      @click.self="closeModal"
    >
      <div class="bg-white rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        <div class="p-6">
          <h2 class="text-xl font-bold text-gray-900 mb-4">
            {{ editingVendor ? 'Edit Vendor' : 'Add Vendor' }}
          </h2>

          <form @submit.prevent="saveVendor" class="space-y-4">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="label">Name *</label>
                <input
                  v-model="vendorForm.name"
                  type="text"
                  required
                  class="input"
                  placeholder="Vendor name"
                />
              </div>

              <div>
                <label class="label">Email *</label>
                <input
                  v-model="vendorForm.email"
                  type="email"
                  required
                  class="input"
                  placeholder="vendor@example.com"
                />
              </div>

              <div>
                <label class="label">Phone</label>
                <input
                  v-model="vendorForm.phone"
                  type="tel"
                  class="input"
                  placeholder="+256700000000"
                />
              </div>

              <div>
                <label class="label">Tax ID / TIN</label>
                <input
                  v-model="vendorForm.tax_id"
                  type="text"
                  class="input"
                  placeholder="Tax identification number"
                />
              </div>
            </div>

            <div>
              <label class="label">Address</label>
              <textarea
                v-model="vendorForm.address"
                rows="3"
                class="input"
                placeholder="Street address, city, country"
              ></textarea>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="label">Payment Terms</label>
                <select v-model="vendorForm.payment_terms" class="input">
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
                  v-model.number="vendorForm.credit_limit"
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
                v-model="vendorForm.is_active"
                type="checkbox"
                id="is_active"
                class="h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded"
              />
              <label for="is_active" class="ml-2 text-sm text-gray-700">
                Active vendor
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
                {{ isSaving ? 'Saving...' : 'Save Vendor' }}
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

interface Vendor {
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
  bills_count?: number
}

const router = useRouter()
const isLoading = ref(false)
const isSaving = ref(false)
const showCreateModal = ref(false)
const editingVendor = ref<Vendor | null>(null)
const formError = ref<string | null>(null)
const searchQuery = ref('')
const vendors = ref<Vendor[]>([])

const pagination = ref({
  current_page: 1,
  last_page: 1,
  per_page: 15,
  total: 0,
  from: 0,
  to: 0,
})

const vendorForm = ref({
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
    fetchVendors()
  }, 500)
}

async function fetchVendors() {
  try {
    isLoading.value = true
    const params: any = {
      page: pagination.value.current_page,
      per_page: pagination.value.per_page,
    }

    if (searchQuery.value) params.search = searchQuery.value

    const response = await api.getVendors(params)
    const data = response.data

    vendors.value = data.data
    pagination.value = {
      current_page: data.pagination.current_page,
      last_page: data.pagination.last_page,
      per_page: data.pagination.per_page,
      total: data.pagination.total,
      from: (data.pagination.current_page - 1) * data.pagination.per_page + 1,
      to: Math.min(data.pagination.current_page * data.pagination.per_page, data.pagination.total),
    }
  } catch (error) {
    console.error('Failed to fetch vendors:', error)
  } finally {
    isLoading.value = false
  }
}

function goToPage(page: number) {
  pagination.value.current_page = page
  fetchVendors()
}

function viewVendor(vendor: Vendor) {
  console.log('View vendor:', vendor)
}

function editVendor(vendor: Vendor) {
  editingVendor.value = vendor
  vendorForm.value = {
    name: vendor.name,
    email: vendor.email,
    phone: vendor.phone || '',
    address: vendor.address || '',
    tax_id: vendor.tax_id || '',
    payment_terms: vendor.payment_terms || '',
    credit_limit: vendor.credit_limit,
    is_active: vendor.is_active,
  }
}

function viewStatement(vendorId: number) {
  console.log('View statement for vendor:', vendorId)
  alert('Vendor statement feature coming soon!')
}

function closeModal() {
  showCreateModal.value = false
  editingVendor.value = null
  formError.value = null
  vendorForm.value = {
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

async function saveVendor() {
  formError.value = null
  isSaving.value = true

  try {
    if (editingVendor.value) {
      await api.updateVendor(editingVendor.value.id, vendorForm.value)
      alert('Vendor updated successfully!')
    } else {
      await api.createVendor(vendorForm.value)
      alert('Vendor created successfully!')
    }

    closeModal()
    fetchVendors()
  } catch (err: any) {
    formError.value = err.response?.data?.message || 'Failed to save vendor. Please try again.'
    console.error('Vendor save error:', err)
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
  fetchVendors()
})
</script>
