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

it('rejects requests without tenant header on tenant routes', function () {
    $ctx = $this->createTenantWithUser();

    // Authenticated but no X-Tenant-ID header — middleware should reject
    $this->withHeader('Authorization', "Bearer {$ctx['token']}")
         ->withHeader('Accept', 'application/json')
         ->getJson('/api/invoices')
         ->assertStatus(400)
         ->assertJsonFragment(['error' => 'Tenant not specified']);
});
