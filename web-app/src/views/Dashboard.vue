<template>
  <AppLayout>
      <!-- Stats -->
      <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4 mb-8">
        <div class="card">
          <div class="flex items-center">
            <div class="flex-shrink-0 bg-primary-500 rounded-md p-3">
              <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Revenue (YTD)</dt>
                <dd class="text-2xl font-semibold text-gray-900">{{ formatCurrency(stats.revenue) }}</dd>
              </dl>
            </div>
          </div>
        </div>

        <div class="card">
          <div class="flex items-center">
            <div class="flex-shrink-0 bg-red-500 rounded-md p-3">
              <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Expenses (YTD)</dt>
                <dd class="text-2xl font-semibold text-gray-900">{{ formatCurrency(stats.expenses) }}</dd>
              </dl>
            </div>
          </div>
        </div>

        <div class="card">
          <div class="flex items-center">
            <div class="flex-shrink-0 bg-green-500 rounded-md p-3">
              <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Profit (YTD)</dt>
                <dd class="text-2xl font-semibold text-gray-900">{{ formatCurrency(stats.profit) }}</dd>
              </dl>
            </div>
          </div>
        </div>

        <div class="card">
          <div class="flex items-center">
            <div class="flex-shrink-0 bg-yellow-500 rounded-md p-3">
              <svg class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" />
              </svg>
            </div>
            <div class="ml-5 w-0 flex-1">
              <dl>
                <dt class="text-sm font-medium text-gray-500 truncate">Cash Position</dt>
                <dd class="text-2xl font-semibold text-gray-900">{{ formatCurrency(stats.cash_position) }}</dd>
              </dl>
            </div>
          </div>
        </div>
      </div>

      <!-- Recent Activity -->
      <div class="grid grid-cols-1 gap-5 lg:grid-cols-2">
        <!-- Recent Invoices -->
        <div class="card">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Recent Invoices</h3>
          <div class="flow-root">
            <ul role="list" class="-my-5 divide-y divide-gray-200">
              <li v-for="invoice in recentInvoices" :key="invoice.id" class="py-4">
                <div class="flex items-center space-x-4">
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium text-gray-900 truncate">{{ invoice.invoice_number }}</p>
                    <p class="text-sm text-gray-500 truncate">{{ invoice.customer_name }}</p>
                  </div>
                  <div class="text-right">
                    <p class="text-sm font-medium text-gray-900">{{ formatCurrency(invoice.total) }}</p>
                    <p class="text-xs text-gray-500">{{ invoice.status }}</p>
                  </div>
                </div>
              </li>
            </ul>
          </div>
        </div>

        <!-- Recent Bills -->
        <div class="card">
          <h3 class="text-lg font-medium text-gray-900 mb-4">Recent Bills</h3>
          <div class="flow-root">
            <ul role="list" class="-my-5 divide-y divide-gray-200">
              <li v-for="bill in recentBills" :key="bill.id" class="py-4">
                <div class="flex items-center space-x-4">
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium text-gray-900 truncate">{{ bill.bill_number }}</p>
                    <p class="text-sm text-gray-500 truncate">{{ bill.vendor_name }}</p>
                  </div>
                  <div class="text-right">
                    <p class="text-sm font-medium text-gray-900">{{ formatCurrency(bill.total) }}</p>
                    <p class="text-xs text-gray-500">{{ bill.status }}</p>
                  </div>
                </div>
              </li>
            </ul>
          </div>
        </div>
      </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import AppLayout from '@/components/AppLayout.vue'
import api from '@/utils/api'

interface DashboardStats {
  revenue: number
  expenses: number
  profit: number
  cash_position: number
}

interface Invoice {
  id: number
  invoice_number: string
  customer_name: string
  total: number
  status: string
}

interface Bill {
  id: number
  bill_number: string
  vendor_name: string
  total: number
  status: string
}

const isLoading = ref(true)
const stats = ref<DashboardStats>({
  revenue: 0,
  expenses: 0,
  profit: 0,
  cash_position: 0,
})

const recentInvoices = ref<Invoice[]>([])
const recentBills = ref<Bill[]>([])

const formatCurrency = (amount: number): string => {
  return new Intl.NumberFormat('en-UG', {
    style: 'currency',
    currency: 'UGX',
    minimumFractionDigits: 0,
  }).format(amount)
}

async function fetchDashboardData() {
  try {
    isLoading.value = true

    // Fetch dashboard overview
    const overviewResponse = await api.getDashboardOverview()
    const data = overviewResponse.data.data

    stats.value = {
      revenue: data.revenue || 0,
      expenses: data.expenses || 0,
      profit: data.profit || 0,
      cash_position: data.cash_position || 0,
    }

    // Fetch recent invoices
    const invoicesResponse = await api.getInvoices({ limit: 5, sort: '-created_at' })
    recentInvoices.value = invoicesResponse.data.data.map((inv: any) => ({
      id: inv.id,
      invoice_number: inv.invoice_number,
      customer_name: inv.customer?.name || 'N/A',
      total: inv.total,
      status: inv.status,
    }))

    // Fetch recent bills
    const billsResponse = await api.getBills({ limit: 5, sort: '-created_at' })
    recentBills.value = billsResponse.data.data.map((bill: any) => ({
      id: bill.id,
      bill_number: bill.bill_number,
      vendor_name: bill.vendor?.name || 'N/A',
      total: bill.total,
      status: bill.status,
    }))
  } catch (error) {
    console.error('Failed to fetch dashboard data:', error)
  } finally {
    isLoading.value = false
  }
}

onMounted(() => {
  fetchDashboardData()
})
</script>
