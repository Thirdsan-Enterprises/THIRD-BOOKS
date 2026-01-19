<template>
  <AppLayout>
    <div class="space-y-6">
      <!-- Header -->
      <div class="flex justify-between items-center">
        <h1 class="text-2xl font-bold text-gray-900">Create Invoice</h1>
        <router-link to="/invoices" class="text-gray-600 hover:text-gray-900">
          Cancel
        </router-link>
      </div>

      <form @submit.prevent="handleSubmit" class="space-y-6">
        <!-- Customer & Details Card -->
        <div class="card">
          <h2 class="text-lg font-medium text-gray-900 mb-4">Invoice Details</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label class="label">Customer *</label>
              <select v-model="form.customer_id" required class="input">
                <option value="">Select a customer</option>
                <option v-for="customer in customers" :key="customer.id" :value="customer.id">
                  {{ customer.name }}
                </option>
              </select>
              <router-link to="/customers/create" class="text-xs text-primary-600 hover:text-primary-900 mt-1 inline-block">
                + Add new customer
              </router-link>
            </div>

            <div>
              <label class="label">Invoice Date *</label>
              <input
                v-model="form.invoice_date"
                type="date"
                required
                class="input"
              />
            </div>

            <div>
              <label class="label">Due Date *</label>
              <input
                v-model="form.due_date"
                type="date"
                required
                class="input"
              />
            </div>

            <div>
              <label class="label">Payment Terms</label>
              <select v-model="form.payment_terms" class="input" @change="updateDueDate">
                <option value="">Custom</option>
                <option value="immediate">Due on Receipt</option>
                <option value="15">Net 15</option>
                <option value="30">Net 30</option>
                <option value="60">Net 60</option>
                <option value="90">Net 90</option>
              </select>
            </div>

            <div class="md:col-span-2">
              <label class="label">Reference Number</label>
              <input
                v-model="form.reference_number"
                type="text"
                class="input"
                placeholder="PO Number, Project Code, etc."
              />
            </div>

            <div class="md:col-span-2">
              <label class="label">Notes</label>
              <textarea
                v-model="form.notes"
                rows="3"
                class="input"
                placeholder="Additional information for customer..."
              ></textarea>
            </div>
          </div>
        </div>

        <!-- Line Items Card -->
        <div class="card">
          <h2 class="text-lg font-medium text-gray-900 mb-4">Line Items</h2>
          <div class="overflow-x-auto">
            <table class="min-w-full">
              <thead class="border-b border-gray-200">
                <tr>
                  <th class="text-left text-sm font-medium text-gray-700 pb-2">Description</th>
                  <th class="text-left text-sm font-medium text-gray-700 pb-2 w-24">Quantity</th>
                  <th class="text-left text-sm font-medium text-gray-700 pb-2 w-32">Unit Price</th>
                  <th class="text-left text-sm font-medium text-gray-700 pb-2 w-24">Tax %</th>
                  <th class="text-right text-sm font-medium text-gray-700 pb-2 w-32">Amount</th>
                  <th class="w-10"></th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(item, index) in form.items" :key="index" class="border-b border-gray-100">
                  <td class="py-2 pr-2">
                    <input
                      v-model="item.description"
                      type="text"
                      required
                      class="input"
                      placeholder="Item description..."
                    />
                  </td>
                  <td class="py-2 pr-2">
                    <input
                      v-model.number="item.quantity"
                      type="number"
                      step="0.01"
                      min="0"
                      required
                      class="input"
                      @input="calculateTotals"
                    />
                  </td>
                  <td class="py-2 pr-2">
                    <input
                      v-model.number="item.unit_price"
                      type="number"
                      step="0.01"
                      min="0"
                      required
                      class="input"
                      @input="calculateTotals"
                    />
                  </td>
                  <td class="py-2 pr-2">
                    <input
                      v-model.number="item.tax_rate"
                      type="number"
                      step="0.01"
                      min="0"
                      max="100"
                      class="input"
                      @input="calculateTotals"
                    />
                  </td>
                  <td class="py-2 pr-2 text-right text-sm font-medium">
                    {{ formatCurrency(item.quantity * item.unit_price) }}
                  </td>
                  <td class="py-2">
                    <button
                      v-if="form.items.length > 1"
                      type="button"
                      @click="removeItem(index)"
                      class="text-red-600 hover:text-red-900"
                    >
                      <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <button
            type="button"
            @click="addItem"
            class="mt-4 text-primary-600 hover:text-primary-900 text-sm font-medium"
          >
            + Add Line Item
          </button>
        </div>

        <!-- Totals Card -->
        <div class="card">
          <div class="max-w-md ml-auto space-y-2">
            <div class="flex justify-between text-sm">
              <span class="text-gray-600">Subtotal:</span>
              <span class="font-medium">{{ formatCurrency(totals.subtotal) }}</span>
            </div>
            <div class="flex justify-between text-sm">
              <span class="text-gray-600">Tax (VAT 18%):</span>
              <span class="font-medium">{{ formatCurrency(totals.tax) }}</span>
            </div>
            <div class="border-t border-gray-200 pt-2 flex justify-between">
              <span class="text-lg font-medium">Total:</span>
              <span class="text-lg font-bold text-primary-600">{{ formatCurrency(totals.total) }}</span>
            </div>
          </div>
        </div>

        <!-- Error Message -->
        <div v-if="error" class="rounded-md bg-red-50 p-4">
          <div class="text-sm text-red-700">{{ error }}</div>
        </div>

        <!-- Action Buttons -->
        <div class="flex justify-end space-x-3">
          <router-link to="/invoices" class="btn btn-secondary">
            Cancel
          </router-link>
          <button
            type="submit"
            name="action"
            value="draft"
            :disabled="isSubmitting"
            class="btn btn-secondary"
            @click="submitAction = 'draft'"
          >
            Save as Draft
          </button>
          <button
            type="submit"
            name="action"
            value="send"
            :disabled="isSubmitting"
            class="btn btn-primary"
            @click="submitAction = 'send'"
          >
            {{ isSubmitting ? 'Creating...' : 'Create & Send' }}
          </button>
        </div>
      </form>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import AppLayout from '@/components/AppLayout.vue'
import api from '@/utils/api'

interface LineItem {
  description: string
  quantity: number
  unit_price: number
  tax_rate: number
}

interface Customer {
  id: number
  name: string
  email: string
}

const router = useRouter()
const isSubmitting = ref(false)
const error = ref<string | null>(null)
const submitAction = ref('draft')
const customers = ref<Customer[]>([])

const form = ref({
  customer_id: '',
  invoice_date: new Date().toISOString().split('T')[0],
  due_date: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
  payment_terms: '30',
  reference_number: '',
  notes: '',
  items: [
    {
      description: '',
      quantity: 1,
      unit_price: 0,
      tax_rate: 18, // Default VAT rate for Uganda
    },
  ] as LineItem[],
})

const totals = computed(() => {
  const subtotal = form.value.items.reduce((sum, item) => {
    return sum + (item.quantity * item.unit_price)
  }, 0)

  const tax = form.value.items.reduce((sum, item) => {
    const itemAmount = item.quantity * item.unit_price
    return sum + (itemAmount * (item.tax_rate / 100))
  }, 0)

  return {
    subtotal,
    tax,
    total: subtotal + tax,
  }
})

function addItem() {
  form.value.items.push({
    description: '',
    quantity: 1,
    unit_price: 0,
    tax_rate: 18,
  })
}

function removeItem(index: number) {
  form.value.items.splice(index, 1)
}

function calculateTotals() {
  // Trigger reactivity - the computed property will handle calculations
}

function updateDueDate() {
  if (!form.value.payment_terms) return

  const terms = form.value.payment_terms
  if (terms === 'immediate') {
    form.value.due_date = form.value.invoice_date
  } else {
    const days = parseInt(terms)
    const invoiceDate = new Date(form.value.invoice_date)
    const dueDate = new Date(invoiceDate.getTime() + days * 24 * 60 * 60 * 1000)
    form.value.due_date = dueDate.toISOString().split('T')[0]
  }
}

async function fetchCustomers() {
  try {
    const response = await api.getCustomers()
    customers.value = response.data.data
  } catch (err) {
    console.error('Failed to fetch customers:', err)
  }
}

async function handleSubmit() {
  error.value = null
  isSubmitting.value = true

  try {
    // Prepare invoice data
    const invoiceData = {
      customer_id: parseInt(form.value.customer_id),
      invoice_date: form.value.invoice_date,
      due_date: form.value.due_date,
      reference_number: form.value.reference_number || null,
      notes: form.value.notes || null,
      subtotal: totals.value.subtotal,
      tax_amount: totals.value.tax,
      total: totals.value.total,
      items: form.value.items.map(item => ({
        description: item.description,
        quantity: item.quantity,
        unit_price: item.unit_price,
        tax_rate: item.tax_rate,
        amount: item.quantity * item.unit_price,
      })),
    }

    // Create invoice
    const response = await api.createInvoice(invoiceData)
    const invoiceId = response.data.data.id

    // Send invoice if requested
    if (submitAction.value === 'send') {
      await api.sendInvoice(invoiceId)
    }

    // Redirect to invoice view
    router.push(`/invoices/${invoiceId}`)
  } catch (err: any) {
    error.value = err.response?.data?.message || 'Failed to create invoice. Please try again.'
    console.error('Invoice creation error:', err)
  } finally {
    isSubmitting.value = false
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
