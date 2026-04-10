<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

/**
 * Tenant-scoped user management.
 * All operations are restricted to users within the authenticated user's tenant.
 * Only admins can create / update / delete users.
 */
class UserController extends Controller
{
    // ── List ─────────────────────────────────────────────────────────────────

    public function index(Request $request)
    {
        $tenantId = auth()->user()->tenant_id;

        $users = User::where('tenant_id', $tenantId)
            ->orderBy('name')
            ->get(['id', 'name', 'email', 'role', 'is_active', 'created_at']);

        return response()->json(['users' => $users]);
    }

    // ── Create ────────────────────────────────────────────────────────────────

    public function store(Request $request)
    {
        $this->requireAdmin();

        $validated = $request->validate([
            'name'     => 'required|string|max:255',
            'email'    => 'required|email|unique:users,email',
            'password' => 'required|string|min:8',
            'role'     => ['required', Rule::in([
                User::ROLE_ADMIN,
                User::ROLE_ACCOUNTANT,
                User::ROLE_MANAGER,
                User::ROLE_USER,
                User::ROLE_VIEWER,
            ])],
        ]);

        $user = User::create([
            'name'      => $validated['name'],
            'email'     => $validated['email'],
            'password'  => Hash::make($validated['password']),
            'role'      => $validated['role'],
            'tenant_id' => auth()->user()->tenant_id,
            'is_active' => true,
        ]);

        return response()->json([
            'user'    => $user->only(['id', 'name', 'email', 'role', 'is_active', 'created_at']),
            'message' => 'User created successfully',
        ], 201);
    }

    // ── Update ────────────────────────────────────────────────────────────────

    public function update(Request $request, User $user)
    {
        $this->requireAdmin();
        $this->requireSameTenant($user);

        $validated = $request->validate([
            'name'      => 'sometimes|string|max:255',
            'role'      => ['sometimes', Rule::in([
                User::ROLE_ADMIN,
                User::ROLE_ACCOUNTANT,
                User::ROLE_MANAGER,
                User::ROLE_USER,
                User::ROLE_VIEWER,
            ])],
            'is_active' => 'sometimes|boolean',
        ]);

        // Prevent downgrading the last admin
        if (isset($validated['role']) && $validated['role'] !== User::ROLE_ADMIN) {
            $adminCount = User::where('tenant_id', auth()->user()->tenant_id)
                ->where('role', User::ROLE_ADMIN)
                ->where('id', '!=', $user->id)
                ->count();
            if ($adminCount === 0 && $user->role === User::ROLE_ADMIN) {
                return response()->json([
                    'message' => 'Cannot change role: this is the only admin in the tenant.',
                ], 422);
            }
        }

        $user->update($validated);

        return response()->json([
            'user'    => $user->fresh()->only(['id', 'name', 'email', 'role', 'is_active', 'created_at']),
            'message' => 'User updated',
        ]);
    }

    // ── Delete ────────────────────────────────────────────────────────────────

    public function destroy(User $user)
    {
        $this->requireAdmin();
        $this->requireSameTenant($user);

        if ($user->id === auth()->id()) {
            return response()->json(['message' => 'You cannot delete your own account.'], 422);
        }

        // Revoke all tokens first
        $user->tokens()->delete();
        $user->delete();

        return response()->json(['message' => 'User removed from tenant']);
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private function requireAdmin(): void
    {
        if (!auth()->user()->isAdmin() && !auth()->user()->isSuperAdmin()) {
            abort(403, 'Only admins can manage users.');
        }
    }

    private function requireSameTenant(User $target): void
    {
        if ($target->tenant_id !== auth()->user()->tenant_id) {
            abort(403, 'User does not belong to your tenant.');
        }
    }
}
