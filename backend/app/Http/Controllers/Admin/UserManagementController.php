<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class UserManagementController extends Controller
{
    /**
     * Get all users across all tenants
     */
    public function index(Request $request): JsonResponse
    {
        $query = User::with('tenant');

        // Search filter
        if ($request->has('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'LIKE', "%{$search}%")
                    ->orWhere('email', 'LIKE', "%{$search}%");
            });
        }

        // Tenant filter
        if ($request->has('tenant_id')) {
            $query->where('tenant_id', $request->tenant_id);
        }

        // Role filter
        if ($request->has('role')) {
            $query->where('role', $request->role);
        }

        // Active filter
        if ($request->has('is_active')) {
            $query->where('is_active', $request->is_active === 'true');
        }

        // Sort
        $sortBy = $request->get('sort_by', 'created_at');
        $sortOrder = $request->get('sort_order', 'desc');
        $query->orderBy($sortBy, $sortOrder);

        $perPage = $request->get('per_page', 20);
        $users = $query->paginate($perPage);

        return response()->json($users);
    }

    /**
     * Get single user details
     */
    public function show(string $id): JsonResponse
    {
        $user = User::with(['tenant'])->findOrFail($id);

        // Get user activity logs
        $activityLogs = AuditLog::byUser($user->id)
            ->recent(90)
            ->orderBy('created_at', 'desc')
            ->limit(50)
            ->get();

        return response()->json([
            'user' => $user,
            'activity_logs' => $activityLogs,
        ]);
    }

    /**
     * Update user
     */
    public function update(Request $request, string $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|string|max:255',
            'email' => 'sometimes|email|max:255|unique:users,email,' . $id,
            'phone' => 'nullable|string|max:20',
            'role' => 'sometimes|in:admin,accountant,manager,user,viewer',
            'is_active' => 'sometimes|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $user = User::findOrFail($id);
        $oldData = $user->only(['name', 'email', 'role', 'is_active']);

        $user->update($request->all());

        // Log the change
        AuditLog::log(
            action: 'user.updated',
            entityType: 'User',
            entityId: $user->id,
            changes: [
                'before' => $oldData,
                'after' => $user->only(['name', 'email', 'role', 'is_active']),
            ],
            metadata: ['tenant_id' => $user->tenant_id]
        );

        return response()->json([
            'message' => 'User updated successfully',
            'user' => $user->fresh(),
        ]);
    }

    /**
     * Deactivate user
     */
    public function deactivate(string $id): JsonResponse
    {
        $user = User::findOrFail($id);

        if (!$user->is_active) {
            return response()->json([
                'message' => 'User is already inactive',
            ], 400);
        }

        $user->update(['is_active' => false]);

        // Revoke all tokens
        $user->tokens()->delete();

        // Log the action
        AuditLog::log(
            action: 'user.deactivated',
            entityType: 'User',
            entityId: $user->id,
            metadata: ['tenant_id' => $user->tenant_id]
        );

        return response()->json([
            'message' => 'User deactivated successfully',
            'user' => $user,
        ]);
    }

    /**
     * Activate user
     */
    public function activate(string $id): JsonResponse
    {
        $user = User::findOrFail($id);

        if ($user->is_active) {
            return response()->json([
                'message' => 'User is already active',
            ], 400);
        }

        $user->update(['is_active' => true]);

        // Log the action
        AuditLog::log(
            action: 'user.activated',
            entityType: 'User',
            entityId: $user->id,
            metadata: ['tenant_id' => $user->tenant_id]
        );

        return response()->json([
            'message' => 'User activated successfully',
            'user' => $user,
        ]);
    }

    /**
     * Reset user password
     */
    public function resetPassword(Request $request, string $id): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'password' => 'required|string|min:8',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $user = User::findOrFail($id);

        $user->update([
            'password' => Hash::make($request->password),
        ]);

        // Revoke all existing tokens
        $user->tokens()->delete();

        // Log the action
        AuditLog::log(
            action: 'user.password_reset',
            entityType: 'User',
            entityId: $user->id,
            metadata: ['tenant_id' => $user->tenant_id]
        );

        return response()->json([
            'message' => 'Password reset successfully',
        ]);
    }

    /**
     * Delete user
     */
    public function destroy(string $id): JsonResponse
    {
        $user = User::findOrFail($id);

        // Prevent deleting super admins
        if ($user->isSuperAdmin()) {
            return response()->json([
                'message' => 'Cannot delete super admin users',
            ], 403);
        }

        // Log before deletion
        AuditLog::log(
            action: 'user.deleted',
            entityType: 'User',
            entityId: $user->id,
            changes: ['user_data' => $user->toArray()]
        );

        $user->delete();

        return response()->json([
            'message' => 'User deleted successfully',
        ]);
    }

    /**
     * Force logout user (revoke all tokens)
     */
    public function forceLogout(string $id): JsonResponse
    {
        $user = User::findOrFail($id);

        $user->tokens()->delete();

        // Log the action
        AuditLog::log(
            action: 'user.force_logout',
            entityType: 'User',
            entityId: $user->id,
            metadata: ['tenant_id' => $user->tenant_id]
        );

        return response()->json([
            'message' => 'User logged out from all devices',
        ]);
    }

    /**
     * Impersonate user (for support purposes)
     */
    public function impersonate(string $id): JsonResponse
    {
        $user = User::findOrFail($id);

        // Prevent impersonating super admins
        if ($user->isSuperAdmin()) {
            return response()->json([
                'message' => 'Cannot impersonate super admin users',
            ], 403);
        }

        // Create impersonation token
        $token = $user->createToken('impersonation-token')->plainTextToken;

        // Log the action
        AuditLog::log(
            action: 'user.impersonated',
            entityType: 'User',
            entityId: $user->id,
            metadata: [
                'tenant_id' => $user->tenant_id,
                'impersonated_by' => auth()->id(),
            ]
        );

        return response()->json([
            'message' => 'Impersonation token created',
            'token' => $token,
            'user' => $user,
            'tenant' => $user->tenant,
        ]);
    }
}
