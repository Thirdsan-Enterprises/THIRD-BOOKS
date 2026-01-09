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

            // Double-entry amounts
            $table->decimal('debit', 20, 4)->default(0);
            $table->decimal('credit', 20, 4)->default(0);

            // Multi-currency support
            $table->foreignId('currency_id')->constrained();
            $table->decimal('exchange_rate', 20, 10)->default(1);
            $table->decimal('debit_foreign', 20, 4)->default(0);
            $table->decimal('credit_foreign', 20, 4)->default(0);

            $table->integer('order')->default(0);
            $table->timestamps();

            $table->index(['journal_entry_id', 'account_id']);
            $table->index('account_id');

            // CRITICAL: Ensure debits and credits are never negative
            $table->rawIndex('CHECK (debit >= 0 AND credit >= 0)', 'journal_lines_amounts_check');
        });

        // Add constraint to ensure journal entries balance
        DB::statement('
            CREATE OR REPLACE FUNCTION check_journal_balance()
            RETURNS TRIGGER AS $$
            DECLARE
                entry_id BIGINT;
                total_debits NUMERIC(20,4);
                total_credits NUMERIC(20,4);
            BEGIN
                IF TG_OP = \'DELETE\' THEN
                    entry_id := OLD.journal_entry_id;
                ELSE
                    entry_id := NEW.journal_entry_id;
                END IF;

                SELECT
                    COALESCE(SUM(debit), 0),
                    COALESCE(SUM(credit), 0)
                INTO total_debits, total_credits
                FROM journal_lines
                WHERE journal_entry_id = entry_id;

                IF total_debits != total_credits THEN
                    RAISE EXCEPTION \'Journal entry must balance: Debits (%) != Credits (%)\',
                        total_debits, total_credits;
                END IF;

                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
        ');

        DB::statement('
            CREATE TRIGGER ensure_journal_balance
            AFTER INSERT OR UPDATE OR DELETE ON journal_lines
            FOR EACH ROW EXECUTE FUNCTION check_journal_balance();
        ');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        DB::statement('DROP TRIGGER IF EXISTS ensure_journal_balance ON journal_lines');
        DB::statement('DROP FUNCTION IF EXISTS check_journal_balance()');
        Schema::dropIfExists('journal_lines');
        Schema::dropIfExists('journal_entries');
    }
};
