@extends('layouts.admin')

@section('title', $tenant->company_name)
@section('header', 'Tenant Details')

@section('content')
<div class="space-y-6">
    <!-- Back Button -->
    <div>
        <a href="{{ route('admin.tenants.index') }}" class="inline-flex items-center text-sm text-gray-500 hover:text-gray-700">
            <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
            </svg>
            Back to Tenants
        </a>
    </div>

    <!-- Header Card -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div class="flex flex-col md:flex-row md:items-center md:justify-between">
            <div>
                <h2 class="text-2xl font-bold text-gray-900">{{ $tenant->company_name }}</h2>
                <p class="text-gray-500">{{ $tenant->name }}</p>
                <div class="mt-2 flex items-center gap-2">
                    <x-badge :type="$tenant->status === 'active' ? 'success' : ($tenant->status === 'suspended' ? 'danger' : 'warning')">
                        {{ ucfirst($tenant->status) }}
                    </x-badge>
                    <x-badge :type="$tenant->plan === 'enterprise' ? 'info' : ($tenant->plan === 'premium' ? 'success' : 'default')">
                        {{ ucfirst($tenant->plan) }} Plan
                    </x-badge>
                </div>
            </div>
            <div class="mt-4 md:mt-0 flex gap-2">
                <a href="{{ route('admin.tenants.edit', $tenant) }}"
                   class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors">
                    Edit Tenant
                </a>
                @if($tenant->status === 'active')
                    <form method="POST" action="{{ route('admin.tenants.suspend', $tenant) }}">
                        @csrf
                        <button type="submit"
                                onclick="return confirm('Are you sure you want to suspend this tenant?')"
                                class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors">
                            Suspend
                        </button>
                    </form>
                @else
                    <form method="POST" action="{{ route('admin.tenants.activate', $tenant) }}">
                        @csrf
                        <button type="submit" class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors">
                            Activate
                        </button>
                    </form>
                @endif
            </div>
        </div>
    </div>

    <!-- Info Grid -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- Contact Information -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200">
            <div class="px-6 py-4 border-b border-gray-200">
                <h3 class="text-lg font-semibold text-gray-900">Contact Information</h3>
            </div>
            <div class="p-6 space-y-4">
                <div>
                    <label class="text-sm font-medium text-gray-500">Email</label>
                    <p class="mt-1 text-gray-900">{{ $tenant->email }}</p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Phone</label>
                    <p class="mt-1 text-gray-900">{{ $tenant->phone ?? 'Not provided' }}</p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Address</label>
                    <p class="mt-1 text-gray-900">{{ $tenant->address ?? 'Not provided' }}</p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Country</label>
                    <p class="mt-1 text-gray-900">{{ $tenant->country }}</p>
                </div>
            </div>
        </div>

        <!-- Subscription Information -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200">
            <div class="px-6 py-4 border-b border-gray-200">
                <h3 class="text-lg font-semibold text-gray-900">Subscription</h3>
            </div>
            <div class="p-6 space-y-4">
                <div>
                    <label class="text-sm font-medium text-gray-500">Plan</label>
                    <p class="mt-1 text-gray-900 capitalize">{{ $tenant->plan }}</p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Trial Ends</label>
                    <p class="mt-1 text-gray-900">
                        {{ $tenant->trial_ends_at ? $tenant->trial_ends_at->format('M d, Y') : 'N/A' }}
                        @if($tenant->trial_ends_at && $tenant->trial_ends_at->isFuture())
                            <span class="text-sm text-green-600">({{ $tenant->trial_ends_at->diffForHumans() }})</span>
                        @endif
                    </p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Subscription Ends</label>
                    <p class="mt-1 text-gray-900">
                        {{ $tenant->subscription_ends_at ? $tenant->subscription_ends_at->format('M d, Y') : 'N/A' }}
                        @if($tenant->subscription_ends_at && $tenant->subscription_ends_at->isFuture())
                            <span class="text-sm text-green-600">({{ $tenant->subscription_ends_at->diffForHumans() }})</span>
                        @endif
                    </p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Base Currency</label>
                    <p class="mt-1 text-gray-900">{{ $tenant->base_currency }}</p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Fiscal Year Start</label>
                    <p class="mt-1 text-gray-900">{{ $tenant->fiscal_year_start }}</p>
                </div>
            </div>
        </div>
    </div>

    <!-- Users -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200">
        <div class="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
            <h3 class="text-lg font-semibold text-gray-900">Users ({{ $users->count() }})</h3>
        </div>
        <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Name</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Email</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Role</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Joined</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-200">
                    @forelse($users as $user)
                        <tr class="hover:bg-gray-50">
                            <td class="px-6 py-4 whitespace-nowrap font-medium text-gray-900">{{ $user->name }}</td>
                            <td class="px-6 py-4 whitespace-nowrap text-gray-500">{{ $user->email }}</td>
                            <td class="px-6 py-4 whitespace-nowrap">
                                <x-badge>{{ ucfirst($user->role) }}</x-badge>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                                <x-badge :type="$user->is_active ? 'success' : 'danger'">
                                    {{ $user->is_active ? 'Active' : 'Inactive' }}
                                </x-badge>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                {{ $user->created_at->format('M d, Y') }}
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="5" class="px-6 py-8 text-center text-gray-500">No users found</td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
    </div>

    <!-- Metadata -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
            <div>
                <label class="text-gray-500">Tenant ID</label>
                <p class="mt-1 text-gray-900 font-mono text-xs">{{ $tenant->id }}</p>
            </div>
            <div>
                <label class="text-gray-500">Created</label>
                <p class="mt-1 text-gray-900">{{ $tenant->created_at->format('M d, Y H:i') }}</p>
            </div>
            <div>
                <label class="text-gray-500">Last Updated</label>
                <p class="mt-1 text-gray-900">{{ $tenant->updated_at->format('M d, Y H:i') }}</p>
            </div>
            <div>
                <label class="text-gray-500">Database</label>
                <p class="mt-1 text-gray-900 font-mono text-xs">tenant_{{ $tenant->id }}</p>
            </div>
        </div>
    </div>
</div>
@endsection
