<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * asset_registers — one record per physical asset acquired by the company.
     * Created automatically when a bill line uses a fixed-asset CoA account,
     * or manually via the Assets UI.
     */
    public function up(): void
    {
        if (Schema::hasTable('asset_registers')) {
            return;
        }

        // Live DB uses bill_lines; fall back gracefully if neither exists
        $billLinesTable = Schema::hasTable('bill_lines') ? 'bill_lines' : 'bill_items';

        Schema::create('asset_registers', function (Blueprint $table) use ($billLinesTable) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();

            // Source bill (nullable — assets can be added manually)
            $table->foreignId('bill_id')->nullable()->constrained('bills')->nullOnDelete();
            $table->unsignedBigInteger('bill_line_id')->nullable();
            $table->foreign('bill_line_id')->references('id')->on($billLinesTable)->nullOnDelete();

            // The Chart-of-Accounts account that carries this asset's book value
            $table->foreignId('coa_account_id')->constrained('accounts')->restrictOnDelete();

            // Identifiers
            $table->string('asset_code', 50)->nullable();
            $table->string('name');
            $table->string('category');         // Vehicle, Equipment, Furniture, Electronics, Building, Land, Machinery
            $table->text('description')->nullable();

            // Financials
            $table->decimal('cost', 20, 4);           // Original acquisition cost
            $table->decimal('salvage_value', 20, 4)->default(0);
            $table->decimal('current_book_value', 20, 4); // Updated by depreciation posts
            $table->string('currency_code', 10)->default('UGX');

            // Lifecycle
            $table->date('acquisition_date');
            $table->date('disposal_date')->nullable();
            $table->string('status', 20)->default('active'); // active | disposed | damaged | written_off
            $table->string('location')->nullable();
            $table->string('responsible_person')->nullable();

            // Depreciation settings
            $table->string('depreciation_method', 30)->nullable(); // straight_line | declining_balance
            $table->decimal('depreciation_rate', 10, 4)->nullable(); // Annual % e.g. 20.00
            $table->string('depreciation_period', 20)->nullable();   // monthly | yearly
            $table->decimal('useful_life_years', 6, 2)->nullable();
            $table->date('depreciation_start_date')->nullable();
            $table->date('last_depreciation_date')->nullable();

            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['company_id', 'status']);
            $table->index(['company_id', 'category']);
            $table->index(['company_id', 'coa_account_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('asset_registers');
    }
};
