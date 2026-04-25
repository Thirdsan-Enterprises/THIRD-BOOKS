<?php

use Illuminate\Support\Str;

// ── Connectivity / Status ─────────────────────────────────────────────────────

it('returns sync status for a device', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);

    $this->withHeaders($headers)
         ->getJson('/api/sync/status?device_id=device-abc-123')
         ->assertStatus(200)
         ->assertJsonStructure([
             'data' => [
                 'device_id',
                 'last_synced_sequence',
                 'total_events',
                 'unsynced_events',
                 'is_synced',
             ],
         ]);
});

// ── Push (upload events) ──────────────────────────────────────────────────────

it('accepts pushed events and stores them', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);

    $response = $this->withHeaders($headers)->postJson('/api/sync/push', [
        'device_id' => 'device-A',
        'events'    => [
            [
                'id'             => Str::uuid(),
                'aggregate_type' => 'invoice',
                'aggregate_id'   => Str::uuid(),
                'event_type'     => 'invoice.created',
                'event_data'     => ['total' => 150000, 'currency' => 'UGX'],
                'occurred_at'    => now()->toIso8601String(),
            ],
        ],
    ]);

    $response->assertStatus(200)
             ->assertJsonPath('data.uploaded_count', 1)
             ->assertJsonPath('data.conflicts_count', 0);
});

it('rejects push with missing required fields', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);

    $this->withHeaders($headers)->postJson('/api/sync/push', [
        'device_id' => 'device-A',
        'events'    => [
            ['event_type' => 'invoice.created'], // missing aggregate_type, aggregate_id, event_data, occurred_at
        ],
    ])->assertStatus(422);
});

// ── Pull (download events) ────────────────────────────────────────────────────

it('returns empty events when nothing has been pushed', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);

    $this->withHeaders($headers)
         ->getJson('/api/sync/pull?device_id=device-B&after_sequence=0')
         ->assertStatus(200)
         ->assertJsonPath('data.has_more', false);
});

it('device B receives events pushed by device A', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);

    // Device A pushes an event
    $this->withHeaders($headers)->postJson('/api/sync/push', [
        'device_id' => 'device-A',
        'events'    => [[
            'id'             => Str::uuid(),
            'aggregate_type' => 'invoice',
            'aggregate_id'   => Str::uuid(),
            'event_type'     => 'invoice.created',
            'event_data'     => ['total' => 200000],
            'occurred_at'    => now()->toIso8601String(),
        ]],
    ]);

    // Device B pulls — should receive Device A's event
    $response = $this->withHeaders($headers)
         ->getJson('/api/sync/pull?device_id=device-B&after_sequence=0');

    $response->assertStatus(200);
    expect(count($response->json('data.events')))->toBeGreaterThanOrEqual(1);
});

it('device does not receive its own events on pull', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);

    $this->withHeaders($headers)->postJson('/api/sync/push', [
        'device_id' => 'same-device',
        'events'    => [[
            'id'             => Str::uuid(),
            'aggregate_type' => 'invoice',
            'aggregate_id'   => Str::uuid(),
            'event_type'     => 'invoice.created',
            'event_data'     => ['total' => 50000],
            'occurred_at'    => now()->toIso8601String(),
        ]],
    ]);

    // Same device pulls — should get 0 events back
    $response = $this->withHeaders($headers)
         ->getJson('/api/sync/pull?device_id=same-device&after_sequence=0');

    $response->assertStatus(200);
    expect(count($response->json('data.events')))->toBe(0);
});

// ── Full bi-directional sync ──────────────────────────────────────────────────

it('performs a full bi-directional sync', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);

    $response = $this->withHeaders($headers)->postJson('/api/sync', [
        'device_id'   => 'device-X',
        'device_name' => 'Marion Desktop',
        'device_type' => 'desktop',
        'events'      => [[
            'id'             => Str::uuid(),
            'aggregate_type' => 'customer',
            'aggregate_id'   => Str::uuid(),
            'event_type'     => 'customer.created',
            'event_data'     => ['name' => 'John Doe', 'email' => 'john@example.com'],
            'occurred_at'    => now()->toIso8601String(),
        ]],
        'after_sequence' => 0,
    ]);

    $response->assertStatus(200)
             ->assertJsonStructure([
                 'data' => [
                     'pushed' => ['uploaded_count', 'conflicts_count'],
                     'pulled' => ['events', 'last_sequence', 'has_more'],
                 ],
             ]);

    expect($response->json('data.pushed.uploaded_count'))->toBe(1);
});
