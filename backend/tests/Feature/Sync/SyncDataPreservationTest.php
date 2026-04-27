<?php

/**
 * SyncDataPreservationTest
 *
 * Regression suite for the data-loss bug where journals and bills created
 * offline disappeared after the first sync. Root causes covered:
 *
 * 1. POST /journal-entries failed with 422 because company_id was required
 *    but the desktop client never sends it.  After the fix, company_id is
 *    resolved from the tenant context when absent.
 *
 * 2. POST /bills failed with 422 for the same reason, plus currency_id was
 *    required (client sends currency_code) and line quantity/unit_price were
 *    required (client sends a flat amount).
 *
 * 3. GET /bills did not eager-load lines, so the pull returned bills without
 *    line items.  LocalStorageService then saved bills with lines:[] and all
 *    bill lines were wiped from the local JSON cache.
 *
 * 4. account_id values from the desktop follow the "acct-NNN" / "NNN" code
 *    convention before the device has pulled server integer IDs.  The server
 *    must resolve those to real Account rows by code.
 */

use App\Models\Accounting\Account;
use App\Models\Currency;
use App\Models\Purchases\Vendor;

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Seed the minimum chart-of-accounts + currency needed for bills and journals.
 */
function seedAccountsAndCurrency(int $companyId): array
{
    $ugx = Currency::firstOrCreate(
        ['code' => 'UGX'],
        ['name' => 'Ugandan Shilling', 'symbol' => 'USh', 'exchange_rate' => 1, 'is_base' => true]
    );

    // Expense account (code 125) — used by bills
    $expense = Account::create([
        'company_id'  => $companyId,
        'code'        => '125',
        'name'        => 'Operating Expenses',
        'type'        => 'expense',
        'category'    => 'expense',
        'currency_id' => $ugx->id,
        'is_active'   => true,
    ]);

    // Accounts Payable (code 164) — credit side of bill JE
    $ap = Account::create([
        'company_id'  => $companyId,
        'code'        => '164',
        'name'        => 'Accounts Payable',
        'type'        => 'liability',
        'category'    => 'accounts_payable',
        'currency_id' => $ugx->id,
        'is_active'   => true,
    ]);

    // Cash account (code 101) — for journal entries
    $cash = Account::create([
        'company_id'  => $companyId,
        'code'        => '101',
        'name'        => 'Cash',
        'type'        => 'asset',
        'category'    => 'cash',
        'currency_id' => $ugx->id,
        'is_active'   => true,
    ]);

    return compact('ugx', 'expense', 'ap', 'cash');
}

// ── Journal Entry — push without company_id ───────────────────────────────────

it('creates a journal entry when company_id is absent (desktop client payload)', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);
    $accts   = seedAccountsAndCurrency($ctx['company']->id);

    $response = $this->withHeaders($headers)->postJson('/api/journal-entries', [
        // no company_id — desktop client never sends it
        'date'        => '2026-04-01',
        'description' => 'Test JE from desktop',
        'lines'       => [
            ['account_id' => 'acct-101', 'debit' => 500000, 'credit' => 0,      'description' => 'Cash in'],
            ['account_id' => 'acct-164', 'debit' => 0,      'credit' => 500000, 'description' => 'AP'],
        ],
    ]);

    $response->assertStatus(201)
             ->assertJsonPath('message', 'Journal entry created successfully');

    $this->assertDatabaseHas('journal_entries', ['description' => 'Test JE from desktop']);
});

it('stores journal lines when company_id is absent', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);
    $accts   = seedAccountsAndCurrency($ctx['company']->id);

    $response = $this->withHeaders($headers)->postJson('/api/journal-entries', [
        'date'        => '2026-04-01',
        'description' => 'JE with lines',
        'lines'       => [
            ['account_id' => $accts['cash']->id,    'debit' => 200000, 'credit' => 0],
            ['account_id' => $accts['expense']->id, 'debit' => 0,      'credit' => 200000],
        ],
    ]);

    $response->assertStatus(201);

    $je = $response->json('journal_entry');
    $this->assertNotEmpty($je['lines'], 'Journal entry must have lines in the response');
    $this->assertCount(2, $je['lines']);
});

it('resolves account_id by code string (e.g. "acct-125") when creating a journal entry', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);
    seedAccountsAndCurrency($ctx['company']->id);

    $response = $this->withHeaders($headers)->postJson('/api/journal-entries', [
        'date'        => '2026-04-01',
        'description' => 'Desktop code-based account IDs',
        'lines'       => [
            ['account_id' => 'acct-101', 'debit' => 100000, 'credit' => 0],
            ['account_id' => '164',      'debit' => 0,       'credit' => 100000],
        ],
    ]);

    $response->assertStatus(201);
    $this->assertCount(2, $response->json('journal_entry.lines'));
});

// ── Journal Entry — pull includes lines ───────────────────────────────────────

it('GET /journal-entries returns entries with their lines', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);
    $accts   = seedAccountsAndCurrency($ctx['company']->id);

    // Create one JE via the API so lines are attached
    $this->withHeaders($headers)->postJson('/api/journal-entries', [
        'date'        => '2026-04-01',
        'description' => 'Pull test JE',
        'lines'       => [
            ['account_id' => $accts['cash']->id,    'debit' => 750000, 'credit' => 0],
            ['account_id' => $accts['expense']->id, 'debit' => 0,      'credit' => 750000],
        ],
    ])->assertStatus(201);

    $pull = $this->withHeaders($headers)->getJson('/api/journal-entries?per_page=10000');
    $pull->assertStatus(200);

    $entries = $pull->json('data');
    $this->assertNotEmpty($entries, 'Pull must return at least one entry');

    $entry = collect($entries)->firstWhere('description', 'Pull test JE');
    $this->assertNotNull($entry, 'The created entry must appear in the pull response');
    $this->assertNotEmpty($entry['lines'], 'Pulled journal entry must include lines');
});

// ── Bill — push without company_id / currency_id ─────────────────────────────

it('creates a bill when company_id and currency_id are absent (desktop client payload)', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);
    $accts   = seedAccountsAndCurrency($ctx['company']->id);

    $vendor = Vendor::create([
        'company_id' => $ctx['company']->id,
        'name'       => 'Test Supplier',
        'status'     => 'active',
        'currency_id'=> $accts['ugx']->id,
    ]);

    $response = $this->withHeaders($headers)->postJson('/api/bills', [
        // no company_id, no currency_id — desktop sends currency_code instead
        'vendor_id'     => $vendor->id,
        'date'          => '2026-04-01',
        'due_date'      => '2026-04-30',
        'currency_code' => 'UGX',
        'lines'         => [
            [
                'account_id'  => 'acct-125',
                'description' => 'Office supplies',
                'amount'      => 300000,
                // no quantity, no unit_price — desktop sends amount only
            ],
        ],
    ]);

    $response->assertStatus(201)
             ->assertJsonPath('message', 'Bill created successfully');

    $this->assertDatabaseHas('bills', ['vendor_id' => $vendor->id]);
});

it('stores bill lines when pushing without quantity/unit_price', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);
    $accts   = seedAccountsAndCurrency($ctx['company']->id);

    $vendor = Vendor::create([
        'company_id'  => $ctx['company']->id,
        'name'        => 'Test Supplier 2',
        'status'      => 'active',
        'currency_id' => $accts['ugx']->id,
    ]);

    $response = $this->withHeaders($headers)->postJson('/api/bills', [
        'vendor_id'     => $vendor->id,
        'date'          => '2026-04-01',
        'currency_code' => 'UGX',
        'lines'         => [
            ['account_id' => 'acct-125', 'description' => 'Stationery',    'amount' => 150000],
            ['account_id' => 'acct-125', 'description' => 'Printing costs','amount' => 80000],
        ],
    ]);

    $response->assertStatus(201);

    $bill = $response->json('bill');
    $this->assertNotEmpty($bill['lines'], 'Bill response must include lines');
    $this->assertCount(2, $bill['lines']);
});

// ── Bill — pull includes lines ────────────────────────────────────────────────

it('GET /bills returns bills with their lines', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);
    $accts   = seedAccountsAndCurrency($ctx['company']->id);

    $vendor = Vendor::create([
        'company_id'  => $ctx['company']->id,
        'name'        => 'Pull Test Vendor',
        'status'      => 'active',
        'currency_id' => $accts['ugx']->id,
    ]);

    // Create a bill with two lines
    $this->withHeaders($headers)->postJson('/api/bills', [
        'vendor_id'     => $vendor->id,
        'date'          => '2026-04-01',
        'currency_code' => 'UGX',
        'lines'         => [
            ['account_id' => 'acct-125', 'description' => 'Internet',    'amount' => 200000],
            ['account_id' => 'acct-125', 'description' => 'Electricity', 'amount' => 350000],
        ],
    ])->assertStatus(201);

    $pull = $this->withHeaders($headers)->getJson('/api/bills?per_page=10000');
    $pull->assertStatus(200);

    $bills = $pull->json('data');
    $this->assertNotEmpty($bills, 'Pull must return at least one bill');

    $bill = $bills[0];
    $this->assertArrayHasKey('lines', $bill, 'Pulled bill must have a lines key');
    $this->assertNotEmpty($bill['lines'], 'Pulled bill must include at least one line');
});

// ── Full push+pull cycle — data survives ─────────────────────────────────────

it('journal entry lines survive a full push then pull cycle', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);
    $accts   = seedAccountsAndCurrency($ctx['company']->id);

    // PUSH: create a journal entry (simulating offline-created desktop data)
    $push = $this->withHeaders($headers)->postJson('/api/journal-entries', [
        'date'        => '2026-04-15',
        'description' => 'Cycle test JE',
        'lines'       => [
            ['account_id' => 'acct-101', 'debit' => 1000000, 'credit' => 0,       'description' => 'Cash'],
            ['account_id' => 'acct-164', 'debit' => 0,       'credit' => 1000000, 'description' => 'AP'],
        ],
    ]);
    $push->assertStatus(201);
    $pushedId = $push->json('journal_entry.id');

    // PULL: simulate what the desktop does on the next sync
    $pull = $this->withHeaders($headers)->getJson('/api/journal-entries?per_page=10000');
    $pull->assertStatus(200);

    $entries  = $pull->json('data');
    $found    = collect($entries)->firstWhere('id', $pushedId);

    $this->assertNotNull($found, "The pushed JE (id={$pushedId}) must appear in the pull");
    $this->assertNotEmpty($found['lines'], 'Lines must still be present after pull');
    $this->assertCount(2, $found['lines'], 'Both lines must survive the push+pull cycle');
});

it('bill lines survive a full push then pull cycle', function () {
    $ctx     = $this->createTenantWithUser();
    $headers = $this->tenantHeaders($ctx['token'], $ctx['tenant']->id);
    $accts   = seedAccountsAndCurrency($ctx['company']->id);

    $vendor = Vendor::create([
        'company_id'  => $ctx['company']->id,
        'name'        => 'Cycle Vendor',
        'status'      => 'active',
        'currency_id' => $accts['ugx']->id,
    ]);

    // PUSH
    $push = $this->withHeaders($headers)->postJson('/api/bills', [
        'vendor_id'     => $vendor->id,
        'date'          => '2026-04-15',
        'currency_code' => 'UGX',
        'lines'         => [
            ['account_id' => 'acct-125', 'description' => 'Rent',      'amount' => 800000],
            ['account_id' => 'acct-125', 'description' => 'Utilities', 'amount' => 120000],
        ],
    ]);
    $push->assertStatus(201);
    $pushedId = $push->json('bill.id');

    // PULL
    $pull = $this->withHeaders($headers)->getJson('/api/bills?per_page=10000');
    $pull->assertStatus(200);

    $bills = $pull->json('data');
    $found = collect($bills)->firstWhere('id', $pushedId);

    $this->assertNotNull($found, "The pushed bill (id={$pushedId}) must appear in the pull");
    $this->assertNotEmpty($found['lines'], 'Lines must still be present after pull');
    $this->assertCount(2, $found['lines'], 'Both lines must survive the push+pull cycle');
});
