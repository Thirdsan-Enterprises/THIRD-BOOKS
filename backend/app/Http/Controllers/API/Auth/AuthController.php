<?php

namespace App\Http\Controllers\API\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Tenant\Tenant;
use App\Services\TenantService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    protected TenantService $tenantService;

    public function __construct(TenantService $tenantService)
    {
        $this->tenantService = $tenantService;
    }

    /**
     * Register a new user and tenant
     *
     * This endpoint provisions a complete tenant setup including:
     * - Tenant record with subscription
     * - Primary domain
     * - Admin user
     * - Default company
     * - Default chart of accounts
     * - Default currencies
     */
    public function register(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'company_name' => 'required|string|max:255',
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:tenants,email|unique:users,email',
            'password' => 'required|string|min:8|confirmed',
            'phone' => 'nullable|string|max:20',
            'country' => 'nullable|string|size:2',
            'base_currency' => 'nullable|string|size:3',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            // Use TenantService for complete tenant provisioning
            $result = $this->tenantService->provisionTenant([
                'company_name' => $request->company_name,
                'name' => $request->name,
                'email' => $request->email,
                'password' => $request->password,
                'phone' => $request->phone,
                'country' => $request->country,
                'base_currency' => $request->base_currency,
            ]);

            $tenant = $result['tenant'];
            $user = $result['user'];
            $company = $result['company'];
            $domain = $result['domain'];

            // Create authentication token
            $token = $user->createToken('auth-token')->plainTextToken;

            return response()->json([
                'message' => 'Registration successful',
                'token' => $token,
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'role' => $user->role,
                    'tenant_id' => $user->tenant_id,
                ],
                'tenant' => [
                    'id' => $tenant->id,
                    'name' => $tenant->name,
                    'company_name' => $tenant->company_name,
                    'domain' => $domain->domain,
                    'plan' => $tenant->plan,
                    'status' => $tenant->status,
                    'trial_ends_at' => $tenant->trial_ends_at,
                ],
                'company' => [
                    'id' => $company->id,
                    'name' => $company->name,
                    'base_currency' => $company->base_currency,
                ],
            ], 201);

        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Registration failed',
                'error' => config('app.debug') ? $e->getMessage() : 'An error occurred during registration',
            ], 500);
        }
    }

    /**
     * Login user
     *
     * Authenticates a user and returns their tenant and company information.
     * This enables multi-tenant login where users can access their organization's data.
     */
    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|email',
            'password' => 'required',
            'device_name' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json([
                'message' => 'Invalid credentials',
            ], 401);
        }

        if (!$user->is_active) {
            return response()->json([
                'message' => 'Account is inactive',
            ], 403);
        }

        // Superadmin has no tenant — skip tenant access check
        $tenant = $user->tenant;
        if (!$user->isSuperAdmin()) {
            if (!$tenant || !$tenant->canAccess()) {
                return response()->json([
                    'message' => 'Your subscription has expired or account is suspended',
                    'tenant_status' => $tenant?->status,
                    'trial_ends_at' => $tenant?->trial_ends_at,
                    'subscription_ends_at' => $tenant?->subscription_ends_at,
                ], 403);
            }
        }

        // Create token
        $deviceName = $request->device_name ?? $request->userAgent() ?? 'unknown';
        $token = $user->createToken($deviceName)->plainTextToken;

        // Get user's default company (first company in the tenant)
        $company = $user->tenant_id
            ? \App\Models\Company::where('tenant_id', $user->tenant_id)->first()
            : null;

        return response()->json([
            'message' => 'Login successful',
            'token' => $token,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'role' => $user->role,
                'tenant_id' => $user->tenant_id,
            ],
            'tenant' => $tenant ? [
                'id' => $tenant->id,
                'name' => $tenant->name,
                'company_name' => $tenant->company_name,
                'plan' => $tenant->plan,
                'status' => $tenant->status,
                'trial_ends_at' => $tenant->trial_ends_at,
                'subscription_ends_at' => $tenant->subscription_ends_at,
            ] : null,
            'company' => $company ? [
                'id' => $company->id,
                'name' => $company->name,
                'base_currency' => $company->base_currency,
                'fiscal_year_start' => $company->fiscal_year_start,
            ] : null,
        ]);
    }

    /**
     * Logout user
     */
    public function logout(Request $request)
    {
        // Revoke current token
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'message' => 'Logged out successfully',
        ]);
    }

    /**
     * Get authenticated user
     */
    public function user(Request $request)
    {
        $user = $request->user();
        $tenant = $user->tenant;

        return response()->json([
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'role' => $user->role,
                'is_active' => $user->is_active,
                'email_verified_at' => $user->email_verified_at,
                'tenant_id' => $user->tenant_id,
            ],
            'tenant' => $tenant ? [
                'id' => $tenant->id,
                'name' => $tenant->name,
                'company_name' => $tenant->company_name,
                'plan' => $tenant->plan,
                'status' => $tenant->status,
                'trial_ends_at' => $tenant->trial_ends_at,
                'subscription_ends_at' => $tenant->subscription_ends_at,
            ] : null,
        ]);
    }

    /**
     * Request password reset
     */
    public function forgotPassword(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|email',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $status = Password::sendResetLink(
            $request->only('email')
        );

        if ($status === Password::RESET_LINK_SENT) {
            return response()->json([
                'message' => 'Password reset link sent to your email',
            ]);
        }

        return response()->json([
            'message' => 'Unable to send password reset link',
        ], 400);
    }

    /**
     * Reset password
     */
    public function resetPassword(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'token' => 'required',
            'email' => 'required|email',
            'password' => 'required|min:8|confirmed',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $status = Password::reset(
            $request->only('email', 'password', 'password_confirmation', 'token'),
            function ($user, $password) {
                $user->password = Hash::make($password);
                $user->save();
            }
        );

        if ($status === Password::PASSWORD_RESET) {
            return response()->json([
                'message' => 'Password reset successful',
            ]);
        }

        return response()->json([
            'message' => 'Password reset failed',
            'error' => __($status),
        ], 400);
    }
}
