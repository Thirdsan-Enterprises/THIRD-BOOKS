<template>
  <AppLayout>
    <div v-if="isLoading" class="text-center py-12">
      <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
      <p class="mt-2 text-gray-500">Loading bill...</p>
    </div>

    <div v-else-if="bill" class="space-y-6">
      <!-- Header -->
      <div class="flex justify-between items-start">
        <div>
          <router-link to="/bills" class="text-sm text-gray-600 hover:text-gray-900 mb-2 inline-block">
            ← Back to Bills
          </router-link>
          <h1 class="text-2xl font-bold text-gray-900">{{ bill.bill_number }}</h1>
          <p class="text-sm text-gray-500 mt-1">
            Created {{ formatDate(bill.created_at) }}
          </p>
        </div>
        <div class="flex items-center space-x-3">
          <span :class="getStatusClass(bill.status)">
            {{ bill.status }}
          </span>
          <button
            v-if="bill.status === 'draft'"
            @click="submitBill"
            class="btn btn-primary"
          >
            Submit for Approval
          </button>
          <button
            v-if="bill.status === 'submitted'"
            @click="approveBill"
            class="btn btn-success"
          >
            Approve Bill
          </button>
          <button class="btn btn-secondary">
            Print / PDF
          </button>
        </div>
      </div>

      <!-- Bill Details Card -->
      <div class="card">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
          <!-- From/To Section -->
          <div>
            <h3 class="text-sm font-medium text-gray-500 uppercase mb-2">Bill To</h3>
            <div class="text-sm">
              <p class="font-medium text-gray-900">{{ bill.company?.name || 'Your Company' }}</p>
              <p class="text-gray-600">{{ bill.company?.email }}</p>
              <p class="text-gray-600">{{ bill.company?.phone }}</p>
              <p class="text-gray-600">{{ bill.company?.address }}</p>
            </div>

            <h3 class="text-sm font-medium text-gray-500 uppercase mt-6 mb-2">Bill From</h3>
            <div class="text-sm">
              <p class="font-medium text-gray-900">{{ bill.vendor?.name }}</p>
              <p class="text-gray-600">{{ bill.vendor?.email }}</p>
              <p class="text-gray-600">{{ bill.vendor?.phone }}</p>
              <p class="text-gray-600">{{ bill.vendor?.address }}</p>
            </div>
          </div>

          <!-- Bill Info Section -->
          <div>
            <div class="space-y-3">
              <div class="flex justify-between">
                <span class="text-sm text-gray-600">Bill Number:</span>
                <span class="text-sm font-medium">{{ bill.bill_number }}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-sm text-gray-600">Bill Date:</span>
                <span class="text-sm font-medium">{{ formatDate(bill.bill_date) }}</span>
              </div>
              <div class="flex justify-between">
                <span class="text-sm text-gray-600">Due Date:</span>
                <span class="text-sm font-medium">{{ formatDate(bill.due_date) }}</span>
              </div>
              <div v-if="bill.vendor_invoice_number" class="flex justify-between">
                <span class="text-sm text-gray-600">Vendor Invoice #:</span>
                <span class="text-sm font-medium">{{ bill.vendor_invoice_number }}</span>
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
              <tr v-for="item in bill.items" :key="item.id">
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
              <span class="font-medium">{{ formatCurrency(bill.subtotal) }}</span>
            </div>
            <div class="flex justify-between text-sm">
              <span class="text-gray-600">Tax:</span>
              <span class="font-medium">{{ formatCurrency(bill.tax_amount) }}</span>
            </div>
            <div class="border-t border-gray-200 pt-2 flex justify-between">
              <span class="text-lg font-medium">Total:</span>
              <span class="text-lg font-bold text-primary-600">{{ formatCurrency(bill.total) }}</span>
            </div>
            <div v-if="bill.paid_amount > 0" class="flex justify-between text-sm">
              <span class="text-gray-600">Paid:</span>
              <span class="font-medium text-green-600">{{ formatCurrency(bill.paid_amount) }}</span>
            </div>
            <div v-if="bill.balance > 0" class="flex justify-between">
              <span class="text-base font-medium text-red-600">Balance Due:</span>
              <span class="text-base font-bold text-red-600">{{ formatCurrency(bill.balance) }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Notes Card -->
      <div v-if="bill.notes" class="card">
        <h3 class="text-sm font-medium text-gray-500 uppercase mb-2">Notes</h3>
        <p class="text-sm text-gray-700 whitespace-pre-line">{{ bill.notes }}</p>
      </div>

      <!-- Payment Recording Card -->
      <div v-if="bill.status === 'approved' || bill.status === 'partial'" class="card">
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
                :max="bill.balance"
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
      <div v-if="bill.payments && bill.payments.length > 0" class="card">
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
              <tr v-for="payment in bill.payments" :key="payment.id">
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
      <p class="text-gray-500">Bill not found.</p>
      <router-link to="/bills" class="text-primary-600 hover:text-primary-900 mt-4 inline-block">
        Back to Bills
      </router-link>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import AppLayout from '@/components/AppLayout.vue'
import api from '@/utils/api'

interface Bill {
  id: number
  bill_number: string
  vendor: any
  company: any
  bill_date: string
  due_date: string
  vendor_invoice_number: string | null
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
const bill = ref<Bill | null>(null)

const paymentForm = ref({
  payment_date: new Date().toISOString().split('T')[0],
  amount: 0,
  payment_method: '',
  reference: '',
})

async function fetchBill() {
  try {
    isLoading.value = true
    const response = await api.getBill(Number(route.params.id))
    bill.value = response.data.data
    paymentForm.value.amount = bill.value.balance
  } catch (error) {
    console.error('Failed to fetch bill:', error)
  } finally {
    isLoading.value = false
  }
}

async function submitBill() {
  if (!confirm('Are you sure you want to submit this bill for approval?')) return

  try {
    await api.submitBill(bill.value!.id)
    alert('Bill submitted successfully!')
    await fetchBill()
  } catch (error) {
    console.error('Failed to submit bill:', error)
    alert('Failed to submit bill. Please try again.')
  }
}

async function approveBill() {
  if (!confirm('Are you sure you want to approve this bill?')) return

  try {
    await api.approveBill(bill.value!.id)
    alert('Bill approved successfully!')
    await fetchBill()
  } catch (error) {
    console.error('Failed to approve bill:', error)
    alert('Failed to approve bill. Please try again.')
  }
}

async function recordPayment() {
  paymentError.value = null
  isRecordingPayment.value = true

  try {
    await api.recordBillPayment(bill.value!.id, {
      payment_date: paymentForm.value.payment_date,
      amount: paymentForm.value.amount,
      payment_method: paymentForm.value.payment_method,
      reference: paymentForm.value.reference || null,
    })

    alert('Payment recorded successfully!')

    paymentForm.value = {
      payment_date: new Date().toISOString().split('T')[0],
      amount: 0,
      payment_method: '',
      reference: '',
    }

    await fetchBill()
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
    submitted: 'px-3 py-1 text-sm rounded-full bg-blue-100 text-blue-800',
    approved: 'px-3 py-1 text-sm rounded-full bg-green-100 text-green-800',
    paid: 'px-3 py-1 text-sm rounded-full bg-secondary-100 text-secondary-800',
    partial: 'px-3 py-1 text-sm rounded-full bg-accent-100 text-accent-800',
    overdue: 'px-3 py-1 text-sm rounded-full bg-red-100 text-red-800',
    rejected: 'px-3 py-1 text-sm rounded-full bg-red-100 text-red-800',
  }
  return classes[status] || classes.draft
}

onMounted(() => {
  fetchBill()
})
</script>
