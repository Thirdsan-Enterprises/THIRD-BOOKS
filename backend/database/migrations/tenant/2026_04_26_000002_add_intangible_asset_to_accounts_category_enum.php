<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Extends the accounts.category ENUM to include 'intangible_asset'.
 * Must run before the intangible account seeding migrations.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (DB::getDriverName() === 'sqlite') {
            return; // SQLite has no ENUM type; category is stored as varchar
        }

        DB::statement("ALTER TABLE `accounts` MODIFY COLUMN `category` ENUM(
            'bank', 'cash', 'accounts_receivable', 'inventory', 'fixed_asset',
            'accounts_payable', 'credit_card', 'long_term_liability',
            'equity', 'income', 'cost_of_goods_sold', 'expense', 'other_income',
            'other_expense', 'intangible_asset'
        ) NULL");
    }

    public function down(): void
    {
        if (DB::getDriverName() === 'sqlite') {
            return;
        }

        DB::statement("ALTER TABLE `accounts` MODIFY COLUMN `category` ENUM(
            'bank', 'cash', 'accounts_receivable', 'inventory', 'fixed_asset',
            'accounts_payable', 'credit_card', 'long_term_liability',
            'equity', 'income', 'cost_of_goods_sold', 'expense', 'other_income',
            'other_expense'
        ) NULL");
    }
};
