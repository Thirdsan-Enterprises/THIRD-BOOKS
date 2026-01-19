import axios, { AxiosInstance, AxiosResponse, AxiosError } from 'axios'

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000/api'

class ApiService {
  private api: AxiosInstance

  constructor() {
    this.api = axios.create({
      baseURL: API_URL,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    })

    // Request interceptor
    this.api.interceptors.request.use(
      (config) => {
        const token = localStorage.getItem('token')
        const tenantId = localStorage.getItem('tenant_id')

        if (token) {
          config.headers.Authorization = `Bearer ${token}`
        }

        if (tenantId) {
          config.headers['X-Tenant-ID'] = tenantId
        }

        return config
      },
      (error) => Promise.reject(error)
    )

    // Response interceptor
    this.api.interceptors.response.use(
      (response: AxiosResponse) => response,
      (error: AxiosError) => {
        if (error.response?.status === 401) {
          // Unauthorized - clear auth and redirect to login
          localStorage.removeItem('token')
          localStorage.removeItem('tenant_id')
          window.location.href = '/login'
        }
        return Promise.reject(error)
      }
    )
  }

  // Auth endpoints
  async register(data: any) {
    return this.api.post('/auth/register', data)
  }

  async login(email: string, password: string) {
    return this.api.post('/auth/login', { email, password })
  }

  async logout() {
    return this.api.post('/auth/logout')
  }

  async getUser() {
    return this.api.get('/auth/user')
  }

  // Dashboard
  async getDashboardOverview() {
    return this.api.get('/dashboard/overview')
  }

  // Accounts
  async getAccounts(params?: any) {
    return this.api.get('/accounts', { params })
  }

  async getAccount(id: number) {
    return this.api.get(`/accounts/${id}`)
  }

  async createAccount(data: any) {
    return this.api.post('/accounts', data)
  }

  async updateAccount(id: number, data: any) {
    return this.api.put(`/accounts/${id}`, data)
  }

  async deleteAccount(id: number) {
    return this.api.delete(`/accounts/${id}`)
  }

  async getAccountBalance(id: number, date?: string) {
    return this.api.get(`/accounts/${id}/balance`, { params: { date } })
  }

  async getAccountLedger(id: number, params?: any) {
    return this.api.get(`/accounts/${id}/ledger`, { params })
  }

  // Journal Entries
  async getJournalEntries(params?: any) {
    return this.api.get('/journal-entries', { params })
  }

  async getJournalEntry(id: number) {
    return this.api.get(`/journal-entries/${id}`)
  }

  async createJournalEntry(data: any) {
    return this.api.post('/journal-entries', data)
  }

  async postJournalEntry(id: number) {
    return this.api.post(`/journal-entries/${id}/post`)
  }

  async unpostJournalEntry(id: number) {
    return this.api.post(`/journal-entries/${id}/unpost`)
  }

  // Customers
  async getCustomers(params?: any) {
    return this.api.get('/customers', { params })
  }

  async getCustomer(id: number) {
    return this.api.get(`/customers/${id}`)
  }

  async createCustomer(data: any) {
    return this.api.post('/customers', data)
  }

  async updateCustomer(id: number, data: any) {
    return this.api.put(`/customers/${id}`, data)
  }

  async deleteCustomer(id: number) {
    return this.api.delete(`/customers/${id}`)
  }

  async getCustomerStatement(id: number, params?: any) {
    return this.api.get(`/customers/${id}/statement`, { params })
  }

  async getCustomerAging(id: number) {
    return this.api.get(`/customers/${id}/aging`)
  }

  // Invoices
  async getInvoices(params?: any) {
    return this.api.get('/invoices', { params })
  }

  async getInvoice(id: number) {
    return this.api.get(`/invoices/${id}`)
  }

  async createInvoice(data: any) {
    return this.api.post('/invoices', data)
  }

  async updateInvoice(id: number, data: any) {
    return this.api.put(`/invoices/${id}`, data)
  }

  async deleteInvoice(id: number) {
    return this.api.delete(`/invoices/${id}`)
  }

  async sendInvoice(id: number) {
    return this.api.post(`/invoices/${id}/send`)
  }

  async recordInvoicePayment(id: number, data: any) {
    return this.api.post(`/invoices/${id}/payment`, data)
  }

  // Vendors
  async getVendors(params?: any) {
    return this.api.get('/vendors', { params })
  }

  async getVendor(id: number) {
    return this.api.get(`/vendors/${id}`)
  }

  async createVendor(data: any) {
    return this.api.post('/vendors', data)
  }

  async updateVendor(id: number, data: any) {
    return this.api.put(`/vendors/${id}`, data)
  }

  async deleteVendor(id: number) {
    return this.api.delete(`/vendors/${id}`)
  }

  // Bills
  async getBills(params?: any) {
    return this.api.get('/bills', { params })
  }

  async getBill(id: number) {
    return this.api.get(`/bills/${id}`)
  }

  async createBill(data: any) {
    return this.api.post('/bills', data)
  }

  async updateBill(id: number, data: any) {
    return this.api.put(`/bills/${id}`, data)
  }

  async deleteBill(id: number) {
    return this.api.delete(`/bills/${id}`)
  }

  async recordBillPayment(id: number, data: any) {
    return this.api.post(`/bills/${id}/payment`, data)
  }

  // Reports
  async getTrialBalance(date?: string) {
    return this.api.get('/reports/trial-balance', { params: { date } })
  }

  async getBalanceSheet(date?: string) {
    return this.api.get('/reports/balance-sheet', { params: { date } })
  }

  async getProfitLoss(startDate?: string, endDate?: string) {
    return this.api.get('/reports/profit-loss', {
      params: { start_date: startDate, end_date: endDate },
    })
  }

  async getAgedReceivables() {
    return this.api.get('/reports/aged-receivables')
  }

  async getAgedPayables() {
    return this.api.get('/reports/aged-payables')
  }

  // Utilities
  async getCurrencies() {
    return this.api.get('/currencies')
  }

  async getCompanies() {
    return this.api.get('/companies')
  }
}

export default new ApiService()
