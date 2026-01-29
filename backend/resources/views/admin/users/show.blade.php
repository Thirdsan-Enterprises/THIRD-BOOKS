@extends('layouts.admin')

@section('title', $user->name)
@section('header', 'User Details')

@section('content')
<div class="space-y-6">
    <!-- Back Button -->
    <div>
        <a href="{{ route('admin.users.index') }}" class="inline-flex items-center text-sm text-gray-500 hover:text-gray-700">
            <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
            </svg>
            Back to Users
        </a>
    </div>

    <!-- Header Card -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div class="flex flex-col md:flex-row md:items-center md:justify-between">
            <div class="flex items-center">
                <div class="w-16 h-16 rounded-full bg-primary-500 flex items-center justify-center text-white text-2xl font-bold">
                    {{ substr($user->name, 0, 1) }}
                </div>
                <div class="ml-4">
                    <h2 class="text-2xl font-bold text-gray-900">{{ $user->name }}</h2>
                    <p class="text-gray-500">{{ $user->email }}</p>
                    <div class="mt-2 flex items-center gap-2">
                        <x-badge :type="$user->is_active ? 'success' : 'danger'">
                            {{ $user->is_active ? 'Active' : 'Inactive' }}
                        </x-badge>
                        <x-badge :type="$user->role === 'admin' ? 'info' : 'default'">
                            {{ ucfirst($user->role) }}
                        </x-badge>
                    </div>
                </div>
            </div>
            <div class="mt-4 md:mt-0 flex gap-2">
                @if($user->is_active)
                    <form method="POST" action="{{ route('admin.users.deactivate', $user) }}">
                        @csrf
                        <button type="submit"
                                onclick="return confirm('Deactivate this user?')"
                                class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors">
                            Deactivate
                        </button>
                    </form>
                @else
                    <form method="POST" action="{{ route('admin.users.activate', $user) }}">
                        @csrf
                        <button type="submit" class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors">
                            Activate
                        </button>
                    </form>
                @endif
                <form method="POST" action="{{ route('admin.users.reset-password', $user) }}">
                    @csrf
                    <button type="submit"
                            onclick="return confirm('Send password reset email to this user?')"
                            class="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 transition-colors">
                        Reset Password
                    </button>
                </form>
            </div>
        </div>
    </div>

    <!-- Info Grid -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- User Information -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200">
            <div class="px-6 py-4 border-b border-gray-200">
                <h3 class="text-lg font-semibold text-gray-900">User Information</h3>
            </div>
            <div class="p-6 space-y-4">
                <div>
                    <label class="text-sm font-medium text-gray-500">Email</label>
                    <p class="mt-1 text-gray-900">{{ $user->email }}</p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Phone</label>
                    <p class="mt-1 text-gray-900">{{ $user->phone ?? 'Not provided' }}</p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Role</label>
                    <p class="mt-1 text-gray-900 capitalize">{{ $user->role }}</p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Email Verified</label>
                    <p class="mt-1 text-gray-900">
                        {{ $user->email_verified_at ? $user->email_verified_at->format('M d, Y H:i') : 'Not verified' }}
                    </p>
                </div>
            </div>
        </div>

        <!-- Tenant Information -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200">
            <div class="px-6 py-4 border-b border-gray-200">
                <h3 class="text-lg font-semibold text-gray-900">Tenant</h3>
            </div>
            <div class="p-6 space-y-4">
                @if($user->tenant)
                    <div>
                        <label class="text-sm font-medium text-gray-500">Company</label>
                        <p class="mt-1">
                            <a href="{{ route('admin.tenants.show', $user->tenant) }}" class="text-primary-600 hover:text-primary-900">
                                {{ $user->tenant->company_name }}
                            </a>
                        </p>
                    </div>
                    <div>
                        <label class="text-sm font-medium text-gray-500">Plan</label>
                        <p class="mt-1 text-gray-900 capitalize">{{ $user->tenant->plan }}</p>
                    </div>
                    <div>
                        <label class="text-sm font-medium text-gray-500">Tenant Status</label>
                        <p class="mt-1">
                            <x-badge :type="$user->tenant->status === 'active' ? 'success' : 'danger'">
                                {{ ucfirst($user->tenant->status) }}
                            </x-badge>
                        </p>
                    </div>
                @else
                    <p class="text-gray-500">No tenant associated</p>
                @endif
            </div>
        </div>
    </div>

    <!-- Recent Activity -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200">
        <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-semibold text-gray-900">Recent Activity</h3>
        </div>
        <div class="divide-y divide-gray-200">
            @forelse($activities as $activity)
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
                            <p class="text-sm text-gray-900">{{ $activity->description }}</p>
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

    <!-- Metadata -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
            <div>
                <label class="text-gray-500">User ID</label>
                <p class="mt-1 text-gray-900">{{ $user->id }}</p>
            </div>
            <div>
                <label class="text-gray-500">Tenant ID</label>
                <p class="mt-1 text-gray-900 font-mono text-xs">{{ $user->tenant_id }}</p>
            </div>
            <div>
                <label class="text-gray-500">Joined</label>
                <p class="mt-1 text-gray-900">{{ $user->created_at->format('M d, Y H:i') }}</p>
            </div>
            <div>
                <label class="text-gray-500">Last Updated</label>
                <p class="mt-1 text-gray-900">{{ $user->updated_at->format('M d, Y H:i') }}</p>
            </div>
        </div>
    </div>
</div>
@endsection
