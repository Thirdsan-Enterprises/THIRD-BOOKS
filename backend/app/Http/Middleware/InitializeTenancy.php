<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Stancl\Tenancy\Tenancy;
use App\Models\Tenant\Tenant;
use App\Models\Company;

class InitializeTenancy
{
    protected $tenancy;

    public function __construct(Tenancy $tenancy)
    {
        $this->tenancy = $tenancy;
    }

    /**
     * Handle an incoming request.
     *
     * This middleware:
     * 1. Identifies the tenant from header or authenticated user
     * 2. Validates tenant access (subscription status)
     * 3. Initializes tenant context for data isolation
     * 4. Sets the current company context
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
                'tenant_status' => $tenant->status,
                'trial_ends_at' => $tenant->trial_ends_at?->toIso8601String(),
                'subscription_ends_at' => $tenant->subscription_ends_at?->toIso8601String(),
            ], 403);
        }

        // Initialize tenancy
        $this->tenancy->initialize($tenant);

        // Bind tenant ID to the container for global access
        app()->instance('current_tenant_id', $tenantId);
        app()->instance('current_tenant', $tenant);

        // Get company ID from header or use default company for tenant
        $companyId = $request->header('X-Company-ID');

        if ($companyId) {
            // Verify company belongs to tenant
            $company = Company::withoutGlobalScope('tenant')
                ->where('id', $companyId)
                ->where('tenant_id', $tenantId)
                ->first();

            if (!$company) {
                return response()->json([
                    'error' => 'Company not found',
                    'message' => 'The specified company does not exist or does not belong to your organization',
                ], 404);
            }
        } else {
            // Get default (first) company for tenant
            $company = Company::withoutGlobalScope('tenant')
                ->where('tenant_id', $tenantId)
                ->first();
        }

        if ($company) {
            app()->instance('current_company_id', $company->id);
            app()->instance('current_company', $company);
        }

        $response = $next($request);

        // End tenancy after request
        $this->tenancy->end();

        return $response;
    }
}
