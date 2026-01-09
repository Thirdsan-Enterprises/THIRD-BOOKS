<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Stancl\Tenancy\Tenancy;
use App\Models\Tenant\Tenant;

class InitializeTenancy
{
    protected $tenancy;

    public function __construct(Tenancy $tenancy)
    {
        $this->tenancy = $tenancy;
    }

    /**
     * Handle an incoming request.
     */
    public function handle(Request $request, Closure $next): Response
    {
        // Get tenant ID from request header or authenticated user
        $tenantId = $request->header('X-Tenant-ID') ??
                    $request->user()?->tenant_id;

        if (!$tenantId) {
            return response()->json([
                'error' => 'Tenant not specified',
                'message' => 'Please provide X-Tenant-ID header or authenticate with a tenant user',
            ], 400);
        }

        // Find and initialize tenant
        $tenant = Tenant::find($tenantId);

        if (!$tenant) {
            return response()->json([
                'error' => 'Tenant not found',
                'message' => 'The specified tenant does not exist',
            ], 404);
        }

        if (!$tenant->canAccess()) {
            return response()->json([
                'error' => 'Tenant access denied',
                'message' => 'Your subscription has expired or account is inactive',
            ], 403);
        }

        // Initialize tenancy
        $this->tenancy->initialize($tenant);

        $response = $next($request);

        // End tenancy after request
        $this->tenancy->end();

        return $response;
    }
}
