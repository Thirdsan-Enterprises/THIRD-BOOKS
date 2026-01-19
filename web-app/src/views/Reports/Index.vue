<template>
  <AppLayout>
    <div class="space-y-6">
      <h1 class="text-2xl font-bold text-gray-900">Financial Reports</h1>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <!-- Trial Balance -->
        <div
          class="card hover:shadow-lg transition-shadow cursor-pointer"
          @click="viewReport('trial-balance')"
        >
          <div class="flex items-start space-x-4">
            <div class="flex-shrink-0 bg-primary-100 rounded-lg p-3">
              <svg class="h-6 w-6 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15 11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-medium text-gray-900">Trial Balance</h3>
              <p class="mt-1 text-sm text-gray-500">View all account balances at a specific date</p>
            </div>
          </div>
        </div>

        <!-- Balance Sheet -->
        <div
          class="card hover:shadow-lg transition-shadow cursor-pointer"
          @click="viewReport('balance-sheet')"
        >
          <div class="flex items-start space-x-4">
            <div class="flex-shrink-0 bg-secondary-100 rounded-lg p-3">
              <svg class="h-6 w-6 text-secondary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-medium text-gray-900">Balance Sheet</h3>
              <p class="mt-1 text-sm text-gray-500">Assets, Liabilities, and Equity snapshot</p>
            </div>
          </div>
        </div>

        <!-- Profit & Loss -->
        <div
          class="card hover:shadow-lg transition-shadow cursor-pointer"
          @click="viewReport('profit-loss')"
        >
          <div class="flex items-start space-x-4">
            <div class="flex-shrink-0 bg-blue-100 rounded-lg p-3">
              <svg class="h-6 w-6 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-medium text-gray-900">Profit & Loss</h3>
              <p class="mt-1 text-sm text-gray-500">Revenue, expenses, and net income</p>
            </div>
          </div>
        </div>

        <!-- Aged Receivables -->
        <div
          class="card hover:shadow-lg transition-shadow cursor-pointer"
          @click="viewReport('aged-receivables')"
        >
          <div class="flex items-start space-x-4">
            <div class="flex-shrink-0 bg-accent-100 rounded-lg p-3">
              <svg class="h-6 w-6 text-accent-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-medium text-gray-900">Aged Receivables</h3>
              <p class="mt-1 text-sm text-gray-500">Outstanding customer invoices by age</p>
            </div>
          </div>
        </div>

        <!-- Aged Payables -->
        <div
          class="card hover:shadow-lg transition-shadow cursor-pointer"
          @click="viewReport('aged-payables')"
        >
          <div class="flex items-start space-x-4">
            <div class="flex-shrink-0 bg-red-100 rounded-lg p-3">
              <svg class="h-6 w-6 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-medium text-gray-900">Aged Payables</h3>
              <p class="mt-1 text-sm text-gray-500">Outstanding vendor bills by age</p>
            </div>
          </div>
        </div>

        <!-- General Ledger -->
        <div
          class="card hover:shadow-lg transition-shadow cursor-pointer"
          @click="viewReport('general-ledger')"
        >
          <div class="flex items-start space-x-4">
            <div class="flex-shrink-0 bg-purple-100 rounded-lg p-3">
              <svg class="h-6 w-6 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-medium text-gray-900">General Ledger</h3>
              <p class="mt-1 text-sm text-gray-500">Complete transaction history by account</p>
            </div>
          </div>
        </div>
      </div>

      <!-- Selected Report Display -->
      <div v-if="selectedReport" class="space-y-4">
        <!-- Report Header -->
        <div class="card">
          <div class="flex justify-between items-start mb-4">
            <div>
              <h2 class="text-xl font-bold text-gray-900">{{ reportTitle }}</h2>
              <p class="text-sm text-gray-500 mt-1">{{ reportDescription }}</p>
            </div>
            <button
              @click="selectedReport = null"
              class="text-gray-400 hover:text-gray-600"
            >
              <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>

          <!-- Date Filters -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label class="label">Report Date</label>
              <input
                v-model="reportFilters.date"
                type="date"
                class="input"
                @change="fetchReport"
              />
            </div>
            <div v-if="selectedReport === 'profit-loss'">
              <label class="label">Start Date</label>
              <input
                v-model="reportFilters.start_date"
                type="date"
                class="input"
                @change="fetchReport"
              />
            </div>
            <div v-if="selectedReport === 'profit-loss'">
              <label class="label">End Date</label>
              <input
                v-model="reportFilters.end_date"
                type="date"
                class="input"
                @change="fetchReport"
              />
            </div>
            <div class="flex items-end">
              <button @click="fetchReport" class="btn btn-primary w-full">
                Generate Report
              </button>
            </div>
          </div>
        </div>

        <!-- Loading State -->
        <div v-if="isLoadingReport" class="text-center py-12 card">
          <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
          <p class="mt-2 text-gray-500">Generating report...</p>
        </div>

        <!-- Report Data -->
        <div v-else-if="reportData" class="card">
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th
                    v-for="column in reportColumns"
                    :key="column.key"
                    class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                    :class="column.align === 'right' ? 'text-right' : ''"
                  >
                    {{ column.label }}
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <tr v-if="reportRows.length === 0">
                  <td :colspan="reportColumns.length" class="px-6 py-12 text-center text-gray-500">
                    No data found for the selected period.
                  </td>
                </tr>
                <tr
                  v-for="(row, index) in reportRows"
                  :key="index"
                  :class="row.isTotal ? 'font-bold bg-gray-50' : ''"
                >
                  <td
                    v-for="column in reportColumns"
                    :key="column.key"
                    class="px-6 py-4 whitespace-nowrap text-sm"
                    :class="[
                      row.isTotal ? 'font-bold text-gray-900' : 'text-gray-900',
                      column.align === 'right' ? 'text-right' : ''
                    ]"
                  >
                    {{ formatCell(row[column.key], column.type) }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <!-- Export Options -->
          <div class="mt-4 pt-4 border-t border-gray-200 flex justify-end space-x-3">
            <button class="btn btn-secondary">
              Export to Excel
            </button>
            <button class="btn btn-secondary">
              Export to PDF
            </button>
          </div>
        </div>
      </div>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import AppLayout from '@/components/AppLayout.vue'
import api from '@/utils/api'

const selectedReport = ref<string | null>(null)
const isLoadingReport = ref(false)
const reportData = ref<any>(null)

const reportFilters = ref({
  date: new Date().toISOString().split('T')[0],
  start_date: new Date(new Date().getFullYear(), 0, 1).toISOString().split('T')[0],
  end_date: new Date().toISOString().split('T')[0],
})

const reportConfigs: Record<string, any> = {
  'trial-balance': {
    title: 'Trial Balance',
    description: 'A list of all accounts with their debit and credit balances',
    columns: [
      { key: 'account_code', label: 'Account Code', align: 'left' },
      { key: 'account_name', label: 'Account Name', align: 'left' },
      { key: 'debit', label: 'Debit', align: 'right', type: 'currency' },
      { key: 'credit', label: 'Credit', align: 'right', type: 'currency' },
    ],
  },
  'balance-sheet': {
    title: 'Balance Sheet',
    description: 'Statement of financial position showing assets, liabilities, and equity',
    columns: [
      { key: 'account_name', label: 'Account', align: 'left' },
      { key: 'balance', label: 'Balance', align: 'right', type: 'currency' },
    ],
  },
  'profit-loss': {
    title: 'Profit & Loss Statement',
    description: 'Income statement showing revenue, expenses, and net income',
    columns: [
      { key: 'account_name', label: 'Account', align: 'left' },
      { key: 'amount', label: 'Amount', align: 'right', type: 'currency' },
    ],
  },
  'aged-receivables': {
    title: 'Aged Receivables',
    description: 'Customer balances aged by invoice due date',
    columns: [
      { key: 'customer_name', label: 'Customer', align: 'left' },
      { key: 'current', label: 'Current', align: 'right', type: 'currency' },
      { key: 'days_30', label: '1-30 Days', align: 'right', type: 'currency' },
      { key: 'days_60', label: '31-60 Days', align: 'right', type: 'currency' },
      { key: 'days_90', label: '61-90 Days', align: 'right', type: 'currency' },
      { key: 'days_over_90', label: '90+ Days', align: 'right', type: 'currency' },
      { key: 'total', label: 'Total', align: 'right', type: 'currency' },
    ],
  },
  'aged-payables': {
    title: 'Aged Payables',
    description: 'Vendor balances aged by bill due date',
    columns: [
      { key: 'vendor_name', label: 'Vendor', align: 'left' },
      { key: 'current', label: 'Current', align: 'right', type: 'currency' },
      { key: 'days_30', label: '1-30 Days', align: 'right', type: 'currency' },
      { key: 'days_60', label: '31-60 Days', align: 'right', type: 'currency' },
      { key: 'days_90', label: '61-90 Days', align: 'right', type: 'currency' },
      { key: 'days_over_90', label: '90+ Days', align: 'right', type: 'currency' },
      { key: 'total', label: 'Total', align: 'right', type: 'currency' },
    ],
  },
  'general-ledger': {
    title: 'General Ledger',
    description: 'Complete transaction history for all accounts',
    columns: [
      { key: 'date', label: 'Date', align: 'left', type: 'date' },
      { key: 'account_code', label: 'Account', align: 'left' },
      { key: 'description', label: 'Description', align: 'left' },
      { key: 'debit', label: 'Debit', align: 'right', type: 'currency' },
      { key: 'credit', label: 'Credit', align: 'right', type: 'currency' },
      { key: 'balance', label: 'Balance', align: 'right', type: 'currency' },
    ],
  },
}

const reportTitle = computed(() => {
  return selectedReport.value ? reportConfigs[selectedReport.value].title : ''
})

const reportDescription = computed(() => {
  return selectedReport.value ? reportConfigs[selectedReport.value].description : ''
})

const reportColumns = computed(() => {
  return selectedReport.value ? reportConfigs[selectedReport.value].columns : []
})

const reportRows = computed(() => {
  if (!reportData.value) return []
  return reportData.value.data || []
})

function viewReport(reportType: string) {
  selectedReport.value = reportType
  fetchReport()
}

async function fetchReport() {
  if (!selectedReport.value) return

  isLoadingReport.value = true
  reportData.value = null

  try {
    let response
    const params: any = { date: reportFilters.value.date }

    if (selectedReport.value === 'profit-loss') {
      params.start_date = reportFilters.value.start_date
      params.end_date = reportFilters.value.end_date
    }

    switch (selectedReport.value) {
      case 'trial-balance':
        response = await api.getTrialBalance(params)
        break
      case 'balance-sheet':
        response = await api.getBalanceSheet(params)
        break
      case 'profit-loss':
        response = await api.getProfitLoss(params)
        break
      case 'aged-receivables':
        response = await api.getAgedReceivables(params)
        break
      case 'aged-payables':
        response = await api.getAgedPayables(params)
        break
      case 'general-ledger':
        response = await api.getGeneralLedger(params)
        break
    }

    if (response) {
      reportData.value = response.data
    }
  } catch (error) {
    console.error('Failed to fetch report:', error)
    alert('Failed to generate report. Please try again.')
  } finally {
    isLoadingReport.value = false
  }
}

function formatCell(value: any, type?: string): string {
  if (value === null || value === undefined) return '-'

  if (type === 'currency') {
    return formatCurrency(Number(value))
  }

  if (type === 'date') {
    return new Date(value).toLocaleDateString('en-UG')
  }

  return String(value)
}

function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('en-UG', {
    style: 'currency',
    currency: 'UGX',
    minimumFractionDigits: 0,
  }).format(amount)
}
</script>
