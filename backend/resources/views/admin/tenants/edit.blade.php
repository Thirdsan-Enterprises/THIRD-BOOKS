@extends('layouts.admin')

@section('title', 'Edit ' . $tenant->company_name)
@section('header', 'Edit Tenant')

@section('content')
<div class="space-y-6">
    <!-- Back Button -->
    <div>
        <a href="{{ route('admin.tenants.show', $tenant) }}" class="inline-flex items-center text-sm text-gray-500 hover:text-gray-700">
            <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
            </svg>
            Back to Tenant
        </a>
    </div>

    <form method="POST" action="{{ route('admin.tenants.update', $tenant) }}" class="space-y-6">
        @csrf
        @method('PUT')

        <!-- Company Information -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200">
            <div class="px-6 py-4 border-b border-gray-200">
                <h3 class="text-lg font-semibold text-gray-900">Company Information</h3>
            </div>
            <div class="p-6 grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                    <label for="company_name" class="block text-sm font-medium text-gray-700">Company Name</label>
                    <input type="text" name="company_name" id="company_name"
                           value="{{ old('company_name', $tenant->company_name) }}"
                           class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
                           required>
                    @error('company_name')
                        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                    @enderror
                </div>

                <div>
                    <label for="name" class="block text-sm font-medium text-gray-700">Contact Name</label>
                    <input type="text" name="name" id="name"
                           value="{{ old('name', $tenant->name) }}"
                           class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
                           required>
                    @error('name')
                        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                    @enderror
                </div>

                <div>
                    <label for="email" class="block text-sm font-medium text-gray-700">Email</label>
                    <input type="email" name="email" id="email"
                           value="{{ old('email', $tenant->email) }}"
                           class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
                           required>
                    @error('email')
                        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                    @enderror
                </div>

                <div>
                    <label for="phone" class="block text-sm font-medium text-gray-700">Phone</label>
                    <input type="text" name="phone" id="phone"
                           value="{{ old('phone', $tenant->phone) }}"
                           class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500">
                    @error('phone')
                        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                    @enderror
                </div>

                <div class="md:col-span-2">
                    <label for="address" class="block text-sm font-medium text-gray-700">Address</label>
                    <textarea name="address" id="address" rows="2"
                              class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500">{{ old('address', $tenant->address) }}</textarea>
                    @error('address')
                        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                    @enderror
                </div>

                <div>
                    <label for="country" class="block text-sm font-medium text-gray-700">Country</label>
                    <select name="country" id="country"
                            class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500">
                        <option value="UG" {{ old('country', $tenant->country) === 'UG' ? 'selected' : '' }}>Uganda</option>
                        <option value="KE" {{ old('country', $tenant->country) === 'KE' ? 'selected' : '' }}>Kenya</option>
                        <option value="TZ" {{ old('country', $tenant->country) === 'TZ' ? 'selected' : '' }}>Tanzania</option>
                        <option value="RW" {{ old('country', $tenant->country) === 'RW' ? 'selected' : '' }}>Rwanda</option>
                    </select>
                    @error('country')
                        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                    @enderror
                </div>
            </div>
        </div>

        <!-- Subscription -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200">
            <div class="px-6 py-4 border-b border-gray-200">
                <h3 class="text-lg font-semibold text-gray-900">Subscription</h3>
            </div>
            <div class="p-6 grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                    <label for="plan" class="block text-sm font-medium text-gray-700">Plan</label>
                    <select name="plan" id="plan"
                            class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500">
                        <option value="trial" {{ old('plan', $tenant->plan) === 'trial' ? 'selected' : '' }}>Trial</option>
                        <option value="basic" {{ old('plan', $tenant->plan) === 'basic' ? 'selected' : '' }}>Basic</option>
                        <option value="premium" {{ old('plan', $tenant->plan) === 'premium' ? 'selected' : '' }}>Premium</option>
                        <option value="enterprise" {{ old('plan', $tenant->plan) === 'enterprise' ? 'selected' : '' }}>Enterprise</option>
                    </select>
                    @error('plan')
                        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                    @enderror
                </div>

                <div>
                    <label for="status" class="block text-sm font-medium text-gray-700">Status</label>
                    <select name="status" id="status"
                            class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500">
                        <option value="active" {{ old('status', $tenant->status) === 'active' ? 'selected' : '' }}>Active</option>
                        <option value="suspended" {{ old('status', $tenant->status) === 'suspended' ? 'selected' : '' }}>Suspended</option>
                        <option value="cancelled" {{ old('status', $tenant->status) === 'cancelled' ? 'selected' : '' }}>Cancelled</option>
                    </select>
                    @error('status')
                        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                    @enderror
                </div>

                <div>
                    <label for="trial_ends_at" class="block text-sm font-medium text-gray-700">Trial Ends At</label>
                    <input type="date" name="trial_ends_at" id="trial_ends_at"
                           value="{{ old('trial_ends_at', $tenant->trial_ends_at?->format('Y-m-d')) }}"
                           class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500">
                    @error('trial_ends_at')
                        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                    @enderror
                </div>

                <div>
                    <label for="subscription_ends_at" class="block text-sm font-medium text-gray-700">Subscription Ends At</label>
                    <input type="date" name="subscription_ends_at" id="subscription_ends_at"
                           value="{{ old('subscription_ends_at', $tenant->subscription_ends_at?->format('Y-m-d')) }}"
                           class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500">
                    @error('subscription_ends_at')
                        <p class="mt-1 text-sm text-red-600">{{ $message }}</p>
                    @enderror
                </div>
            </div>
        </div>

        <!-- Actions -->
        <div class="flex items-center justify-end gap-4">
            <a href="{{ route('admin.tenants.show', $tenant) }}"
               class="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
                Cancel
            </a>
            <button type="submit"
                    class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors">
                Save Changes
            </button>
        </div>
    </form>
</div>
@endsection
