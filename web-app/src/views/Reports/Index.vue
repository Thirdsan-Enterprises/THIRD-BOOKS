<template>
  <AppLayout>
    <div class="space-y-6">
      <h1 class="text-2xl font-bold text-gray-900">Financial Reports</h1>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <!-- Trial Balance -->
        <div class="card hover:shadow-lg transition-shadow cursor-pointer">
          <div class="flex items-start space-x-4">
            <div class="flex-shrink-0 bg-primary-100 rounded-lg p-3">
              <svg class="h-6 w-6 text-primary-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 7h6m0 10v-3m-3 3h.01M9 17h.01M9 14h.01M12 14h.01M15 11h.01M12 11h.01M9 11h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-medium text-gray-900">Trial Balance</h3>
              <p class="mt-1 text-sm text-gray-500">View all account balances at a specific date</p>
              <span class="mt-2 inline-block text-xs text-gray-400">Coming soon</span>
            </div>
          </div>
        </div>

        <!-- Balance Sheet -->
        <div class="card hover:shadow-lg transition-shadow cursor-pointer">
          <div class="flex items-start space-x-4">
            <div class="flex-shrink-0 bg-green-100 rounded-lg p-3">
              <svg class="h-6 w-6 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-medium text-gray-900">Balance Sheet</h3>
              <p class="mt-1 text-sm text-gray-500">Assets, Liabilities, and Equity snapshot</p>
              <span class="mt-2 inline-block text-xs text-gray-400">Coming soon</span>
            </div>
          </div>
        </div>

        <!-- Profit & Loss -->
        <div class="card hover:shadow-lg transition-shadow cursor-pointer">
          <div class="flex items-start space-x-4">
            <div class="flex-shrink-0 bg-blue-100 rounded-lg p-3">
              <svg class="h-6 w-6 text-blue-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-medium text-gray-900">Profit & Loss</h3>
              <p class="mt-1 text-sm text-gray-500">Revenue, expenses, and net income</p>
              <span class="mt-2 inline-block text-xs text-gray-400">Coming soon</span>
            </div>
          </div>
        </div>

        <!-- Aged Receivables -->
        <div class="card hover:shadow-lg transition-shadow cursor-pointer">
          <div class="flex items-start space-x-4">
            <div class="flex-shrink-0 bg-yellow-100 rounded-lg p-3">
              <svg class="h-6 w-6 text-yellow-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-medium text-gray-900">Aged Receivables</h3>
              <p class="mt-1 text-sm text-gray-500">Outstanding customer invoices by age</p>
              <span class="mt-2 inline-block text-xs text-gray-400">Coming soon</span>
            </div>
          </div>
        </div>

        <!-- Aged Payables -->
        <div class="card hover:shadow-lg transition-shadow cursor-pointer">
          <div class="flex items-start space-x-4">
            <div class="flex-shrink-0 bg-red-100 rounded-lg p-3">
              <svg class="h-6 w-6 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-medium text-gray-900">Aged Payables</h3>
              <p class="mt-1 text-sm text-gray-500">Outstanding vendor bills by age</p>
              <span class="mt-2 inline-block text-xs text-gray-400">Coming soon</span>
            </div>
          </div>
        </div>

        <!-- General Ledger -->
        <div class="card hover:shadow-lg transition-shadow cursor-pointer">
          <div class="flex items-start space-x-4">
            <div class="flex-shrink-0 bg-purple-100 rounded-lg p-3">
              <svg class="h-6 w-6 text-purple-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
              </svg>
            </div>
            <div>
              <h3 class="text-lg font-medium text-gray-900">General Ledger</h3>
              <p class="mt-1 text-sm text-gray-500">Complete transaction history by account</p>
              <span class="mt-2 inline-block text-xs text-gray-400">Coming soon</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Info Card -->
      <div class="card bg-blue-50 border-blue-200">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-blue-800">Financial Reports</h3>
            <div class="mt-2 text-sm text-blue-700">
              <p>
                All major financial reports are available via the API. The UI for viewing and filtering reports
                is being developed and will be available soon.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import AppLayout from '@/components/AppLayout.vue'
</script>
