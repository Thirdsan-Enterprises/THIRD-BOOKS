<?php

namespace App\Services\Accounting;

use App\Models\Accounting\Account;
use App\Models\Accounting\GeneralLedger;
use App\Models\Accounting\JournalEntry;
use App\Models\Accounting\JournalLine;
use Illuminate\Support\Facades\DB;

/**
 * General Ledger Service
 *
 * Handles all general ledger operations including:
 * - Creating GL entries when journal entries are posted
 * - Calculating running balances
 * - Updating account balances
 *
 * This replaces the PostgreSQL trigger functionality for database portability.
 */
class GeneralLedgerService
{
    /**
     * Post journal entry to general ledger
     *
     * Creates GL entries for each journal line and updates account balances.
     *
     * @param JournalEntry $journalEntry
     * @return void
     * @throws \Exception
     */
    public function postToLedger(JournalEntry $journalEntry): void
    {
        if (!$journalEntry->isPosted()) {
            throw new \Exception('Cannot post to ledger: Journal entry is not posted');
        }

        DB::transaction(function () use ($journalEntry) {
            // Delete any existing GL entries for this journal entry (in case of re-posting)
            GeneralLedger::where('journal_entry_id', $journalEntry->id)->delete();

            // Create GL entries for each journal line
            foreach ($journalEntry->lines as $line) {
                $this->createGLEntry($journalEntry, $line);
            }

            // Update account balances
            $this->updateAccountBalances($journalEntry);
        });
    }

    /**
     * Create a general ledger entry for a journal line
     *
     * @param JournalEntry $journalEntry
     * @param JournalLine $line
     * @return GeneralLedger
     */
    protected function createGLEntry(JournalEntry $journalEntry, JournalLine $line): GeneralLedger
    {
        $account = $line->account;
        $previousBalance = $this->getPreviousBalance($account, $journalEntry->date);
        $newBalance = $this->calculateNewBalance($account, $previousBalance, $line->debit, $line->credit);

        return GeneralLedger::create([
            'company_id' => $journalEntry->company_id,
            'account_id' => $line->account_id,
            'journal_line_id' => $line->id,
            'journal_entry_id' => $journalEntry->id,
            'date' => $journalEntry->date,
            'entry_number' => $journalEntry->entry_number,
            'description' => $line->description ?? $journalEntry->description,
            'debit' => $line->debit,
            'credit' => $line->credit,
            'balance' => $newBalance,
            'currency_id' => $line->currency_id,
            'exchange_rate' => $line->exchange_rate,
        ]);
    }

    /**
     * Get the previous balance for an account before a given date
     *
     * @param Account $account
     * @param mixed $date
     * @return float
     */
    protected function getPreviousBalance(Account $account, $date): float
    {
        $lastEntry = GeneralLedger::where('account_id', $account->id)
            ->where('date', '<=', $date)
            ->orderBy('date', 'desc')
            ->orderBy('id', 'desc')
            ->first();

        if ($lastEntry) {
            return (float) $lastEntry->balance;
        }

        return (float) $account->opening_balance;
    }

    /**
     * Calculate new balance based on account type
     *
     * For debit accounts (Assets, Expenses):
     *   Balance increases with debits, decreases with credits
     *
     * For credit accounts (Liabilities, Equity, Income):
     *   Balance increases with credits, decreases with debits
     *
     * @param Account $account
     * @param float $previousBalance
     * @param float $debit
     * @param float $credit
     * @return float
     */
    protected function calculateNewBalance(Account $account, float $previousBalance, float $debit, float $credit): float
    {
        if ($account->isDebitAccount()) {
            // Assets and Expenses: Debits increase, Credits decrease
            return bcadd(bcsub($previousBalance, $credit, 4), $debit, 4);
        } else {
            // Liabilities, Equity, Income: Credits increase, Debits decrease
            return bcadd(bcsub($previousBalance, $debit, 4), $credit, 4);
        }
    }

    /**
     * Update account current balances after posting
     *
     * @param JournalEntry $journalEntry
     * @return void
     */
    protected function updateAccountBalances(JournalEntry $journalEntry): void
    {
        $accountIds = $journalEntry->lines->pluck('account_id')->unique();

        foreach ($accountIds as $accountId) {
            $this->recalculateAccountBalance($accountId);
        }
    }

    /**
     * Recalculate and update an account's current balance
     *
     * @param int $accountId
     * @return void
     */
    public function recalculateAccountBalance(int $accountId): void
    {
        $account = Account::findOrFail($accountId);

        // Get the latest GL entry for this account
        $latestEntry = GeneralLedger::where('account_id', $accountId)
            ->orderBy('date', 'desc')
            ->orderBy('id', 'desc')
            ->first();

        $newBalance = $latestEntry ? $latestEntry->balance : $account->opening_balance;

        $account->update(['current_balance' => $newBalance]);
    }

    /**
     * Unpost journal entry from general ledger
     *
     * Removes GL entries and recalculates affected account balances.
     *
     * @param JournalEntry $journalEntry
     * @return void
     */
    public function unpostFromLedger(JournalEntry $journalEntry): void
    {
        DB::transaction(function () use ($journalEntry) {
            // Get affected account IDs before deleting
            $accountIds = $journalEntry->lines->pluck('account_id')->unique();

            // Delete GL entries
            GeneralLedger::where('journal_entry_id', $journalEntry->id)->delete();

            // Recalculate balances for affected accounts
            foreach ($accountIds as $accountId) {
                $this->recalculateAccountBalance($accountId);
            }
        });
    }

    /**
     * Recalculate all running balances for an account
     *
     * Used when entries are inserted/deleted in the middle of the ledger.
     *
     * @param int $accountId
     * @return void
     */
    public function recalculateRunningBalances(int $accountId): void
    {
        $account = Account::findOrFail($accountId);

        DB::transaction(function () use ($account) {
            $entries = GeneralLedger::where('account_id', $account->id)
                ->orderBy('date')
                ->orderBy('id')
                ->get();

            $runningBalance = (float) $account->opening_balance;

            foreach ($entries as $entry) {
                $runningBalance = $this->calculateNewBalance(
                    $account,
                    $runningBalance,
                    (float) $entry->debit,
                    (float) $entry->credit
                );

                $entry->update(['balance' => $runningBalance]);
            }

            // Update account current balance
            $account->update(['current_balance' => $runningBalance]);
        });
    }

    /**
     * Get account balance as of a specific date
     *
     * @param int $accountId
     * @param string|\DateTime $date
     * @return float
     */
    public function getBalanceAsOf(int $accountId, $date): float
    {
        $account = Account::findOrFail($accountId);

        $dateString = $date instanceof \DateTime ? $date->format('Y-m-d') : $date;

        $entry = GeneralLedger::where('account_id', $accountId)
            ->where('date', '<=', $dateString)
            ->orderBy('date', 'desc')
            ->orderBy('id', 'desc')
            ->first();

        return $entry ? (float) $entry->balance : (float) $account->opening_balance;
    }

    /**
     * Get trial balance as of a specific date
     *
     * @param int $companyId
     * @param string|\DateTime $date
     * @return array
     */
    public function getTrialBalance(int $companyId, $date): array
    {
        $dateString = $date instanceof \DateTime ? $date->format('Y-m-d') : $date;

        $accounts = Account::where('company_id', $companyId)
            ->where('is_active', true)
            ->orderBy('code')
            ->get();

        $trialBalance = [];
        $totalDebits = 0;
        $totalCredits = 0;

        foreach ($accounts as $account) {
            $balance = $this->getBalanceAsOf($account->id, $dateString);

            if ($balance == 0) {
                continue; // Skip zero balance accounts
            }

            $debit = 0;
            $credit = 0;

            if ($account->isDebitAccount()) {
                if ($balance > 0) {
                    $debit = $balance;
                } else {
                    $credit = abs($balance);
                }
            } else {
                if ($balance > 0) {
                    $credit = $balance;
                } else {
                    $debit = abs($balance);
                }
            }

            $trialBalance[] = [
                'account_id' => $account->id,
                'account_code' => $account->code,
                'account_name' => $account->name,
                'account_type' => $account->type,
                'debit' => $debit,
                'credit' => $credit,
            ];

            $totalDebits += $debit;
            $totalCredits += $credit;
        }

        return [
            'date' => $dateString,
            'accounts' => $trialBalance,
            'total_debits' => $totalDebits,
            'total_credits' => $totalCredits,
            'is_balanced' => bccomp($totalDebits, $totalCredits, 4) === 0,
        ];
    }
}
