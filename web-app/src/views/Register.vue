<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
    <div class="max-w-md w-full space-y-8">
      <div>
        <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
          ThirdBooks
        </h2>
        <p class="mt-2 text-center text-sm text-gray-600">
          Create your account
        </p>
      </div>
      <form class="mt-8 space-y-6" @submit.prevent="handleSubmit">
        <div v-if="authStore.error" class="rounded-md bg-red-50 p-4">
          <div class="text-sm text-red-700">
            {{ authStore.error }}
          </div>
        </div>

        <div class="space-y-4">
          <div>
            <label for="company_name" class="label">Company Name</label>
            <input
              id="company_name"
              v-model="form.company_name"
              type="text"
              required
              class="input"
              placeholder="My Company Ltd"
            />
          </div>

          <div>
            <label for="name" class="label">Your Name</label>
            <input
              id="name"
              v-model="form.name"
              type="text"
              required
              class="input"
              placeholder="John Doe"
            />
          </div>

          <div>
            <label for="email" class="label">Email</label>
            <input
              id="email"
              v-model="form.email"
              type="email"
              required
              class="input"
              placeholder="john@company.com"
            />
          </div>

          <div>
            <label for="phone" class="label">Phone (Optional)</label>
            <input
              id="phone"
              v-model="form.phone"
              type="tel"
              class="input"
              placeholder="+256700123456"
            />
          </div>

          <div>
            <label for="password" class="label">Password</label>
            <input
              id="password"
              v-model="form.password"
              type="password"
              required
              minlength="8"
              class="input"
              placeholder="Minimum 8 characters"
            />
          </div>

          <div>
            <label for="password_confirmation" class="label">Confirm Password</label>
            <input
              id="password_confirmation"
              v-model="form.password_confirmation"
              type="password"
              required
              class="input"
              placeholder="Re-enter password"
            />
          </div>
        </div>

        <div class="text-sm">
          <a href="/login" class="font-medium text-primary-600 hover:text-primary-500">
            Already have an account? Sign in
          </a>
        </div>

        <div>
          <button
            type="submit"
            :disabled="authStore.isLoading"
            class="btn btn-primary w-full disabled:opacity-50"
          >
            <span v-if="authStore.isLoading">Creating account...</span>
            <span v-else>Create Account</span>
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const authStore = useAuthStore()

const form = ref({
  company_name: '',
  name: '',
  email: '',
  phone: '',
  password: '',
  password_confirmation: '',
  country: 'UG',
  base_currency: 'UGX',
})

async function handleSubmit() {
  if (form.value.password !== form.value.password_confirmation) {
    authStore.error = 'Passwords do not match'
    return
  }

  const success = await authStore.register(form.value)
  if (success) {
    router.push('/dashboard')
  }
}
</script>
