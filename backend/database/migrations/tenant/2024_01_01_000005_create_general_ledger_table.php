<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     * General Ledger is a denormalized table for performance
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

        // Function to automatically update general ledger when journal line is posted
        DB::statement('
            CREATE OR REPLACE FUNCTION update_general_ledger()
            RETURNS TRIGGER AS $$
            DECLARE
                je_data RECORD;
                prev_balance NUMERIC(20,4);
                acc_type TEXT;
            BEGIN
                -- Get journal entry data
                SELECT je.date, je.entry_number, je.company_id, je.status
                INTO je_data
                FROM journal_entries je
                WHERE je.id = NEW.journal_entry_id;

                -- Only update GL for posted entries
                IF je_data.status != \'posted\' THEN
                    RETURN NEW;
                END IF;

                -- Get account type to determine balance calculation
                SELECT type INTO acc_type FROM accounts WHERE id = NEW.account_id;

                -- Get previous balance for this account
                SELECT COALESCE(balance, 0) INTO prev_balance
                FROM general_ledger
                WHERE account_id = NEW.account_id
                  AND date <= je_data.date
                ORDER BY date DESC, id DESC
                LIMIT 1;

                -- Insert into general ledger
                INSERT INTO general_ledger (
                    company_id, account_id, journal_line_id, journal_entry_id,
                    date, entry_number, description,
                    debit, credit, balance,
                    currency_id, exchange_rate,
                    created_at, updated_at
                ) VALUES (
                    je_data.company_id, NEW.account_id, NEW.id, NEW.journal_entry_id,
                    je_data.date, je_data.entry_number, NEW.description,
                    NEW.debit, NEW.credit,
                    -- Calculate balance based on account type
                    CASE
                        WHEN acc_type IN (\'asset\', \'expense\') THEN prev_balance + NEW.debit - NEW.credit
                        WHEN acc_type IN (\'liability\', \'equity\', \'income\') THEN prev_balance + NEW.credit - NEW.debit
                    END,
                    NEW.currency_id, NEW.exchange_rate,
                    NOW(), NOW()
                );

                -- Update account current balance
                UPDATE accounts
                SET current_balance = (
                    SELECT balance FROM general_ledger
                    WHERE account_id = NEW.account_id
                    ORDER BY date DESC, id DESC
                    LIMIT 1
                )
                WHERE id = NEW.account_id;

                RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
        ');

        DB::statement('
            CREATE TRIGGER update_gl_on_post
            AFTER INSERT ON journal_lines
            FOR EACH ROW EXECUTE FUNCTION update_general_ledger();
        ');
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        DB::statement('DROP TRIGGER IF EXISTS update_gl_on_post ON journal_lines');
        DB::statement('DROP FUNCTION IF EXISTS update_general_ledger()');
        Schema::dropIfExists('general_ledger');
    }
};
