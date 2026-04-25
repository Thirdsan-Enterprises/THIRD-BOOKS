<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * depreciation_entries — one row per depreciation posting period.
     * Each posting generates a journal entry: DR Depreciation Expense / CR Accumulated Depreciation.
     */
    public function up(): void
    {
        if (Schema::hasTable('depreciation_entries')) {
            return;
        }

        Schema::create('depreciation_entries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('asset_register_id')->constrained('asset_registers')->cascadeOnDelete();

            // The journal entry that was posted for this depreciation run
            $table->foreignId('journal_entry_id')->nullable()->constrained('journal_entries')->nullOnDelete();

            $table->date('period_date');               // End-of-period date the entry is dated
            $table->string('period_label', 30);        // e.g. "Jan 2026", "FY 2026"
            $table->decimal('depreciation_amount', 20, 4);
            $table->decimal('accumulated_depreciation', 20, 4); // running total at this point
            $table->decimal('book_value_after', 20, 4);          // asset value after this entry

            $table->string('method', 30);   // straight_line | declining_balance
            $table->decimal('rate_used', 10, 4);

            $table->string('status', 20)->default('posted'); // posted | reversed
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['company_id', 'asset_register_id', 'period_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('depreciation_entries');
    }
};
