<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * General Ledger is a denormalized table for performance.
     * GL updates are handled in the application layer via GeneralLedgerService
     * for database portability (MySQL/MariaDB/PostgreSQL).
     */
    public function up(): void
    {
        Schema::create('general_ledger', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('account_id')->constrained()->restrictOnDelete();
            $table->foreignId('journal_line_id')->constrained()->cascadeOnDelete();
            $table->foreignId('journal_entry_id')->constrained()->cascadeOnDelete();

            $table->date('date');
            $table->string('entry_number'); // Denormalized from journal_entry
            $table->text('description')->nullable();

            $table->decimal('debit', 20, 4)->default(0);
            $table->decimal('credit', 20, 4)->default(0);
            $table->decimal('balance', 20, 4)->default(0); // Running balance

            $table->foreignId('currency_id')->constrained();
            $table->decimal('exchange_rate', 20, 10)->default(1);

            $table->timestamps();

            // Critical indexes for performance
            $table->index(['company_id', 'account_id', 'date']);
            $table->index(['account_id', 'date']);
            $table->index('date');
            $table->index('journal_entry_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('general_ledger');
    }
};
