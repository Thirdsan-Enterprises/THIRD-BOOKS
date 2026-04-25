<?php

use App\Models\User;
use Illuminate\Support\Facades\Hash;

// ── Registration ──────────────────────────────────────────────────────────────

it('registers a new tenant and returns token with tenant_id', function () {
    $response = $this->postJson('/api/auth/register', [
        'company_name'          => 'Kandan Books',
        'name'                  => 'Marion Kandan',
        'email'                 => 'marion@kandan.com',
        'password'              => 'StrongPass@2026',
        'password_confirmation' => 'StrongPass@2026',
        'country'               => 'UG',
        'base_currency'         => 'UGX',
    ]);

    $response->assertStatus(201)
             ->assertJsonStructure([
                 'token',
                 'user'    => ['id', 'email', 'tenant_id', 'role'],
                 'tenant'  => ['id', 'company_name', 'plan', 'status', 'trial_ends_at'],
                 'company' => ['id', 'name', 'base_currency'],
             ]);

    // tenant_id must be set on the user
    expect($response->json('user.tenant_id'))->not->toBeNull();

    // Tenant should be on trial with 30-day window
    expect($response->json('tenant.plan'))->toBe('trial');
    expect($response->json('tenant.status'))->toBe('active');
});

it('rejects registration with duplicate email', function () {
    $this->createTenantWithUser(['user' => ['email' => 'dup@test.com']]);

    $this->postJson('/api/auth/register', [
        'company_name'          => 'Another Co',
        'name'                  => 'Jane',
        'email'                 => 'dup@test.com',
        'password'              => 'Password@123',
        'password_confirmation' => 'Password@123',
    ])->assertStatus(422);
});

it('rejects registration with weak password', function () {
    $this->postJson('/api/auth/register', [
        'company_name'          => 'Test Co',
        'name'                  => 'Test',
        'email'                 => 'test@test.com',
        'password'              => '123',
        'password_confirmation' => '123',
    ])->assertStatus(422);
});

// ── Login ─────────────────────────────────────────────────────────────────────

it('logs in with correct credentials and returns tenant_id', function () {
    $ctx = $this->createTenantWithUser([
        'user' => ['email' => 'login@test.com'],
    ]);

    $response = $this->postJson('/api/auth/login', [
        'email'    => 'login@test.com',
        'password' => 'password123',
    ]);

    $response->assertStatus(200)
             ->assertJsonStructure([
                 'token',
                 'user'   => ['id', 'email', 'tenant_id'],
                 'tenant' => ['id', 'status'],
             ]);

    expect($response->json('user.tenant_id'))->toBe($ctx['tenant']->id);
});

it('rejects login with wrong password', function () {
    $this->createTenantWithUser(['user' => ['email' => 'wrong@test.com']]);

    $this->postJson('/api/auth/login', [
        'email'    => 'wrong@test.com',
        'password' => 'wrongpassword',
    ])->assertStatus(401);
});

it('rejects login for suspended tenant', function () {
    $ctx = $this->createTenantWithUser([
        'tenant' => ['status' => 'suspended'],
        'user'   => ['email' => 'suspended@test.com'],
    ]);

    $this->postJson('/api/auth/login', [
        'email'    => 'suspended@test.com',
        'password' => 'password123',
    ])->assertStatus(403);
});

it('rejects login for expired trial', function () {
    $ctx = $this->createTenantWithUser([
        'tenant' => ['trial_ends_at' => now()->subDay(), 'plan' => 'trial'],
        'user'   => ['email' => 'expired@test.com'],
    ]);

    $this->postJson('/api/auth/login', [
        'email'    => 'expired@test.com',
        'password' => 'password123',
    ])->assertStatus(403);
});

// ── Logout ────────────────────────────────────────────────────────────────────

it('logs out and invalidates the token', function () {
    $ctx = $this->createTenantWithUser();

    $this->withHeader('Authorization', "Bearer {$ctx['token']}")
         ->postJson('/api/auth/logout')
         ->assertStatus(200);

    // Token should now be invalid
    $this->withHeader('Authorization', "Bearer {$ctx['token']}")
         ->getJson('/api/auth/user')
         ->assertStatus(401);
});

// ── Get current user ──────────────────────────────────────────────────────────

it('returns authenticated user with tenant info', function () {
    $ctx = $this->createTenantWithUser();

    $this->withHeader('Authorization', "Bearer {$ctx['token']}")
         ->getJson('/api/auth/user')
         ->assertStatus(200)
         ->assertJsonStructure([
             'user'   => ['id', 'email', 'role', 'tenant_id'],
             'tenant' => ['id', 'status', 'plan'],
         ]);
});
