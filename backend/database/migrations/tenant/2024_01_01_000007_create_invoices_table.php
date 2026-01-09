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
        Schema::create('invoices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('customer_id')->constrained()->restrictOnDelete();
            $table->foreignId('journal_entry_id')->nullable()->constrained()->nullOnDelete();

            $table->string('invoice_number')->unique();
            $table->date('date');
            $table->date('due_date');
            $table->string('reference')->nullable();
            $table->text('notes')->nullable();
            $table->text('terms')->nullable();

            // Amounts
            $table->foreignId('currency_id')->constrained();
            $table->decimal('exchange_rate', 20, 10)->default(1);
            $table->decimal('subtotal', 20, 4)->default(0);
            $table->decimal('tax_amount', 20, 4)->default(0);
            $table->decimal('discount_amount', 20, 4)->default(0);
            $table->decimal('total', 20, 4)->default(0);
            $table->decimal('paid_amount', 20, 4)->default(0);
            $table->decimal('balance', 20, 4)->default(0);

            $table->enum('status', ['draft', 'sent', 'viewed', 'partial', 'paid', 'overdue', 'cancelled'])->default('draft');
            $table->timestamp('sent_at')->nullable();
            $table->timestamp('viewed_at')->nullable();
            $table->timestamp('paid_at')->nullable();

            $table->timestamps();
            $table->softDeletes();

            $table->index(['company_id', 'customer_id']);
            $table->index(['company_id', 'status']);
            $table->index(['company_id', 'date']);
            $table->index('invoice_number');
            $table->index('due_date');
        });

        Schema::create('invoice_lines', function (Blueprint $table) {
            $table->id();
            $table->foreignId('invoice_id')->constrained()->cascadeOnDelete();
            $table->foreignId('account_id')->nullable()->constrained()->nullOnDelete(); // Income account
            $table->text('description');
            $table->decimal('quantity', 20, 4)->default(1);
            $table->decimal('unit_price', 20, 4)->default(0);
            $table->decimal('discount_percent', 5, 2)->default(0);
            $table->decimal('discount_amount', 20, 4)->default(0);
            $table->decimal('tax_rate', 5, 2)->default(0); // 18% VAT in Uganda
            $table->decimal('tax_amount', 20, 4)->default(0);
            $table->decimal('amount', 20, 4)->default(0);
            $table->integer('order')->default(0);
            $table->timestamps();

            $table->index('invoice_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('invoice_lines');
        Schema::dropIfExists('invoices');
    }
};
