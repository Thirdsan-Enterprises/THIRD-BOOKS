<?php

// Tests that the server is reachable and responding correctly.

it('returns ok on health check', function () {
    $response = $this->getJson('/api/health');

    $response->assertStatus(200)
             ->assertJsonStructure(['status', 'timestamp'])
             ->assertJson(['status' => 'ok']);
});

it('rejects unauthenticated requests to protected routes', function () {
    $this->getJson('/api/accounts')->assertStatus(401);
    $this->getJson('/api/invoices')->assertStatus(401);
    $this->getJson('/api/customers')->assertStatus(401);
});

it('tenant user can access routes without explicit X-Tenant-ID header', function () {
    $ctx = $this->createTenantWithUser();

    // The middleware falls back to $request->user()->tenant_id — no header required
    $this->withHeader('Authorization', "Bearer {$ctx['token']}")
         ->withHeader('Accept', 'application/json')
         ->getJson('/api/invoices')
         ->assertStatus(200);
});

it('rejects tenant routes when user has no tenant (superadmin without header)', function () {
    $superAdmin = \App\Models\User::create([
        'name'              => 'Super Admin',
        'email'             => 'super@test.com',
        'password'          => \Illuminate\Support\Facades\Hash::make('password123'),
        'role'              => \App\Models\User::ROLE_SUPER_ADMIN,
        'is_active'         => true,
        'email_verified_at' => now(),
    ]);
    $token = $superAdmin->createToken('test')->plainTextToken;

    // Superadmin has no tenant_id and sends no X-Tenant-ID — middleware must reject
    $this->withHeader('Authorization', "Bearer $token")
         ->withHeader('Accept', 'application/json')
         ->getJson('/api/invoices')
         ->assertStatus(400)
         ->assertJsonFragment(['error' => 'Tenant not specified']);
});
