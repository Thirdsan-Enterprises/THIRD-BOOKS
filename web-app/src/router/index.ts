import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/login',
      name: 'Login',
      component: () => import('@/views/Login.vue'),
      meta: { requiresGuest: true },
    },
    {
      path: '/register',
      name: 'Register',
      component: () => import('@/views/Register.vue'),
      meta: { requiresGuest: true },
    },
    {
      path: '/',
      redirect: '/dashboard',
    },
    {
      path: '/dashboard',
      name: 'Dashboard',
      component: () => import('@/views/Dashboard.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/invoices',
      name: 'InvoiceList',
      component: () => import('@/views/Invoices/List.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/invoices/create',
      name: 'InvoiceCreate',
      component: () => import('@/views/Invoices/Create.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/invoices/:id',
      name: 'InvoiceView',
      component: () => import('@/views/Invoices/View.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/customers',
      name: 'CustomerList',
      component: () => import('@/views/Customers/List.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/bills',
      name: 'BillList',
      component: () => import('@/views/Bills/List.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/bills/create',
      name: 'BillCreate',
      component: () => import('@/views/Bills/Create.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/bills/:id',
      name: 'BillView',
      component: () => import('@/views/Bills/View.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/vendors',
      name: 'VendorList',
      component: () => import('@/views/Vendors/List.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/accounts',
      name: 'AccountList',
      component: () => import('@/views/Accounts/List.vue'),
      meta: { requiresAuth: true },
    },
    {
      path: '/reports',
      name: 'Reports',
      component: () => import('@/views/Reports/Index.vue'),
      meta: { requiresAuth: true },
    },
  ],
})

// Navigation guard
router.beforeEach((to, from, next) => {
  const authStore = useAuthStore()

  if (to.meta.requiresAuth && !authStore.isAuthenticated) {
    next('/login')
  } else if (to.meta.requiresGuest && authStore.isAuthenticated) {
    next('/dashboard')
  } else {
    next()
  }
})

export default router
