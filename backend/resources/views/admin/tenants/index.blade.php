@extends('layouts.admin')

@section('title', 'Tenants')
@section('header', 'Tenant Management')

@section('content')
<div class="space-y-6">
    <!-- Header Actions -->
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
            <p class="text-gray-500">Manage all tenant organizations</p>
        </div>
    </div>

    <!-- Filters -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-4">
        <form method="GET" action="{{ route('admin.tenants.index') }}" class="flex flex-col sm:flex-row gap-4">
            <div class="flex-1">
                <input
                    type="text"
                    name="search"
                    value="{{ request('search') }}"
                    placeholder="Search by name, email, or company..."
                    class="w-full rounded-lg border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
                >
            </div>
            <div>
                <select name="status" class="rounded-lg border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500">
                    <option value="">All Status</option>
                    <option value="active" {{ request('status') === 'active' ? 'selected' : '' }}>Active</option>
                    <option value="suspended" {{ request('status') === 'suspended' ? 'selected' : '' }}>Suspended</option>
                    <option value="cancelled" {{ request('status') === 'cancelled' ? 'selected' : '' }}>Cancelled</option>
                </select>
            </div>
            <div>
                <select name="plan" class="rounded-lg border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500">
                    <option value="">All Plans</option>
                    <option value="trial" {{ request('plan') === 'trial' ? 'selected' : '' }}>Trial</option>
                    <option value="basic" {{ request('plan') === 'basic' ? 'selected' : '' }}>Basic</option>
                    <option value="premium" {{ request('plan') === 'premium' ? 'selected' : '' }}>Premium</option>
                    <option value="enterprise" {{ request('plan') === 'enterprise' ? 'selected' : '' }}>Enterprise</option>
                </select>
            </div>
            <div class="flex gap-2">
                <button type="submit" class="px-4 py-2 bg-primary-600 text-white rounded-lg hover:bg-primary-700 transition-colors">
                    Filter
                </button>
                @if(request()->hasAny(['search', 'status', 'plan']))
                    <a href="{{ route('admin.tenants.index') }}" class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors">
                        Clear
                    </a>
                @endif
            </div>
        </form>
    </div>

    <!-- Tenants Table -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
                <thead class="bg-gray-50">
                    <tr>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Company
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Contact
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Plan
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Status
                        </th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Created
                        </th>
                        <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                            Actions
                        </th>
                    </tr>
                </thead>
                <tbody class="bg-white divide-y divide-gray-200">
                    @forelse($tenants as $tenant)
                        <tr class="hover:bg-gray-50">
                            <td class="px-6 py-4 whitespace-nowrap">
                                <div>
                                    <p class="font-medium text-gray-900">{{ $tenant->company_name }}</p>
                                    <p class="text-sm text-gray-500">{{ $tenant->name }}</p>
                                </div>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                                <div>
                                    <p class="text-sm text-gray-900">{{ $tenant->email }}</p>
                                    <p class="text-sm text-gray-500">{{ $tenant->phone ?? 'No phone' }}</p>
                                </div>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                                <x-badge :type="$tenant->plan === 'enterprise' ? 'info' : ($tenant->plan === 'premium' ? 'success' : 'default')">
                                    {{ ucfirst($tenant->plan) }}
                                </x-badge>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap">
                                <x-badge :type="$tenant->status === 'active' ? 'success' : ($tenant->status === 'suspended' ? 'danger' : 'warning')">
                                    {{ ucfirst($tenant->status) }}
                                </x-badge>
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                                {{ $tenant->created_at->format('M d, Y') }}
                            </td>
                            <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                                <div class="flex items-center justify-end gap-2">
                                    <a href="{{ route('admin.tenants.show', $tenant) }}"
                                       class="text-primary-600 hover:text-primary-900">
                                        View
                                    </a>
                                    <a href="{{ route('admin.tenants.edit', $tenant) }}"
                                       class="text-gray-600 hover:text-gray-900">
                                        Edit
                                    </a>
                                    @if($tenant->status === 'active')
                                        <form method="POST" action="{{ route('admin.tenants.suspend', $tenant) }}" class="inline">
                                            @csrf
                                            <button type="submit"
                                                    onclick="return confirm('Are you sure you want to suspend this tenant?')"
                                                    class="text-red-600 hover:text-red-900">
                                                Suspend
                                            </button>
                                        </form>
                                    @else
                                        <form method="POST" action="{{ route('admin.tenants.activate', $tenant) }}" class="inline">
                                            @csrf
                                            <button type="submit" class="text-green-600 hover:text-green-900">
                                                Activate
                                            </button>
                                        </form>
                                    @endif
                                </div>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="px-6 py-12 text-center text-gray-500">
                                No tenants found
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>

        @if($tenants->hasPages())
            <div class="px-6 py-4 border-t border-gray-200">
                {{ $tenants->links() }}
            </div>
        @endif
    </div>
</div>
@endsection
