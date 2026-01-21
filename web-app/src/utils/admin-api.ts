import axios, { AxiosInstance, AxiosResponse } from 'axios'

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000/api'

class AdminApiService {
  private api: AxiosInstance

  constructor() {
    this.api = axios.create({
      baseURL: `${API_URL}/admin`,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    })

    // Request interceptor
    this.api.interceptors.request.use(
      (config) => {
        const token = localStorage.getItem('token')
        if (token) {
          config.headers.Authorization = `Bearer ${token}`
        }
        return config
      },
      (error) => Promise.reject(error)
    )

    // Response interceptor
    this.api.interceptors.response.use(
      (response: AxiosResponse) => response,
      (error) => {
        if (error.response?.status === 403) {
          // Not a super admin
          window.location.href = '/dashboard'
        }
        return Promise.reject(error)
      }
    )
  }

  // Analytics
  async getDashboard() {
    return this.api.get('/analytics/dashboard')
  }

  async getSystemHealth() {
    return this.api.get('/analytics/system-health')
  }

  async getTenantTimeline(tenantId: string) {
    return this.api.get(`/analytics/tenant-timeline/${tenantId}`)
  }

  async exportData(type: string) {
    return this.api.get('/analytics/export', {
      params: { type },
      responseType: 'blob',
    })
  }

  // Tenants
  async getTenants(params?: any) {
    return this.api.get('/tenants', { params })
  }

  async getTenant(id: string) {
    return this.api.get(`/tenants/${id}`)
  }

  async updateTenant(id: string, data: any) {
    return this.api.put(`/tenants/${id}`, data)
  }

  async suspendTenant(id: string) {
    return this.api.post(`/tenants/${id}/suspend`)
  }

  async activateTenant(id: string) {
    return this.api.post(`/tenants/${id}/activate`)
  }

  async upgradeTenantPlan(id: string, data: any) {
    return this.api.post(`/tenants/${id}/upgrade-plan`, data)
  }

  async extendSubscription(id: string, months: number) {
    return this.api.post(`/tenants/${id}/extend-subscription`, { months })
  }

  async deleteTenant(id: string) {
    return this.api.delete(`/tenants/${id}`)
  }

  // Users
  async getUsers(params?: any) {
    return this.api.get('/users', { params })
  }

  async getUser(id: string) {
    return this.api.get(`/users/${id}`)
  }

  async updateUser(id: string, data: any) {
    return this.api.put(`/users/${id}`, data)
  }

  async activateUser(id: string) {
    return this.api.post(`/users/${id}/activate`)
  }

  async deactivateUser(id: string) {
    return this.api.post(`/users/${id}/deactivate`)
  }

  async resetUserPassword(id: string, password: string) {
    return this.api.post(`/users/${id}/reset-password`, { password })
  }

  async forceLogoutUser(id: string) {
    return this.api.post(`/users/${id}/force-logout`)
  }

  async impersonateUser(id: string) {
    return this.api.post(`/users/${id}/impersonate`)
  }

  async deleteUser(id: string) {
    return this.api.delete(`/users/${id}`)
  }

  // Audit Logs
  async getAuditLogs(params?: any) {
    return this.api.get('/audit-logs', { params })
  }

  async getAuditLog(id: number) {
    return this.api.get(`/audit-logs/${id}`)
  }

  async getAuditStatistics(days?: number) {
    return this.api.get('/audit-logs/statistics', { params: { days } })
  }

  async getAuditTimeline(limit?: number) {
    return this.api.get('/audit-logs/timeline', { params: { limit } })
  }

  async exportAuditLogs(params?: any) {
    return this.api.get('/audit-logs/export', {
      params,
      responseType: 'blob',
    })
  }
}

export default new AdminApiService()
