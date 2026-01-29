@extends('layouts.admin')

@section('title', 'Dashboard')
@section('header', 'Dashboard')

@section('content')
<div class="space-y-6">
    <!-- Stats Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <x-stat-card
            title="Total Tenants"
            :value="$stats['total_tenants']"
            :change="'+' . $stats['new_tenants_this_month'] . ' this month'"
            changeType="positive"
            :href="route('admin.tenants.index')"
        >
            <x-slot:icon>
                <svg class="w-6 h-6 text-primary-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/>
                </svg>
            </x-slot:icon>
        </x-stat-card>

        <x-stat-card
            title="Active Users"
            :value="$stats['active_users']"
            :change="$stats['total_users'] . ' total'"
            changeType="neutral"
            :href="route('admin.users.index')"
        >
            <x-slot:icon>
                <svg class="w-6 h-6 text-primary-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"/>
                </svg>
            </x-slot:icon>
        </x-stat-card>

        <x-stat-card
            title="Trial Tenants"
            :value="$stats['trial_tenants']"
            change="On free trial"
            changeType="neutral"
        >
            <x-slot:icon>
                <svg class="w-6 h-6 text-primary-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
            </x-slot:icon>
        </x-stat-card>

        <x-stat-card
            title="Suspended"
            :value="$stats['suspended_tenants']"
            change="Require attention"
            changeType="{{ $stats['suspended_tenants'] > 0 ? 'negative' : 'neutral' }}"
        >
            <x-slot:icon>
                <svg class="w-6 h-6 text-primary-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
                </svg>
            </x-slot:icon>
        </x-stat-card>
    </div>

    <!-- Two Column Layout -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- Recent Tenants -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200">
            <div class="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
                <h2 class="text-lg font-semibold text-gray-900">Recent Tenants</h2>
                <a href="{{ route('admin.tenants.index') }}" class="text-sm text-primary-600 hover:text-primary-700">View all</a>
            </div>
            <div class="divide-y divide-gray-200">
                @forelse($recentTenants as $tenant)
                    <div class="px-6 py-4 flex items-center justify-between hover:bg-gray-50">
                        <div>
                            <p class="font-medium text-gray-900">{{ $tenant->company_name }}</p>
                            <p class="text-sm text-gray-500">{{ $tenant->email }}</p>
                        </div>
                        <div class="text-right">
                            <x-badge :type="$tenant->status === 'active' ? 'success' : ($tenant->status === 'suspended' ? 'danger' : 'warning')">
                                {{ ucfirst($tenant->status) }}
                            </x-badge>
                            <p class="text-xs text-gray-400 mt-1">{{ $tenant->created_at->diffForHumans() }}</p>
                        </div>
                    </div>
                @empty
                    <div class="px-6 py-8 text-center text-gray-500">
                        No tenants yet
                    </div>
                @endforelse
            </div>
        </div>

        <!-- Recent Activity -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200">
            <div class="px-6 py-4 border-b border-gray-200 flex items-center justify-between">
                <h2 class="text-lg font-semibold text-gray-900">Recent Activity</h2>
                <a href="{{ route('admin.audit-logs.index') }}" class="text-sm text-primary-600 hover:text-primary-700">View all</a>
            </div>
            <div class="divide-y divide-gray-200">
                @forelse($recentActivity as $activity)
                    <div class="px-6 py-4 hover:bg-gray-50">
                        <div class="flex items-start">
                            <div class="flex-shrink-0">
                                <div class="w-8 h-8 rounded-full bg-gray-100 flex items-center justify-center">
                                    <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                                    </svg>
                                </div>
                            </div>
                            <div class="ml-3 flex-1">
                                <p class="text-sm text-gray-900">
                                    <span class="font-medium">{{ $activity->causer?->name ?? 'System' }}</span>
                                    {{ $activity->description }}
                                </p>
                                <p class="text-xs text-gray-500 mt-1">{{ $activity->created_at->diffForHumans() }}</p>
                            </div>
                        </div>
                    </div>
                @empty
                    <div class="px-6 py-8 text-center text-gray-500">
                        No recent activity
                    </div>
                @endforelse
            </div>
        </div>
    </div>

    <!-- Plan Distribution -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200">
        <div class="px-6 py-4 border-b border-gray-200">
            <h2 class="text-lg font-semibold text-gray-900">Subscription Plans</h2>
        </div>
        <div class="p-6">
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                @foreach($planDistribution as $plan => $count)
                    <div class="text-center p-4 bg-gray-50 rounded-lg">
                        <p class="text-2xl font-bold text-gray-900">{{ $count }}</p>
                        <p class="text-sm text-gray-500 capitalize">{{ $plan }}</p>
                    </div>
                @endforeach
            </div>
        </div>
    </div>
</div>
@endsection
