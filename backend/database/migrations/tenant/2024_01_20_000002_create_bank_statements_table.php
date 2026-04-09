<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * bank_statements        — an uploaded bank statement file for a given bank account
     * bank_statement_lines   — individual rows from that statement
     * reconciliation_items   — links one statement line to one or more bills/invoices/GL lines (many-to-many with amount allocation)
     */
    public function up(): void
    {
        // ── Bank Statements ──────────────────────────────────────────────────────
        Schema::create('bank_statements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();

            // The account in the Chart of Accounts (type = asset/liability, category = bank/cash/credit_card/etc.)
            $table->foreignId('bank_account_id')->constrained('accounts')->restrictOnDelete();

            $table->string('reference_number')->nullable(); // e.g. statement number from bank
            $table->date('from_date');
            $table->date('to_date');
            $table->decimal('opening_balance', 20, 4)->default(0);
            $table->decimal('closing_balance', 20, 4)->default(0);

            // Uploaded file info
            $table->string('file_name')->nullable();
            $table->string('file_path')->nullable();
            $table->string('disk')->default('local');

            $table->enum('status', ['pending', 'in_progress', 'reconciled'])->default('pending');
            $table->text('notes')->nullable();

            $table->foreignId('uploaded_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['company_id', 'bank_account_id']);
            $table->index(['company_id', 'status']);
            $table->index('from_date');
            $table->index('to_date');
        });

        // ── Bank Statement Lines ─────────────────────────────────────────────────
        Schema::create('bank_statement_lines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('bank_statement_id')->constrained()->cascadeOnDelete();

            $table->date('date');
            $table->string('description');
            $table->string('reference')->nullable();
            $table->decimal('debit', 20, 4)->default(0);   // Money leaving the account
            $table->decimal('credit', 20, 4)->default(0);  // Money entering the account
            $table->decimal('balance', 20, 4)->nullable();  // Running balance per statement

            // Reconciliation tracking
            $table->decimal('reconciled_amount', 20, 4)->default(0);
            $table->enum('status', ['unmatched', 'partial', 'reconciled'])->default('unmatched');
            $table->text('notes')->nullable();

            $table->timestamps();

            $table->index('bank_statement_id');
            $table->index(['bank_statement_id', 'status']);
            $table->index('date');
        });

        // ── Reconciliation Items ─────────────────────────────────────────────────
        // Links one bank_statement_line to one or more payables/receivables/GL entries.
        // Supports: one line paying multiple bills, or one line covering multiple invoices.
        Schema::create('reconciliation_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('bank_statement_line_id')->constrained()->cascadeOnDelete();

            // Polymorphic: Bill, Invoice, BillPayment, Payment, JournalEntry, etc.
            $table->string('reconcilable_type');
            $table->unsignedBigInteger('reconcilable_id');

            $table->decimal('amount', 20, 4); // Amount allocated from this statement line to this item
            $table->text('notes')->nullable();

            // Optional: link to the journal entry that was auto-created for this reconciliation
            $table->foreignId('journal_entry_id')->nullable()->constrained()->nullOnDelete();

            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['reconcilable_type', 'reconcilable_id']);
            $table->index('bank_statement_line_id');
            $table->index('company_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('reconciliation_items');
        Schema::dropIfExists('bank_statement_lines');
        Schema::dropIfExists('bank_statements');
    }
};
