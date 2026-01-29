<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * NOTE: Balance validation (debits = credits) is handled in the application layer
     * via JournalEntryService::validateBalance() for database portability.
     */
    public function up(): void
    {
        Schema::create('journal_entries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->string('entry_number')->unique(); // JE-2024-0001
            $table->date('date');
            $table->string('reference')->nullable(); // External reference
            $table->text('description')->nullable();
            $table->enum('status', ['draft', 'posted'])->default('draft');
            $table->enum('type', ['manual', 'automatic'])->default('manual');
            $table->string('source')->nullable(); // invoice, bill, payment, etc.
            $table->unsignedBigInteger('source_id')->nullable(); // ID of source record
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->foreignId('posted_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('posted_at')->nullable();
            $table->boolean('is_locked')->default(false); // Period locking
            $table->timestamps();
            $table->softDeletes();

            $table->index(['company_id', 'date']);
            $table->index(['company_id', 'status']);
            $table->index('entry_number');
            $table->index(['source', 'source_id']);
        });

        Schema::create('journal_lines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('journal_entry_id')->constrained()->cascadeOnDelete();
            $table->foreignId('account_id')->constrained()->restrictOnDelete();
            $table->text('description')->nullable();

            // Double-entry amounts (validation handled in application layer)
            $table->decimal('debit', 20, 4)->unsigned()->default(0);
            $table->decimal('credit', 20, 4)->unsigned()->default(0);

            // Multi-currency support
            $table->foreignId('currency_id')->constrained();
            $table->decimal('exchange_rate', 20, 10)->default(1);
            $table->decimal('debit_foreign', 20, 4)->unsigned()->default(0);
            $table->decimal('credit_foreign', 20, 4)->unsigned()->default(0);

            $table->integer('order')->default(0);
            $table->timestamps();

            $table->index(['journal_entry_id', 'account_id']);
            $table->index('account_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('journal_lines');
        Schema::dropIfExists('journal_entries');
    }
};
