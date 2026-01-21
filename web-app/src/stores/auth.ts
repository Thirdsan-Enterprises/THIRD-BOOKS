import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import api from '@/utils/api'

interface User {
  id: number
  name: string
  email: string
  role: string
  tenant_id: string
}

interface Tenant {
  id: string
  name: string
  plan: string
}

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const tenant = ref<Tenant | null>(null)
  const token = ref<string | null>(localStorage.getItem('token'))
  const isLoading = ref(false)
  const error = ref<string | null>(null)

  const isAuthenticated = computed(() => !!token.value && !!user.value)
  const isSuperAdmin = computed(() => user.value?.role === 'super_admin')

  async function login(email: string, password: string) {
    isLoading.value = true
    error.value = null

    try {
      const response = await api.login(email, password)
      const data = response.data

      token.value = data.token
      user.value = data.user
      tenant.value = data.tenant

      localStorage.setItem('token', data.token)
      localStorage.setItem('tenant_id', data.user.tenant_id)

      return true
    } catch (err: any) {
      error.value = err.response?.data?.message || 'Login failed'
      return false
    } finally {
      isLoading.value = false
    }
  }

  async function register(data: any) {
    isLoading.value = true
    error.value = null

    try {
      const response = await api.register(data)
      const responseData = response.data

      token.value = responseData.token
      user.value = responseData.user
      tenant.value = responseData.tenant

      localStorage.setItem('token', responseData.token)
      localStorage.setItem('tenant_id', responseData.user.tenant_id)

      return true
    } catch (err: any) {
      error.value = err.response?.data?.message || 'Registration failed'
      return false
    } finally {
      isLoading.value = false
    }
  }

  async function logout() {
    try {
      await api.logout()
    } catch (err) {
      console.error('Logout error:', err)
    } finally {
      user.value = null
      tenant.value = null
      token.value = null
      localStorage.removeItem('token')
      localStorage.removeItem('tenant_id')
    }
  }

  async function fetchUser() {
    if (!token.value) return

    try {
      const response = await api.getUser()
      user.value = response.data.user
      tenant.value = response.data.tenant
    } catch (err) {
      console.error('Fetch user error:', err)
      await logout()
    }
  }

  function clearError() {
    error.value = null
  }

  return {
    user,
    tenant,
    token,
    isLoading,
    error,
    isAuthenticated,
    isSuperAdmin,
    login,
    register,
    logout,
    fetchUser,
    clearError,
  }
})
