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
        Schema::create('payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('customer_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('invoice_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('journal_entry_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('deposit_account_id')->constrained('accounts')->restrictOnDelete(); // Bank/Cash account

            $table->string('payment_number')->unique();
            $table->date('date');
            $table->decimal('amount', 20, 4);
            $table->foreignId('currency_id')->constrained();
            $table->decimal('exchange_rate', 20, 10)->default(1);

            $table->enum('method', ['cash', 'bank_transfer', 'cheque', 'mobile_money', 'credit_card', 'other'])->default('cash');
            $table->string('reference')->nullable(); // Transaction reference, cheque number, etc.
            $table->text('notes')->nullable();

            $table->enum('status', ['pending', 'cleared', 'bounced', 'cancelled'])->default('cleared');

            $table->timestamps();
            $table->softDeletes();

            $table->index(['company_id', 'customer_id']);
            $table->index(['company_id', 'date']);
            $table->index('payment_number');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('payments');
    }
};
