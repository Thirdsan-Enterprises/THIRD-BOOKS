<?php

use App\Http\Controllers\Admin\Web\AuditLogController;
use App\Http\Controllers\Admin\Web\AuthController;
use App\Http\Controllers\Admin\Web\DashboardController;
use App\Http\Controllers\Admin\Web\SettingsController;
use App\Http\Controllers\Admin\Web\TenantController;
use App\Http\Controllers\Admin\Web\UserController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
*/

Route::get('/', function () {
    return response()->json([
        'name' => 'ThirdBooks API',
        'version' => '1.0.0',
        'documentation' => url('/api/documentation'),
    ]);
});

/*
|--------------------------------------------------------------------------
| Admin Panel Routes (Blade/Server-Rendered)
|--------------------------------------------------------------------------
*/

// Admin Authentication
Route::get('/admin/login', [AuthController::class, 'showLogin'])->name('admin.login');
Route::post('/admin/login', [AuthController::class, 'login'])->name('admin.login.submit');
Route::post('/admin/logout', [AuthController::class, 'logout'])->name('admin.logout');

// Protected Admin Routes
Route::prefix('admin')
    ->middleware(['web', \App\Http\Middleware\SuperAdminMiddleware::class])
    ->group(function () {
        // Dashboard
        Route::get('/', [DashboardController::class, 'index'])->name('admin.dashboard');

        // Tenants
        Route::get('/tenants', [TenantController::class, 'index'])->name('admin.tenants.index');
        Route::get('/tenants/{tenant}', [TenantController::class, 'show'])->name('admin.tenants.show');
        Route::get('/tenants/{tenant}/edit', [TenantController::class, 'edit'])->name('admin.tenants.edit');
        Route::put('/tenants/{tenant}', [TenantController::class, 'update'])->name('admin.tenants.update');
        Route::delete('/tenants/{tenant}', [TenantController::class, 'destroy'])->name('admin.tenants.destroy');
        Route::post('/tenants/{tenant}/suspend', [TenantController::class, 'suspend'])->name('admin.tenants.suspend');
        Route::post('/tenants/{tenant}/activate', [TenantController::class, 'activate'])->name('admin.tenants.activate');

        // Users
        Route::get('/users', [UserController::class, 'index'])->name('admin.users.index');
        Route::get('/users/{user}', [UserController::class, 'show'])->name('admin.users.show');
        Route::post('/users/{user}/deactivate', [UserController::class, 'deactivate'])->name('admin.users.deactivate');
        Route::post('/users/{user}/activate', [UserController::class, 'activate'])->name('admin.users.activate');
        Route::post('/users/{user}/reset-password', [UserController::class, 'resetPassword'])->name('admin.users.reset-password');

        // Audit Logs
        Route::get('/audit-logs', [AuditLogController::class, 'index'])->name('admin.audit-logs.index');

        // Settings
        Route::get('/settings', [SettingsController::class, 'index'])->name('admin.settings');
        Route::post('/settings/cache/clear', [SettingsController::class, 'clearCache'])->name('admin.cache.clear');
        Route::post('/settings/config/clear', [SettingsController::class, 'clearConfig'])->name('admin.config.clear');
    });
