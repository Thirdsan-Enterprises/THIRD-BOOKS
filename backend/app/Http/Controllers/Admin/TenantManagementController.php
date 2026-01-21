<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Tenant\Tenant;
use App\Models\User;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Validator;

class TenantManagementController extends Controller
{
    /**
     * Get all tenants with pagination and filtering
     */
    public function index(Request $request): JsonResponse
    {
        $query = Tenant::query()->with('users');

        // Search filter
        if ($request->has('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'LIKE', "%{$search}%")
                    ->orWhere('email', 'LIKE', "%{$search}%")
                    ->orWhere('company_name', 'LIKE', "%{$search}%");
            });
        }

        // Status filter
        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        // Plan filter
        if ($request->has('plan')) {
            $query->where('plan', $request->plan);
        }

        // Sort
        $sortBy = $request->get('sort_by', 'created_at');
        $sortOrder = $request->get('sort_order', 'desc');
        $query->orderBy($sortBy, $sortOrder);

        $perPage = $request->get('per_page', 20);
        $tenants = $query->paginate($perPage);

        return response()->json($tenants);
    }

    /**
     * Get single tenant details
     */
    public function show(string $id): JsonResponse
    {
        $tenant = Tenant::with(['users', 'domains'])->findOrFail($id);

        // Get tenant statistics
        $stats = $this->getTenantStatistics($tenant);

        return response()->json([
            'tenant' => $tenant,
            'statistics' => $stats,
        ]);
    }

    /**
     * Update tenant
     */
    public function update(Request $request, string $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|string|max:255',
            'company_name' => 'sometimes|string|max:255',
            'email' => 'sometimes|email|max:255',
            'phone' => 'nullable|string|max:20',
            'country' => 'nullable|string|size:2',
            'base_currency' => 'nullable|string|size:3',
            'plan' => 'sometimes|in:trial,starter,professional,enterprise',
            'status' => 'sometimes|in:active,suspended,cancelled',
            'subscription_ends_at' => 'nullable|date',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $tenant = Tenant::findOrFail($id);
        $oldData = $tenant->toArray();

        $tenant->update($request->all());

        // Log the change
        AuditLog::log(
            action: 'tenant.updated',
            entityType: 'Tenant',
            entityId: $tenant->id,
            changes: [
                'before' => $oldData,
                'after' => $tenant->fresh()->toArray(),
            ]
        );

        return response()->json([
            'message' => 'Tenant updated successfully',
            'tenant' => $tenant->fresh(),
        ]);
    }

    /**
     * Suspend tenant
     */
    public function suspend(string $id): JsonResponse
    {
        $tenant = Tenant::findOrFail($id);

        if ($tenant->status === 'suspended') {
            return response()->json([
                'message' => 'Tenant is already suspended',
            ], 400);
        }

        $tenant->update(['status' => 'suspended']);

        // Log the action
        AuditLog::log(
            action: 'tenant.suspended',
            entityType: 'Tenant',
            entityId: $tenant->id,
            changes: ['status' => 'suspended']
        );

        return response()->json([
            'message' => 'Tenant suspended successfully',
            'tenant' => $tenant,
        ]);
    }

    /**
     * Activate tenant
     */
    public function activate(string $id): JsonResponse
    {
        $tenant = Tenant::findOrFail($id);

        if ($tenant->status === 'active') {
            return response()->json([
                'message' => 'Tenant is already active',
            ], 400);
        }

        $tenant->update(['status' => 'active']);

        // Log the action
        AuditLog::log(
            action: 'tenant.activated',
            entityType: 'Tenant',
            entityId: $tenant->id,
            changes: ['status' => 'active']
        );

        return response()->json([
            'message' => 'Tenant activated successfully',
            'tenant' => $tenant,
        ]);
    }

    /**
     * Delete tenant (soft delete)
     */
    public function destroy(string $id): JsonResponse
    {
        $tenant = Tenant::findOrFail($id);

        // Log before deletion
        AuditLog::log(
            action: 'tenant.deleted',
            entityType: 'Tenant',
            entityId: $tenant->id,
            changes: ['tenant_data' => $tenant->toArray()]
        );

        $tenant->delete();

        return response()->json([
            'message' => 'Tenant deleted successfully',
        ]);
    }

    /**
     * Get tenant statistics
     */
    protected function getTenantStatistics(Tenant $tenant): array
    {
        // This would query the tenant's database
        // For now, return placeholder data
        return [
            'users_count' => $tenant->users()->count(),
            'created_at' => $tenant->created_at,
            'last_login' => $tenant->users()->max('updated_at'),
            'storage_used' => 0, // Implement later
            'api_calls_today' => 0, // Implement later
        ];
    }

    /**
     * Upgrade tenant plan
     */
    public function upgradePlan(Request $request, string $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'plan' => 'required|in:starter,professional,enterprise',
            'subscription_ends_at' => 'required|date|after:today',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $tenant = Tenant::findOrFail($id);
        $oldPlan = $tenant->plan;

        $tenant->update([
            'plan' => $request->plan,
            'status' => 'active',
            'subscription_ends_at' => $request->subscription_ends_at,
            'trial_ends_at' => null, // Remove trial
        ]);

        // Log the upgrade
        AuditLog::log(
            action: 'tenant.plan_upgraded',
            entityType: 'Tenant',
            entityId: $tenant->id,
            changes: [
                'old_plan' => $oldPlan,
                'new_plan' => $request->plan,
                'subscription_ends_at' => $request->subscription_ends_at,
            ]
        );

        return response()->json([
            'message' => 'Tenant plan upgraded successfully',
            'tenant' => $tenant->fresh(),
        ]);
    }

    /**
     * Extend subscription
     */
    public function extendSubscription(Request $request, string $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'months' => 'required|integer|min:1|max:36',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $tenant = Tenant::findOrFail($id);
        $currentEnd = $tenant->subscription_ends_at ?? now();
        $newEnd = $currentEnd->addMonths($request->months);

        $tenant->update([
            'subscription_ends_at' => $newEnd,
            'status' => 'active',
        ]);

        // Log the extension
        AuditLog::log(
            action: 'tenant.subscription_extended',
            entityType: 'Tenant',
            entityId: $tenant->id,
            changes: [
                'months_added' => $request->months,
                'new_end_date' => $newEnd->toDateString(),
            ]
        );

        return response()->json([
            'message' => 'Subscription extended successfully',
            'tenant' => $tenant->fresh(),
        ]);
    }
}
