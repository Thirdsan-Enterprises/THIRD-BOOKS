<?php

// Tests the blob-store sync endpoint used for bank transactions,
// asset drafts, outlet revenues, etc.

$allowedTypes = [
    'bank-transactions',
    'asset-drafts',
    'depreciation-schedules',
    'bank-statements',
    'outlet-revenues',
    'outlet-expenditures',
    'outlet-settlements',
    'commission-payments',
];

// ── Pull (GET) ────────────────────────────────────────────────────────────────

it('returns empty array when no client data exists', function () use ($allowedTypes) {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);

    foreach ($allowedTypes as $type) {
        $this->withHeaders($headers)
             ->getJson("/api/client-data/$type")
             ->assertStatus(200)
             ->assertJsonStructure(['data'])
             ->assertJsonCount(0, 'data');
    }
});

it('rejects unknown entity types', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);

    $this->withHeaders($headers)
         ->getJson('/api/client-data/fake-type')
         ->assertStatus(422);
});

// ── Push (POST) ───────────────────────────────────────────────────────────────

it('stores bank transactions and returns them on pull', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);

    $txId = \Illuminate\Support\Str::uuid()->toString();

    // Push
    $this->withHeaders($headers)->postJson('/api/client-data/bank-transactions', [
        'records' => [[
            'id'          => $txId,
            'date'        => '2026-04-01',
            'amount'      => 500000,
            'description' => 'Mobile money deposit',
            'type'        => 'credit',
        ]],
    ])->assertStatus(200)
      ->assertJsonPath('upserted', 1);

    // Pull — must come back
    $pull = $this->withHeaders($headers)
                 ->getJson('/api/client-data/bank-transactions');

    $pull->assertStatus(200);
    $data = $pull->json('data');
    expect($data)->toHaveCount(1);
    expect($data[0]['id'])->toBe($txId);
    expect($data[0]['amount'])->toBe(500000);
});

it('upserts (updates) an existing record by id', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);
    $id      = \Illuminate\Support\Str::uuid()->toString();

    // First push
    $this->withHeaders($headers)->postJson('/api/client-data/bank-transactions', [
        'records' => [['id' => $id, 'amount' => 100000, 'description' => 'Original']],
    ])->assertStatus(200);

    // Second push — same id, updated amount
    $this->withHeaders($headers)->postJson('/api/client-data/bank-transactions', [
        'records' => [['id' => $id, 'amount' => 999000, 'description' => 'Updated']],
    ])->assertStatus(200);

    // Pull — should only have 1 record with the updated value
    $pull = $this->withHeaders($headers)
                 ->getJson('/api/client-data/bank-transactions');

    $data = $pull->json('data');
    expect($data)->toHaveCount(1);
    expect($data[0]['amount'])->toBe(999000);
    expect($data[0]['description'])->toBe('Updated');
});

it('skips records without an id field', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);

    $this->withHeaders($headers)->postJson('/api/client-data/bank-transactions', [
        'records' => [
            ['amount' => 100],          // no id — should be skipped
            ['id' => '', 'amount' => 200], // empty id — should be skipped
        ],
    ])->assertStatus(200)
      ->assertJsonPath('upserted', 0);
});

it('rejects empty records array', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);

    $this->withHeaders($headers)->postJson('/api/client-data/bank-transactions', [
        'records' => [],
    ])->assertStatus(422);
});

// ── Tenant isolation ──────────────────────────────────────────────────────────

it('tenant A cannot see tenant B bank transactions', function () {
    $ctxA = $this->createTenantWithUser(['user' => ['email' => 'a@test.com']]);
    $ctxB = $this->createTenantWithUser(['user' => ['email' => 'b@test.com']]);

    // Tenant A pushes a record
    $this->withHeaders($this->tenantHeaders($ctxA['token'], $ctxA['tenant']->id))
         ->postJson('/api/client-data/bank-transactions', [
             'records' => [['id' => 'tx-from-A', 'amount' => 777000]],
         ])->assertStatus(200);

    // Tenant B pulls — must get 0 records
    $pull = $this->withHeaders($this->tenantHeaders($ctxB['token'], $ctxB['tenant']->id))
                 ->getJson('/api/client-data/bank-transactions');

    expect($pull->json('data'))->toHaveCount(0);
});
