<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('accounts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('parent_id')->nullable()->constrained('accounts')->nullOnDelete();

            $table->string('code', 50)->unique(); // e.g., 1000, 1010, 2000
            $table->string('name');
            $table->text('description')->nullable();

            // Account Type: Asset, Liability, Equity, Income, Expense
            $table->enum('type', ['asset', 'liability', 'equity', 'income', 'expense']);

            // Subtype for detailed classification
            $table->string('subtype')->nullable(); // e.g., current_asset, fixed_asset, current_liability

            // Account Category Detail
            $table->enum('category', [
                'bank', 'cash', 'accounts_receivable', 'inventory', 'fixed_asset',
                'accounts_payable', 'credit_card', 'long_term_liability',
                'equity', 'income', 'cost_of_goods_sold', 'expense', 'other_income',
                'other_expense', 'intangible_asset'
            ])->nullable();

            $table->foreignId('currency_id')->constrained();
            $table->decimal('opening_balance', 20, 4)->default(0);
            $table->decimal('current_balance', 20, 4)->default(0);
            $table->boolean('is_active')->default(true);
            $table->boolean('is_system')->default(false); // System accounts can't be deleted
            $table->integer('order')->default(0); // For sorting
            $table->json('settings')->nullable();

            $table->timestamps();
            $table->softDeletes();

            $table->index(['company_id', 'type']);
            $table->index(['company_id', 'category']);
            $table->index('code');
            $table->index('is_active');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('accounts');
    }
};
