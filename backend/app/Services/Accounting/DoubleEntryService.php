<?php

namespace App\Services\Accounting;

use App\Models\Accounting\Account;
use App\Models\Accounting\JournalEntry;
use App\Models\Accounting\JournalLine;
use App\Models\Company;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Double-Entry Bookkeeping Service
 *
 * This is the core accounting engine that ensures all transactions
 * follow double-entry bookkeeping principles:
 * - Every transaction has equal debits and credits
 * - Assets = Liabilities + Equity
 * - Revenue - Expenses = Net Income
 */
class DoubleEntryService
{
    /**
     * Create a journal entry with lines
     *
     * @param Company $company
     * @param array $data [
     *   'date' => '2024-01-01',
     *   'description' => 'Payment received',
     *   'reference' => 'INV-001',
     *   'type' => 'manual' | 'automatic',
     *   'source' => 'invoice' | 'bill' | 'payment',
     *   'source_id' => 123,
     *   'lines' => [
     *     ['account_id' => 1, 'debit' => 1000, 'credit' => 0, 'description' => '...'],
     *     ['account_id' => 2, 'debit' => 0, 'credit' => 1000, 'description' => '...'],
     *   ]
     * ]
     * @param User $user
     * @param bool $autoPost
     * @return JournalEntry
     */
    public function createJournalEntry(
        Company $company,
        array $data,
        User $user,
        bool $autoPost = false
    ): JournalEntry {
        return DB::transaction(function () use ($company, $data, $user, $autoPost) {
            // Generate entry number
            $entryNumber = $this->generateEntryNumber($company, $data['date'] ?? now());

            // Create journal entry
            $journalEntry = JournalEntry::create([
                'company_id' => $company->id,
                'entry_number' => $entryNumber,
                'date' => $data['date'] ?? now(),
                'reference' => $data['reference'] ?? null,
                'description' => $data['description'] ?? null,
                'type' => $data['type'] ?? JournalEntry::TYPE_MANUAL,
                'source' => $data['source'] ?? null,
                'source_id' => $data['source_id'] ?? null,
                'status' => JournalEntry::STATUS_DRAFT,
                'created_by' => $user->id,
            ]);

            // Add lines
            if (!empty($data['lines'])) {
                $this->addLines($journalEntry, $data['lines']);
            }

            // Validate balance
            if (!$journalEntry->isBalanced()) {
                throw new \Exception(
                    "Journal entry must balance. Debits: {$journalEntry->getTotalDebits()}, " .
                    "Credits: {$journalEntry->getTotalCredits()}"
                );
            }

            // Auto-post if requested
            if ($autoPost) {
                $journalEntry->post($user);
            }

            return $journalEntry->fresh('lines');
        });
    }

    /**
     * Add lines to journal entry
     */
    public function addLines(JournalEntry $journalEntry, array $lines): void
    {
        foreach ($lines as $index => $lineData) {
            $account = Account::findOrFail($lineData['account_id']);
            $currency = $account->currency;

            JournalLine::create([
                'journal_entry_id' => $journalEntry->id,
                'account_id' => $account->id,
                'description' => $lineData['description'] ?? null,
                'debit' => $lineData['debit'] ?? 0,
                'credit' => $lineData['credit'] ?? 0,
                'currency_id' => $currency->id,
                'exchange_rate' => $lineData['exchange_rate'] ?? 1,
                'debit_foreign' => $lineData['debit_foreign'] ?? ($lineData['debit'] ?? 0),
                'credit_foreign' => $lineData['credit_foreign'] ?? ($lineData['credit'] ?? 0),
                'order' => $index,
            ]);
        }
    }

    /**
     * Create journal entry for invoice
     */
    public function createInvoiceJournalEntry(
        $invoice,
        User $user,
        bool $autoPost = true
    ): JournalEntry {
        $company = $invoice->company;
        $arAccount = $this->getAccountReceivableAccount($company);

        $lines = [
            // Debit: Accounts Receivable
            [
                'account_id' => $arAccount->id,
                'debit' => $invoice->total,
                'credit' => 0,
                'description' => "Invoice {$invoice->invoice_number} - {$invoice->customer->name}",
            ],
        ];

        // Credit: Income accounts (from invoice lines)
        foreach ($invoice->lines as $line) {
            if ($line->account_id) {
                $lines[] = [
                    'account_id' => $line->account_id,
                    'debit' => 0,
                    'credit' => $line->amount - $line->tax_amount,
                    'description' => $line->description,
                ];
            }
        }

        // Credit: Tax account (if applicable)
        if ($invoice->tax_amount > 0) {
            $taxAccount = $this->getTaxPayableAccount($company);
            $lines[] = [
                'account_id' => $taxAccount->id,
                'debit' => 0,
                'credit' => $invoice->tax_amount,
                'description' => 'VAT on ' . $invoice->invoice_number,
            ];
        }

        return $this->createJournalEntry(
            $company,
            [
                'date' => $invoice->date,
                'reference' => $invoice->invoice_number,
                'description' => "Invoice to {$invoice->customer->name}",
                'type' => JournalEntry::TYPE_AUTOMATIC,
                'source' => 'invoice',
                'source_id' => $invoice->id,
                'lines' => $lines,
            ],
            $user,
            $autoPost
        );
    }

    /**
     * Create journal entry for payment received
     */
    public function createPaymentReceivedJournalEntry(
        $payment,
        User $user,
        bool $autoPost = true
    ): JournalEntry {
        $company = $payment->company;
        $arAccount = $this->getAccountReceivableAccount($company);

        return $this->createJournalEntry(
            $company,
            [
                'date' => $payment->date,
                'reference' => $payment->payment_number,
                'description' => "Payment from {$payment->customer->name}",
                'type' => JournalEntry::TYPE_AUTOMATIC,
                'source' => 'payment',
                'source_id' => $payment->id,
                'lines' => [
                    // Debit: Bank/Cash account
                    [
                        'account_id' => $payment->deposit_account_id,
                        'debit' => $payment->amount,
                        'credit' => 0,
                        'description' => "Payment via {$payment->method}",
                    ],
                    // Credit: Accounts Receivable
                    [
                        'account_id' => $arAccount->id,
                        'debit' => 0,
                        'credit' => $payment->amount,
                        'description' => "Payment for invoice {$payment->invoice->invoice_number}",
                    ],
                ],
            ],
            $user,
            $autoPost
        );
    }

    /**
     * Create journal entry for bill
     */
    public function createBillJournalEntry(
        $bill,
        User $user,
        bool $autoPost = true
    ): JournalEntry {
        $company = $bill->company;
        $apAccount = $this->getAccountPayableAccount($company);

        $lines = [];

        // Debit: Expense accounts (from bill lines)
        foreach ($bill->lines as $line) {
            if ($line->account_id) {
                $lines[] = [
                    'account_id' => $line->account_id,
                    'debit' => $line->amount - $line->tax_amount,
                    'credit' => 0,
                    'description' => $line->description,
                ];
            }
        }

        // Debit: Tax account (if applicable)
        if ($bill->tax_amount > 0) {
            $taxAccount = $this->getTaxReceivableAccount($company);
            $lines[] = [
                'account_id' => $taxAccount->id,
                'debit' => $bill->tax_amount,
                'credit' => 0,
                'description' => 'VAT on ' . $bill->bill_number,
            ];
        }

        // Credit: Accounts Payable
        $lines[] = [
            'account_id' => $apAccount->id,
            'debit' => 0,
            'credit' => $bill->total,
            'description' => "Bill {$bill->bill_number} - {$bill->vendor->name}",
        ];

        return $this->createJournalEntry(
            $company,
            [
                'date' => $bill->date,
                'reference' => $bill->bill_number,
                'description' => "Bill from {$bill->vendor->name}",
                'type' => JournalEntry::TYPE_AUTOMATIC,
                'source' => 'bill',
                'source_id' => $bill->id,
                'lines' => $lines,
            ],
            $user,
            $autoPost
        );
    }

    /**
     * Create journal entry for bill payment
     */
    public function createBillPaymentJournalEntry(
        $billPayment,
        User $user,
        bool $autoPost = true
    ): JournalEntry {
        $company = $billPayment->company;
        $apAccount = $this->getAccountPayableAccount($company);

        return $this->createJournalEntry(
            $company,
            [
                'date' => $billPayment->date,
                'reference' => $billPayment->payment_number,
                'description' => "Payment to {$billPayment->vendor->name}",
                'type' => JournalEntry::TYPE_AUTOMATIC,
                'source' => 'bill_payment',
                'source_id' => $billPayment->id,
                'lines' => [
                    // Debit: Accounts Payable
                    [
                        'account_id' => $apAccount->id,
                        'debit' => $billPayment->amount,
                        'credit' => 0,
                        'description' => "Payment for bill {$billPayment->bill->bill_number}",
                    ],
                    // Credit: Bank/Cash account
                    [
                        'account_id' => $billPayment->payment_account_id,
                        'debit' => 0,
                        'credit' => $billPayment->amount,
                        'description' => "Payment via {$billPayment->method}",
                    ],
                ],
            ],
            $user,
            $autoPost
        );
    }

    /**
     * Generate journal entry number
     */
    private function generateEntryNumber(Company $company, $date): string
    {
        $year = is_string($date) ? date('Y', strtotime($date)) : $date->format('Y');
        $prefix = "JE-{$year}-";

        $lastEntry = JournalEntry::where('company_id', $company->id)
            ->where('entry_number', 'like', $prefix . '%')
            ->orderByDesc('entry_number')
            ->first();

        if ($lastEntry) {
            $lastNumber = (int) str_replace($prefix, '', $lastEntry->entry_number);
            $newNumber = $lastNumber + 1;
        } else {
            $newNumber = 1;
        }

        return $prefix . str_pad($newNumber, 6, '0', STR_PAD_LEFT);
    }

    /**
     * Get system accounts
     */
    private function getAccountReceivableAccount(Company $company): Account
    {
        return Account::where('company_id', $company->id)
            ->where('category', Account::CATEGORY_ACCOUNTS_RECEIVABLE)
            ->where('is_system', true)
            ->firstOrFail();
    }

    private function getAccountPayableAccount(Company $company): Account
    {
        return Account::where('company_id', $company->id)
            ->where('category', Account::CATEGORY_ACCOUNTS_PAYABLE)
            ->where('is_system', true)
            ->firstOrFail();
    }

    private function getTaxPayableAccount(Company $company): Account
    {
        return Account::where('company_id', $company->id)
            ->where('code', '2100') // Standard tax payable account
            ->where('is_system', true)
            ->firstOrFail();
    }

    private function getTaxReceivableAccount(Company $company): Account
    {
        return Account::where('company_id', $company->id)
            ->where('code', '1160') // Standard tax receivable account
            ->where('is_system', true)
            ->firstOrFail();
    }
}
