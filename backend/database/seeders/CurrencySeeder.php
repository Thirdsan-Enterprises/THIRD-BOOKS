<?php

namespace Database\Seeders;

use App\Models\Currency;
use Illuminate\Database\Seeder;

class CurrencySeeder extends Seeder
{
    /**
     * Seed currencies
     */
    public function run(): void
    {
        $currencies = [
            // East African currencies
            [
                'code' => 'UGX',
                'name' => 'Ugandan Shilling',
                'symbol' => 'UGX',
                'decimal_places' => 0,
                'is_active' => true,
            ],
            [
                'code' => 'KES',
                'name' => 'Kenyan Shilling',
                'symbol' => 'KES',
                'decimal_places' => 2,
                'is_active' => true,
            ],
            [
                'code' => 'TZS',
                'name' => 'Tanzanian Shilling',
                'symbol' => 'TZS',
                'decimal_places' => 0,
                'is_active' => true,
            ],
            [
                'code' => 'RWF',
                'name' => 'Rwandan Franc',
                'symbol' => 'RWF',
                'decimal_places' => 0,
                'is_active' => true,
            ],

            // Major international currencies
            [
                'code' => 'USD',
                'name' => 'US Dollar',
                'symbol' => '$',
                'decimal_places' => 2,
                'is_active' => true,
            ],
            [
                'code' => 'EUR',
                'name' => 'Euro',
                'symbol' => '€',
                'decimal_places' => 2,
                'is_active' => true,
            ],
            [
                'code' => 'GBP',
                'name' => 'British Pound',
                'symbol' => '£',
                'decimal_places' => 2,
                'is_active' => true,
            ],
            [
                'code' => 'ZAR',
                'name' => 'South African Rand',
                'symbol' => 'R',
                'decimal_places' => 2,
                'is_active' => true,
            ],
        ];

        foreach ($currencies as $currency) {
            Currency::firstOrCreate(
                ['code' => $currency['code']],
                $currency
            );
        }

        $this->command->info('Currencies seeded successfully!');
    }
}
