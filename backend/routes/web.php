<?php

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

// Tenant registration (for SaaS mode)
Route::post('/tenants/register', [TenantController::class, 'register']);
Route::get('/tenants/{tenant}/verify', [TenantController::class, 'verify']);
