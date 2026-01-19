<template>
  <div class="min-h-screen bg-gray-50">
    <!-- Navigation -->
    <nav class="bg-white shadow-sm">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex">
            <div class="flex-shrink-0 flex items-center">
              <h1 class="text-2xl font-bold text-primary-600">ThirdBooks</h1>
            </div>
            <div class="hidden sm:ml-6 sm:flex sm:space-x-8">
              <a href="#" class="border-primary-500 text-gray-900 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium">
                Dashboard
              </a>
              <a href="#" class="border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium">
                Invoices
              </a>
              <a href="#" class="border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium">
                Bills
              </a>
              <a href="#" class="border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium">
                Reports
              </a>
            </div>
          </div>
          <div class="flex items-center">
            <span class="text-sm text-gray-700">{{ user?.name }}</span>
          </div>
        </div>
      </div>
    </nav>

    <!-- Page Content -->
    <main class="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
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
    </main>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'

interface DashboardStats {
  revenue: number
  expenses: number
  profit: number
  cash_position: number
}

interface User {
  name: string
  email: string
}

const user = ref<User>({ name: 'Demo User', email: 'demo@example.com' })
const stats = ref<DashboardStats>({
  revenue: 1000000,
  expenses: 600000,
  profit: 400000,
  cash_position: 500000,
})

const recentInvoices = ref([
  { id: 1, invoice_number: 'INV-2024-00001', customer_name: 'John Doe', total: 118000, status: 'paid' },
  { id: 2, invoice_number: 'INV-2024-00002', customer_name: 'Jane Smith', total: 250000, status: 'sent' },
  { id: 3, invoice_number: 'INV-2024-00003', customer_name: 'Acme Corp', total: 500000, status: 'draft' },
])

const recentBills = ref([
  { id: 1, bill_number: 'BILL-2024-00001', vendor_name: 'Office Supplies Ltd', total: 50000, status: 'paid' },
  { id: 2, bill_number: 'BILL-2024-00002', vendor_name: 'Tech Solutions', total: 150000, status: 'approved' },
  { id: 3, bill_number: 'BILL-2024-00003', vendor_name: 'Utilities Co', total: 75000, status: 'draft' },
])

const formatCurrency = (amount: number): string => {
  return new Intl.NumberFormat('en-UG', {
    style: 'currency',
    currency: 'UGX',
    minimumFractionDigits: 0,
  }).format(amount)
}

onMounted(() => {
  // Fetch real data from API
  // This is placeholder data for now
})
</script>
