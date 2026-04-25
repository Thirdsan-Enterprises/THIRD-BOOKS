<?php

use Illuminate\Support\Str;

// This test suite directly reproduces the reported bug:
// "client enters data on device A but device B cannot see it".

it('data entered by device A is visible to device B after sync', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);

    // ── Device A: push a customer record ──────────────────────────────────────
    $txId = Str::uuid()->toString();
    $this->withHeaders($headers)->postJson('/api/client-data/bank-transactions', [
        'records' => [[
            'id'          => $txId,
            'date'        => now()->toDateString(),
            'amount'      => 250000,
            'description' => 'Revenue from outlet',
            'type'        => 'credit',
        ]],
    ])->assertStatus(200);

    // ── Device B: pull — must see Device A's data ─────────────────────────────
    $pull = $this->withHeaders($headers)
                 ->getJson('/api/client-data/bank-transactions');

    $ids = collect($pull->json('data'))->pluck('id')->all();
    expect($ids)->toContain($txId);
});

it('invoices list returns all records not just first 20', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);

    // Create 25 customers directly in DB to simulate a heavy dataset
    for ($i = 1; $i <= 25; $i++) {
        \App\Models\Sales\Customer::create([
            'company_id' => $ctx['company']->id,
            'name'       => "Customer $i",
            'email'      => "customer$i@test.com",
        ]);
    }

    // Pull with per_page=10000 — must get all 25, not just 20
    $response = $this->withHeaders($headers)
                     ->getJson('/api/customers?per_page=10000');

    $response->assertStatus(200);
    expect(count($response->json('data')))->toBeGreaterThanOrEqual(25);
});

it('sync status shows unsynced events after a push from another device', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);

    // Device A pushes events
    $this->withHeaders($headers)->postJson('/api/sync/push', [
        'device_id' => 'device-A',
        'events'    => [
            [
                'id'             => Str::uuid(),
                'aggregate_type' => 'bill',
                'aggregate_id'   => Str::uuid(),
                'event_type'     => 'bill.created',
                'event_data'     => ['total' => 80000, 'vendor' => 'Supplier X'],
                'occurred_at'    => now()->toIso8601String(),
            ],
        ],
    ])->assertStatus(200);

    // Device B checks sync status — should show unsynced events
    $status = $this->withHeaders($headers)
                   ->getJson('/api/sync/status?device_id=device-B');

    $status->assertStatus(200);
    expect($status->json('data.unsynced_events'))->toBeGreaterThan(0);
    expect($status->json('data.is_synced'))->toBeFalse();
});
