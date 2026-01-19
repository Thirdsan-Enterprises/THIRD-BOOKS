<template>
  <AppLayout>
    <div v-if="isLoading" class="text-center py-12">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
      <p class="mt-2 text-gray-500">Loading invoice...</p>
    </div>

    <div v-else-if="invoice" class="space-y-6">
      <!-- Header -->
      <div class="flex justify-between items-start">
        <div>
          <router-link to="/invoices" class="text-sm text-gray-600 hover:text-gray-900 mb-2 inline-block">
            ← Back to Invoices
          </router-link>
          <h1 class="text-2xl font-bold text-gray-900">{{ invoice.invoice_number }}</h1>
          <p class="text-sm text-gray-500 mt-1">
            Created {{ formatDate(invoice.created_at) }}
          </p>
        </div>
        <div class="flex items-center space-x-3">
          <span :class="getStatusClass(invoice.status)">
            {{ invoice.status }}
          </span>
          <button
            v-if="invoice.status === 'draft'"
            @click="sendInvoice"
            class="btn btn-primary"
          >
            Send Invoice
          </button>
          <button class="btn btn-secondary">
            Print / PDF
          </button>
        </div>
      </div>

      <!-- Invoice Details Card -->
      <div class="card">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
          <!-- From/To Section -->
          <div>
            <h3 class="text-sm font-medium text-gray-500 uppercase mb-2">From</h3>
            <div class="text-sm">
              <p class="font-medium text-gray-900">{{ invoice.company?.name || 'Your Company' }}</p>
              <p class="text-gray-600">{{ invoice.company?.email }}</p>
              <p class="text-gray-600">{{ invoice.company?.phone }}</p>
              <p class="text-gray-600">{{ invoice.company?.address }}</p>
            </div>

            <h3 class="text-sm font-medium text-gray-500 uppercase mt-6 mb-2">Bill To</h3>
            <div class="text-sm">
              <p class="font-medium text-gray-900">{{ invoice.customer?.name }}</p>
              <p class="text-gray-600">{{ invoice.customer?.email }}</p>
              <p class="text-gray-600">{{ invoice.customer?.phone }}</p>
              <p class="text-gray-600">{{ invoice.customer?.address }}</p>
            </div>
          </div>

          <!-- Invoice Info Section -->
          <div>
            <div class="space-y-3">
              <div class="flex justify-between">
                <span class="text-sm text-gray-600">Invoice Number:</span>
                <span class="text-sm font-medium">{{ invoice.invoice_number }}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-sm text-gray-600">Invoice Date:</span>
                <span class="text-sm font-medium">{{ formatDate(invoice.invoice_date) }}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-sm text-gray-600">Due Date:</span>
                <span class="text-sm font-medium">{{ formatDate(invoice.due_date) }}</span>
              </div>
              <div v-if="invoice.reference_number" class="flex justify-between">
                <span class="text-sm text-gray-600">Reference:</span>
                <span class="text-sm font-medium">{{ invoice.reference_number }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Line Items Card -->
      <div class="card">
        <h2 class="text-lg font-medium text-gray-900 mb-4">Line Items</h2>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Description</th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Qty</th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Unit Price</th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Tax</th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr v-for="item in invoice.items" :key="item.id">
                <td class="px-6 py-4 text-sm text-gray-900">{{ item.description }}</td>
                <td class="px-6 py-4 text-sm text-gray-900 text-right">{{ item.quantity }}</td>
                <td class="px-6 py-4 text-sm text-gray-900 text-right">{{ formatCurrency(item.unit_price) }}</td>
                <td class="px-6 py-4 text-sm text-gray-900 text-right">{{ item.tax_rate }}%</td>
                <td class="px-6 py-4 text-sm font-medium text-gray-900 text-right">{{ formatCurrency(item.amount) }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Totals -->
        <div class="border-t border-gray-200 mt-4 pt-4">
          <div class="max-w-md ml-auto space-y-2">
            <div class="flex justify-between text-sm">
              <span class="text-gray-600">Subtotal:</span>
              <span class="font-medium">{{ formatCurrency(invoice.subtotal) }}</span>
            </div>
            <div class="flex justify-between text-sm">
              <span class="text-gray-600">Tax:</span>
              <span class="font-medium">{{ formatCurrency(invoice.tax_amount) }}</span>
            </div>
            <div class="border-t border-gray-200 pt-2 flex justify-between">
              <span class="text-lg font-medium">Total:</span>
              <span class="text-lg font-bold text-primary-600">{{ formatCurrency(invoice.total) }}</span>
            </div>
            <div v-if="invoice.paid_amount > 0" class="flex justify-between text-sm">
              <span class="text-gray-600">Paid:</span>
              <span class="font-medium text-green-600">{{ formatCurrency(invoice.paid_amount) }}</span>
            </div>
            <div v-if="invoice.balance > 0" class="flex justify-between">
              <span class="text-base font-medium text-red-600">Balance Due:</span>
              <span class="text-base font-bold text-red-600">{{ formatCurrency(invoice.balance) }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Notes Card -->
      <div v-if="invoice.notes" class="card">
        <h3 class="text-sm font-medium text-gray-500 uppercase mb-2">Notes</h3>
        <p class="text-sm text-gray-700 whitespace-pre-line">{{ invoice.notes }}</p>
      </div>

      <!-- Payment Recording Card -->
      <div v-if="invoice.status !== 'paid' && invoice.status !== 'cancelled'" class="card">
        <h2 class="text-lg font-medium text-gray-900 mb-4">Record Payment</h2>
        <form @submit.prevent="recordPayment" class="space-y-4">
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label class="label">Payment Date *</label>
              <input
                v-model="paymentForm.payment_date"
                type="date"
                required
                class="input"
              />
            </div>
            <div>
              <label class="label">Amount *</label>
              <input
                v-model.number="paymentForm.amount"
                type="number"
                step="0.01"
                min="0"
                :max="invoice.balance"
                required
                class="input"
              />
            </div>
            <div>
              <label class="label">Payment Method *</label>
              <select v-model="paymentForm.payment_method" required class="input">
                <option value="">Select method</option>
                <option value="cash">Cash</option>
                <option value="bank_transfer">Bank Transfer</option>
                <option value="mobile_money">Mobile Money</option>
                <option value="cheque">Cheque</option>
                <option value="credit_card">Credit Card</option>
              </select>
            </div>
          </div>
          <div>
            <label class="label">Reference / Notes</label>
            <input
              v-model="paymentForm.reference"
              type="text"
              class="input"
              placeholder="Transaction ID, cheque number, etc."
            />
          </div>
          <div v-if="paymentError" class="rounded-md bg-red-50 p-4">
            <div class="text-sm text-red-700">{{ paymentError }}</div>
          </div>
          <div class="flex justify-end">
            <button type="submit" :disabled="isRecordingPayment" class="btn btn-primary">
              {{ isRecordingPayment ? 'Recording...' : 'Record Payment' }}
            </button>
          </div>
        </form>
      </div>

      <!-- Payment History -->
      <div v-if="invoice.payments && invoice.payments.length > 0" class="card">
        <h2 class="text-lg font-medium text-gray-900 mb-4">Payment History</h2>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Date</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Method</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Reference</th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Amount</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <tr v-for="payment in invoice.payments" :key="payment.id">
                <td class="px-6 py-4 text-sm text-gray-900">{{ formatDate(payment.payment_date) }}</td>
                <td class="px-6 py-4 text-sm text-gray-900">{{ payment.payment_method }}</td>
                <td class="px-6 py-4 text-sm text-gray-500">{{ payment.reference || '-' }}</td>
                <td class="px-6 py-4 text-sm font-medium text-gray-900 text-right">{{ formatCurrency(payment.amount) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <div v-else class="text-center py-12">
      <p class="text-gray-500">Invoice not found.</p>
      <router-link to="/invoices" class="text-primary-600 hover:text-primary-900 mt-4 inline-block">
        Back to Invoices
      </router-link>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppLayout from '@/components/AppLayout.vue'
import api from '@/utils/api'

interface Invoice {
  id: number
  invoice_number: string
  customer: any
  company: any
  invoice_date: string
  due_date: string
  reference_number: string | null
  subtotal: number
  tax_amount: number
  total: number
  paid_amount: number
  balance: number
  status: string
  notes: string | null
  items: any[]
  payments: any[]
  created_at: string
}

const route = useRoute()
const router = useRouter()
const isLoading = ref(true)
const isRecordingPayment = ref(false)
const paymentError = ref<string | null>(null)
const invoice = ref<Invoice | null>(null)

const paymentForm = ref({
  payment_date: new Date().toISOString().split('T')[0],
  amount: 0,
  payment_method: '',
  reference: '',
})

async function fetchInvoice() {
  try {
    isLoading.value = true
    const response = await api.getInvoice(Number(route.params.id))
    invoice.value = response.data.data

    // Set default payment amount to balance
    paymentForm.value.amount = invoice.value.balance
  } catch (error) {
    console.error('Failed to fetch invoice:', error)
  } finally {
    isLoading.value = false
  }
}

async function sendInvoice() {
  if (!confirm('Are you sure you want to send this invoice to the customer?')) return

  try {
    await api.sendInvoice(invoice.value!.id)
    alert('Invoice sent successfully!')
    await fetchInvoice() // Refresh to get updated status
  } catch (error) {
    console.error('Failed to send invoice:', error)
    alert('Failed to send invoice. Please try again.')
  }
}

async function recordPayment() {
  paymentError.value = null
  isRecordingPayment.value = true

  try {
    await api.recordInvoicePayment(invoice.value!.id, {
      payment_date: paymentForm.value.payment_date,
      amount: paymentForm.value.amount,
      payment_method: paymentForm.value.payment_method,
      reference: paymentForm.value.reference || null,
    })

    alert('Payment recorded successfully!')

    // Reset form
    paymentForm.value = {
      payment_date: new Date().toISOString().split('T')[0],
      amount: 0,
      payment_method: '',
      reference: '',
    }

    // Refresh invoice data
    await fetchInvoice()
  } catch (err: any) {
    paymentError.value = err.response?.data?.message || 'Failed to record payment. Please try again.'
    console.error('Payment recording error:', err)
  } finally {
    isRecordingPayment.value = false
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
    draft: 'px-3 py-1 text-sm rounded-full bg-gray-100 text-gray-800',
    sent: 'px-3 py-1 text-sm rounded-full bg-blue-100 text-blue-800',
    paid: 'px-3 py-1 text-sm rounded-full bg-green-100 text-green-800',
    partial: 'px-3 py-1 text-sm rounded-full bg-yellow-100 text-yellow-800',
    overdue: 'px-3 py-1 text-sm rounded-full bg-red-100 text-red-800',
    cancelled: 'px-3 py-1 text-sm rounded-full bg-gray-100 text-gray-600',
  }
  return classes[status] || classes.draft
}

onMounted(() => {
  fetchInvoice()
})
</script>
