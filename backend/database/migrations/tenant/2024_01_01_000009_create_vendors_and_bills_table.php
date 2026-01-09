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
        Schema::create('vendors', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->string('vendor_number')->unique();
            $table->string('name');
            $table->string('company_name')->nullable();
            $table->string('email')->nullable();
            $table->string('phone')->nullable();
            $table->string('mobile')->nullable();
            $table->text('address')->nullable();
            $table->string('city')->nullable();
            $table->string('state')->nullable();
            $table->string('postal_code')->nullable();
            $table->string('country', 2)->default('UG');
            $table->string('tax_id')->nullable();
            $table->foreignId('currency_id')->constrained();
            $table->integer('payment_terms_days')->default(30);
            $table->enum('status', ['active', 'inactive'])->default('active');
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['company_id', 'status']);
            $table->index('vendor_number');
        });

        Schema::create('bills', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('vendor_id')->constrained()->restrictOnDelete();
            $table->foreignId('journal_entry_id')->nullable()->constrained()->nullOnDelete();

            $table->string('bill_number')->unique();
            $table->string('vendor_invoice_number')->nullable();
            $table->date('date');
            $table->date('due_date');
            $table->string('reference')->nullable();
            $table->text('notes')->nullable();

            $table->foreignId('currency_id')->constrained();
            $table->decimal('exchange_rate', 20, 10)->default(1);
            $table->decimal('subtotal', 20, 4)->default(0);
            $table->decimal('tax_amount', 20, 4)->default(0);
            $table->decimal('discount_amount', 20, 4)->default(0);
            $table->decimal('total', 20, 4)->default(0);
            $table->decimal('paid_amount', 20, 4)->default(0);
            $table->decimal('balance', 20, 4)->default(0);

            $table->enum('status', ['draft', 'approved', 'partial', 'paid', 'overdue', 'cancelled'])->default('draft');
            $table->timestamp('approved_at')->nullable();
            $table->foreignId('approved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('paid_at')->nullable();

            $table->timestamps();
            $table->softDeletes();

            $table->index(['company_id', 'vendor_id']);
            $table->index(['company_id', 'status']);
            $table->index('bill_number');
            $table->index('due_date');
        });

        Schema::create('bill_lines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('bill_id')->constrained()->cascadeOnDelete();
            $table->foreignId('account_id')->nullable()->constrained()->nullOnDelete(); // Expense account
            $table->text('description');
            $table->decimal('quantity', 20, 4)->default(1);
            $table->decimal('unit_price', 20, 4)->default(0);
            $table->decimal('discount_percent', 5, 2)->default(0);
            $table->decimal('discount_amount', 20, 4)->default(0);
            $table->decimal('tax_rate', 5, 2)->default(0);
            $table->decimal('tax_amount', 20, 4)->default(0);
            $table->decimal('amount', 20, 4)->default(0);
            $table->integer('order')->default(0);
            $table->timestamps();

            $table->index('bill_id');
        });

        Schema::create('bill_payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('vendor_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('bill_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('journal_entry_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('payment_account_id')->constrained('accounts')->restrictOnDelete(); // Bank/Cash

            $table->string('payment_number')->unique();
            $table->date('date');
            $table->decimal('amount', 20, 4);
            $table->foreignId('currency_id')->constrained();
            $table->decimal('exchange_rate', 20, 10)->default(1);

            $table->enum('method', ['cash', 'bank_transfer', 'cheque', 'mobile_money', 'credit_card', 'other'])->default('cash');
            $table->string('reference')->nullable();
            $table->text('notes')->nullable();

            $table->enum('status', ['pending', 'cleared', 'bounced', 'cancelled'])->default('cleared');

            $table->timestamps();
            $table->softDeletes();

            $table->index(['company_id', 'vendor_id']);
            $table->index('payment_number');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('bill_payments');
        Schema::dropIfExists('bill_lines');
        Schema::dropIfExists('bills');
        Schema::dropIfExists('vendors');
    }
};
