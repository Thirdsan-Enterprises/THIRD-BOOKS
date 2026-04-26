<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Admin\TenantManagementController;
use App\Http\Controllers\Admin\UserManagementController;
use App\Http\Controllers\Admin\AnalyticsController;
use App\Http\Controllers\Admin\AuditLogController;

/*
|--------------------------------------------------------------------------
| Admin API Routes
|--------------------------------------------------------------------------
|
| These routes require super admin authentication
|
*/

Route::middleware(['auth:sanctum', 'super_admin'])->prefix('admin')->name('api.admin.')->group(function () {

    // Analytics & Dashboard
    Route::get('/analytics/dashboard', [AnalyticsController::class, 'dashboard'])->name('analytics.dashboard');
    Route::get('/analytics/system-health', [AnalyticsController::class, 'systemHealth'])->name('analytics.health');
    Route::get('/analytics/tenant-timeline/{tenantId}', [AnalyticsController::class, 'tenantTimeline'])->name('analytics.tenant_timeline');
    Route::get('/analytics/export', [AnalyticsController::class, 'export'])->name('analytics.export');

    // Tenant Management
    Route::apiResource('tenants', TenantManagementController::class)->except(['store']);
    Route::post('/tenants/{id}/suspend', [TenantManagementController::class, 'suspend'])->name('tenants.suspend');
    Route::post('/tenants/{id}/activate', [TenantManagementController::class, 'activate'])->name('tenants.activate');
    Route::post('/tenants/{id}/upgrade-plan', [TenantManagementController::class, 'upgradePlan'])->name('tenants.upgrade_plan');
    Route::post('/tenants/{id}/extend-subscription', [TenantManagementController::class, 'extendSubscription'])->name('tenants.extend_subscription');

    // User Management
    Route::apiResource('users', UserManagementController::class)->except(['store']);
    Route::post('/users/{id}/deactivate', [UserManagementController::class, 'deactivate'])->name('users.deactivate');
    Route::post('/users/{id}/activate', [UserManagementController::class, 'activate'])->name('users.activate');
    Route::post('/users/{id}/reset-password', [UserManagementController::class, 'resetPassword'])->name('users.reset_password');
    Route::post('/users/{id}/force-logout', [UserManagementController::class, 'forceLogout'])->name('users.force_logout');
    Route::post('/users/{id}/impersonate', [UserManagementController::class, 'impersonate'])->name('users.impersonate');

    // Audit Logs
    Route::get('/audit-logs', [AuditLogController::class, 'index'])->name('audit_logs.index');
    Route::get('/audit-logs/{id}', [AuditLogController::class, 'show'])->name('audit_logs.show');
    Route::get('/audit-logs/statistics', [AuditLogController::class, 'statistics'])->name('audit_logs.statistics');
    Route::get('/audit-logs/timeline', [AuditLogController::class, 'timeline'])->name('audit_logs.timeline');
    Route::get('/audit-logs/export', [AuditLogController::class, 'export'])->name('audit_logs.export');
});
