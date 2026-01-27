@extends('layouts.admin')

@section('title', 'Settings')
@section('header', 'System Settings')

@section('content')
<div class="space-y-6">
    <!-- System Information -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200">
        <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-semibold text-gray-900">System Information</h3>
        </div>
        <div class="p-6">
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                <div>
                    <label class="text-sm font-medium text-gray-500">Application Name</label>
                    <p class="mt-1 text-gray-900">{{ config('app.name') }}</p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Environment</label>
                    <p class="mt-1">
                        <x-badge :type="config('app.env') === 'production' ? 'success' : 'warning'">
                            {{ ucfirst(config('app.env')) }}
                        </x-badge>
                    </p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Debug Mode</label>
                    <p class="mt-1">
                        <x-badge :type="config('app.debug') ? 'danger' : 'success'">
                            {{ config('app.debug') ? 'Enabled' : 'Disabled' }}
                        </x-badge>
                    </p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">PHP Version</label>
                    <p class="mt-1 text-gray-900">{{ PHP_VERSION }}</p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Laravel Version</label>
                    <p class="mt-1 text-gray-900">{{ app()->version() }}</p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Timezone</label>
                    <p class="mt-1 text-gray-900">{{ config('app.timezone') }}</p>
                </div>
            </div>
        </div>
    </div>

    <!-- Database Information -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200">
        <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-semibold text-gray-900">Database</h3>
        </div>
        <div class="p-6">
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                <div>
                    <label class="text-sm font-medium text-gray-500">Connection</label>
                    <p class="mt-1 text-gray-900">{{ config('database.default') }}</p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Host</label>
                    <p class="mt-1 text-gray-900">{{ config('database.connections.' . config('database.default') . '.host') }}</p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Database</label>
                    <p class="mt-1 text-gray-900">{{ config('database.connections.' . config('database.default') . '.database') }}</p>
                </div>
            </div>
        </div>
    </div>

    <!-- Cache & Queue -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200">
        <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-semibold text-gray-900">Cache & Queue</h3>
        </div>
        <div class="p-6">
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <div>
                    <label class="text-sm font-medium text-gray-500">Cache Driver</label>
                    <p class="mt-1 text-gray-900">{{ config('cache.default') }}</p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Session Driver</label>
                    <p class="mt-1 text-gray-900">{{ config('session.driver') }}</p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Queue Driver</label>
                    <p class="mt-1 text-gray-900">{{ config('queue.default') }}</p>
                </div>
                <div>
                    <label class="text-sm font-medium text-gray-500">Mail Driver</label>
                    <p class="mt-1 text-gray-900">{{ config('mail.default') }}</p>
                </div>
            </div>
        </div>
    </div>

    <!-- Quick Actions -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-200">
        <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-semibold text-gray-900">Quick Actions</h3>
        </div>
        <div class="p-6">
            <div class="flex flex-wrap gap-4">
                <form method="POST" action="{{ route('admin.cache.clear') }}">
                    @csrf
                    <button type="submit" class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors">
                        Clear Cache
                    </button>
                </form>
                <form method="POST" action="{{ route('admin.config.clear') }}">
                    @csrf
                    <button type="submit" class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors">
                        Clear Config Cache
                    </button>
                </form>
            </div>
            <p class="mt-4 text-sm text-gray-500">
                Note: Clearing cache may temporarily slow down the application while caches are rebuilt.
            </p>
        </div>
    </div>
</div>
@endsection
