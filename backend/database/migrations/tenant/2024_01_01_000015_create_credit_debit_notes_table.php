<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Credit Notes — issued to customers, reduce their invoice balance
        Schema::create('credit_notes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('customer_id')->constrained()->restrictOnDelete();
            $table->foreignId('invoice_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('journal_entry_id')->nullable()->constrained()->nullOnDelete();

            $table->string('credit_note_number')->unique();
            $table->date('date');
            $table->string('reason');
            $table->text('notes')->nullable();

            $table->string('currency_code', 10)->default('UGX');
            $table->decimal('amount', 20, 4)->default(0);

            $table->enum('status', ['draft', 'issued', 'applied', 'cancelled'])->default('draft');

            $table->timestamps();
            $table->softDeletes();

            $table->index(['company_id', 'customer_id']);
            $table->index(['company_id', 'status']);
            $table->index('credit_note_number');
        });

        // Debit Notes — issued to vendors, reduce their bill balance
        Schema::create('debit_notes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('vendor_id')->constrained()->restrictOnDelete();
            $table->foreignId('bill_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('journal_entry_id')->nullable()->constrained()->nullOnDelete();

            $table->string('debit_note_number')->unique();
            $table->date('date');
            $table->string('reason');
            $table->text('notes')->nullable();

            $table->string('currency_code', 10)->default('UGX');
            $table->decimal('amount', 20, 4)->default(0);

            $table->enum('status', ['draft', 'issued', 'applied', 'cancelled'])->default('draft');

            $table->timestamps();
            $table->softDeletes();

            $table->index(['company_id', 'vendor_id']);
            $table->index(['company_id', 'status']);
            $table->index('debit_note_number');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('debit_notes');
        Schema::dropIfExists('credit_notes');
    }
};
