<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Idempotent patch: ensures accounts 1700–1820 and 6910 exist for every
 * company. The earlier migration (2026_04_26_000001) ran before any company
 * existed, so this re-applies the same logic now that companies are present.
 */
return new class extends Migration
{
    public function up(): void
    {
        $companies = DB::table('companies')->get();

        foreach ($companies as $company) {
            $currency = DB::table('currencies')
                ->where('code', $company->base_currency ?? 'UGX')
                ->first()
                ?? DB::table('currencies')->first();

            if (!$currency) {
                continue;
            }

            $now = now();

            $accounts = [
                ['code' => '1700', 'name' => 'Intangible Assets',                    'type' => 'asset',   'category' => 'intangible_asset'],
                ['code' => '1710', 'name' => 'Software & Licenses',                  'type' => 'asset',   'category' => 'intangible_asset'],
                ['code' => '1720', 'name' => 'Patents & Trademarks',                 'type' => 'asset',   'category' => 'intangible_asset'],
                ['code' => '1730', 'name' => 'Goodwill',                             'type' => 'asset',   'category' => 'intangible_asset'],
                ['code' => '1800', 'name' => 'Accumulated Amortization',             'type' => 'asset',   'category' => 'intangible_asset'],
                ['code' => '1810', 'name' => 'Accumulated Amortization - Software',  'type' => 'asset',   'category' => 'intangible_asset'],
                ['code' => '1820', 'name' => 'Accumulated Amortization - Patents',   'type' => 'asset',   'category' => 'intangible_asset'],
                ['code' => '6910', 'name' => 'Amortization Expense',                 'type' => 'expense', 'category' => 'expense'],
            ];

            foreach ($accounts as $account) {
                $exists = DB::table('accounts')
                    ->where('company_id', $company->id)
                    ->where('code', $account['code'])
                    ->exists();

                if (!$exists) {
                    DB::table('accounts')->insert([
                        'company_id'      => $company->id,
                        'currency_id'     => $currency->id,
                        'code'            => $account['code'],
                        'name'            => $account['name'],
                        'type'            => $account['type'],
                        'category'        => $account['category'],
                        'is_system'       => false,
                        'is_active'       => true,
                        'opening_balance' => 0,
                        'current_balance' => 0,
                        'order'           => 0,
                        'created_at'      => $now,
                        'updated_at'      => $now,
                    ]);
                }
            }
        }
    }

    public function down(): void
    {
        DB::table('accounts')
            ->whereIn('code', ['1700', '1710', '1720', '1730', '1800', '1810', '1820', '6910'])
            ->where('is_system', false)
            ->delete();
    }
};
