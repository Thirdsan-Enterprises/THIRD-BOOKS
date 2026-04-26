<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Add IAS 38 intangible asset accounts (1700-1820) and Amortization Expense
 * (6910) to every existing company that was created before the amortization
 * feature was shipped.
 *
 * Uses updateOrInsert keyed on (company_id, code) so re-running is safe.
 */
return new class extends Migration
{
    public function up(): void
    {
        $companies = DB::table('companies')->get();

        foreach ($companies as $company) {
            $currency = DB::table('currencies')
                ->where('code', $company->base_currency ?? 'UGX')
                ->first();

            if (!$currency) {
                $currency = DB::table('currencies')->first();
            }

            if (!$currency) {
                continue;
            }

            $now = now();

            $newAccounts = [
                // Intangible Assets (IAS 38 / ASC 350)
                [
                    'code'        => '1700',
                    'name'        => 'Intangible Assets',
                    'type'        => 'asset',
                    'category'    => 'intangible_asset',
                    'description' => 'IAS 38 – intangible assets (finite & indefinite life)',
                    'is_system'   => false,
                ],
                [
                    'code'        => '1710',
                    'name'        => 'Software & Licenses',
                    'type'        => 'asset',
                    'category'    => 'intangible_asset',
                    'description' => 'Purchased software and perpetual licenses (IAS 38)',
                    'is_system'   => false,
                ],
                [
                    'code'        => '1720',
                    'name'        => 'Patents & Trademarks',
                    'type'        => 'asset',
                    'category'    => 'intangible_asset',
                    'description' => 'Registered patents, trademarks and similar IP (IAS 38)',
                    'is_system'   => false,
                ],
                [
                    'code'        => '1730',
                    'name'        => 'Goodwill',
                    'type'        => 'asset',
                    'category'    => 'intangible_asset',
                    'description' => 'Goodwill arising from business combinations (IFRS 3)',
                    'is_system'   => false,
                ],
                [
                    'code'        => '1800',
                    'name'        => 'Accumulated Amortization',
                    'type'        => 'asset',
                    'category'    => 'intangible_asset',
                    'description' => 'Contra-asset: total amortization charged on intangibles',
                    'is_system'   => false,
                ],
                [
                    'code'        => '1810',
                    'name'        => 'Accumulated Amortization - Software',
                    'type'        => 'asset',
                    'category'    => 'intangible_asset',
                    'description' => 'Contra-asset: amortization on software & licenses',
                    'is_system'   => false,
                ],
                [
                    'code'        => '1820',
                    'name'        => 'Accumulated Amortization - Patents',
                    'type'        => 'asset',
                    'category'    => 'intangible_asset',
                    'description' => 'Contra-asset: amortization on patents & trademarks',
                    'is_system'   => false,
                ],
                // Amortization Expense
                [
                    'code'        => '6910',
                    'name'        => 'Amortization Expense',
                    'type'        => 'expense',
                    'category'    => 'expense',
                    'description' => 'Periodic amortization charge on intangible assets (IAS 38)',
                    'is_system'   => false,
                ],
            ];

            foreach ($newAccounts as $account) {
                // Only insert if this company does not already have this code.
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
                        'description'     => $account['description'],
                        'is_system'       => $account['is_system'],
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
        $codes = ['1700', '1710', '1720', '1730', '1800', '1810', '1820', '6910'];

        DB::table('accounts')
            ->whereIn('code', $codes)
            ->where('is_system', false)
            ->delete();
    }
};
