<?php

namespace App\Http\Controllers\API\Banking;

use App\Http\Controllers\Controller;
use App\Models\Accounting\Account;
use App\Models\Banking\BankStatement;
use App\Models\Banking\BankStatementLine;
use App\Models\Banking\ReconciliationItem;
use App\Models\Purchases\Bill;
use App\Models\Sales\Invoice;
use App\Services\Accounting\DoubleEntryService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class BankReconciliationController extends Controller
{
    public function __construct(protected DoubleEntryService $des) {}

    // ─────────────────────────────────────────────────────────────────────────
    // Accounts for reconciliation picker
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Return ALL active accounts regardless of type, so the CoA picker
     * in the bank reconciliation screen shows Assets, Liabilities (loans, etc.),
     * Equity, Income, and Expense accounts.
     *
     * GET /banking/reconciliation/accounts
     * Optional: ?search=loan   ?type=liability
     */
    public function accounts(Request $request)
    {
        $query = Account::with(['currency', 'parent'])
            ->where('is_active', true)
            ->orderBy('type')
            ->orderBy('code');

        // Allow optional type filter but do NOT apply one by default
        if ($request->has('type')) {
            $query->whereIn('type', (array) $request->type);
        }

        if ($request->has('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                  ->orWhere('code', 'like', "%{$search}%");
            });
        }

        return response()->json([
            'accounts' => $query->get(),
        ]);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Items available to reconcile against
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Return open bills and invoices (and optionally outlet AR items) that
     * can be matched against a bank statement line.
     *
     * GET /banking/reconciliation/items
     * Optional: ?type=bill|invoice  ?amount_from=x  ?amount_to=y  ?date_from=  ?date_to=
     */
    public function availableItems(Request $request)
    {
        $type   = $request->input('type');
        $result = [];

        if (!$type || $type === 'bill') {
            $billQuery = Bill::with(['vendor', 'currency'])
                ->whereIn('status', [Bill::STATUS_APPROVED, Bill::STATUS_PARTIAL, Bill::STATUS_OVERDUE])
                ->where('balance', '>', 0)
                ->orderBy('due_date');

            if ($request->has('amount_from')) {
                $billQuery->where('balance', '>=', $request->amount_from);
            }
            if ($request->has('amount_to')) {
                $billQuery->where('balance', '<=', $request->amount_to);
            }
            if ($request->has('date_from')) {
                $billQuery->where('date', '>=', $request->date_from);
            }
            if ($request->has('date_to')) {
                $billQuery->where('date', '<=', $request->date_to);
            }
            if ($request->has('vendor_id')) {
                $billQuery->where('vendor_id', $request->vendor_id);
            }

            foreach ($billQuery->get() as $bill) {
                $result[] = [
                    'type'        => 'bill',
                    'id'          => $bill->id,
                    'number'      => $bill->bill_number,
                    'label'       => "Bill {$bill->bill_number} — {$bill->vendor->name}",
                    'date'        => $bill->date,
                    'due_date'    => $bill->due_date,
                    'total'       => $bill->total,
                    'paid_amount' => $bill->paid_amount,
                    'balance'     => $bill->balance,
                    'currency'    => $bill->currency->code,
                    'status'      => $bill->status,
                ];
            }
        }

        if (!$type || $type === 'invoice') {
            $invQuery = Invoice::with(['customer', 'currency'])
                ->whereIn('status', [Invoice::STATUS_SENT, Invoice::STATUS_PARTIAL, Invoice::STATUS_OVERDUE])
                ->where('balance', '>', 0)
                ->orderBy('due_date');

            if ($request->has('amount_from')) {
                $invQuery->where('balance', '>=', $request->amount_from);
            }
            if ($request->has('amount_to')) {
                $invQuery->where('balance', '<=', $request->amount_to);
            }
            if ($request->has('date_from')) {
                $invQuery->where('date', '>=', $request->date_from);
            }
            if ($request->has('date_to')) {
                $invQuery->where('date', '<=', $request->date_to);
            }
            if ($request->has('customer_id')) {
                $invQuery->where('customer_id', $request->customer_id);
            }

            foreach ($invQuery->get() as $inv) {
                $result[] = [
                    'type'        => 'invoice',
                    'id'          => $inv->id,
                    'number'      => $inv->invoice_number,
                    'label'       => "Invoice {$inv->invoice_number} — {$inv->customer->name}",
                    'date'        => $inv->date,
                    'due_date'    => $inv->due_date,
                    'total'       => $inv->total,
                    'paid_amount' => $inv->paid_amount,
                    'balance'     => $inv->balance,
                    'currency'    => $inv->currency->code,
                    'status'      => $inv->status,
                ];
            }
        }

        return response()->json(['items' => $result]);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Reconcile one statement line → one or many bills / invoices
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Link a bank statement line to one or more bills/invoices with per-item
     * amount allocations.  Supports:
     *   - One statement line paying several bills at once
     *   - Partial bill/invoice payments (amount < outstanding balance)
     *
     * POST /banking/statements/{statementId}/lines/{lineId}/reconcile
     * Body JSON:
     * {
     *   "items": [
     *     { "type": "bill",    "id": 12, "amount": 500000 },
     *     { "type": "bill",    "id": 17, "amount": 300000 },
     *     { "type": "invoice", "id": 5,  "amount": 200000 }
     *   ],
     *   "bank_account_id": 3    // CoA account representing the bank (required for JE)
     * }
     */
    public function reconcile(Request $request, $statementId, $lineId)
    {
        $statement = BankStatement::findOrFail($statementId);
        $line      = BankStatementLine::where('bank_statement_id', $statementId)->findOrFail($lineId);

        $validator = Validator::make($request->all(), [
            'items'                => 'required|array|min:1',
            'items.*.type'         => 'required|in:bill,invoice',
            'items.*.id'           => 'required|integer|min:1',
            'items.*.amount'       => 'required|numeric|min:0.01',
            'items.*.notes'        => 'nullable|string',
            'bank_account_id'      => 'required|exists:accounts,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        // Guard: total allocated must not exceed the unreconciled amount on the line
        $totalRequested = collect($request->items)->sum('amount');
        $remaining      = $line->remaining_amount;

        if (bccomp((string) $totalRequested, (string) $remaining, 4) > 0) {
            return response()->json([
                'message' => "Total allocated amount ({$totalRequested}) exceeds remaining unreconciled amount ({$remaining}) on this statement line.",
            ], 422);
        }

        try {
            DB::beginTransaction();

            $bankAccount = Account::findOrFail($request->bank_account_id);
            $created     = [];

            foreach ($request->items as $itemData) {
                [$model, $record] = $this->resolveItem($itemData['type'], $itemData['id']);
                $amount = (float) $itemData['amount'];

                // Guard: amount must not exceed the item's outstanding balance
                if (bccomp((string) $amount, (string) $record->balance, 4) > 0) {
                    throw new \Exception(
                        "Allocated amount {$amount} exceeds outstanding balance {$record->balance} on {$itemData['type']} #{$itemData['id']}"
                    );
                }

                // Create the journal entry that records this payment
                $je = $this->createReconciliationJournalEntry(
                    $itemData['type'],
                    $record,
                    $bankAccount,
                    $amount,
                    $line->date,
                    $request->user(),
                    $statement
                );

                // Update the bill/invoice paid_amount and balance
                $record->recordPayment($amount);

                // Record the reconciliation link
                $item = ReconciliationItem::create([
                    'company_id'            => $statement->company_id,
                    'bank_statement_line_id' => $line->id,
                    'reconcilable_type'     => $model,
                    'reconcilable_id'       => $record->id,
                    'amount'                => $amount,
                    'notes'                 => $itemData['notes'] ?? null,
                    'journal_entry_id'      => $je->id,
                    'created_by'            => $request->user()?->id,
                ]);

                $created[] = $item->load('reconcilable');
            }

            // Update statement line reconciled amount + status
            $line->addReconciliation($totalRequested);

            // Refresh parent statement status
            $statement->refreshStatus();

            DB::commit();

            return response()->json([
                'message'    => count($created) . ' item(s) reconciled successfully',
                'items'      => $created,
                'line'       => $line->fresh(),
                'statement'  => $statement->fresh(),
            ], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['message' => $e->getMessage()], 400);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Unreconcile a single reconciliation item
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Remove a reconciliation item (reverse the payment and JE).
     *
     * DELETE /banking/reconciliation-items/{itemId}
     */
    public function unreconcile($itemId)
    {
        $item = ReconciliationItem::with(['statementLine.statement', 'reconcilable'])->findOrFail($itemId);

        try {
            DB::beginTransaction();

            $record = $item->reconcilable;
            $amount = (float) $item->amount;

            // Reverse the payment on the bill/invoice
            if ($record && method_exists($record, 'reversePayment')) {
                $record->reversePayment($amount);
            } elseif ($record) {
                // Manual reversal: reduce paid_amount, recalculate balance, reset status
                $record->paid_amount = max(0, $record->paid_amount - $amount);
                $record->balance     = $record->total - $record->paid_amount;

                if ($record->paid_amount <= 0) {
                    $type = get_class($record);
                    $record->status = str_contains($type, 'Bill')
                        ? Bill::STATUS_APPROVED
                        : Invoice::STATUS_SENT;
                    $record->paid_at = null;
                } elseif ($record->paid_amount > 0) {
                    $type = get_class($record);
                    $record->status = str_contains($type, 'Bill')
                        ? Bill::STATUS_PARTIAL
                        : Invoice::STATUS_PARTIAL;
                }
                $record->save();
            }

            // Unpost and delete the journal entry if it exists and is posted
            if ($item->journalEntry) {
                if ($item->journalEntry->isPosted()) {
                    $item->journalEntry->unpost();
                }
                $item->journalEntry->delete();
            }

            // Reduce the line's reconciled amount
            $item->statementLine->removeReconciliation($amount);

            // Delete the reconciliation item
            $item->delete();

            // Refresh parent statement
            $item->statementLine->statement->refreshStatus();

            DB::commit();

            return response()->json(['message' => 'Reconciliation reversed successfully']);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['message' => $e->getMessage()], 400);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    private function resolveItem(string $type, int $id): array
    {
        return match ($type) {
            'bill'    => [Bill::class,    Bill::findOrFail($id)],
            'invoice' => [Invoice::class, Invoice::findOrFail($id)],
            default   => throw new \InvalidArgumentException("Unknown reconcilable type: {$type}"),
        };
    }

    /**
     * Build the appropriate journal entry for a reconciliation payment.
     *
     * Bill reconciliation  = money leaves the bank → DR Accounts Payable, CR Bank
     * Invoice reconciliation = money enters the bank → DR Bank, CR Accounts Receivable
     */
    private function createReconciliationJournalEntry(
        string $type,
        $record,
        Account $bankAccount,
        float $amount,
        $date,
        $user,
        BankStatement $statement
    ) {
        $company = $record->company;
        $number  = $type === 'bill' ? $record->bill_number : $record->invoice_number;

        if ($type === 'bill') {
            // Pay a bill from the bank account
            $apAccount = $this->getAccountByCategory($company, 'accounts_payable');

            return $this->des->createJournalEntry(
                $company,
                [
                    'date'        => $date,
                    'reference'   => "RECON-{$statement->id}-{$number}",
                    'description' => "Bank reconciliation payment for {$number}",
                    'type'        => \App\Models\Accounting\JournalEntry::TYPE_AUTOMATIC,
                    'source'      => 'bank_reconciliation',
                    'source_id'   => $record->id,
                    'lines'       => [
                        ['account_id' => $apAccount->id,   'debit' => $amount, 'credit' => 0,      'description' => "AP payment — {$number}"],
                        ['account_id' => $bankAccount->id, 'debit' => 0,       'credit' => $amount, 'description' => "Bank — {$statement->bankAccount->name}"],
                    ],
                ],
                $user,
                true
            );
        }

        // Receive invoice payment into the bank account
        $arAccount = $this->getAccountByCategory($company, 'accounts_receivable');

        return $this->des->createJournalEntry(
            $company,
            [
                'date'        => $date,
                'reference'   => "RECON-{$statement->id}-{$number}",
                'description' => "Bank reconciliation receipt for {$number}",
                'type'        => \App\Models\Accounting\JournalEntry::TYPE_AUTOMATIC,
                'source'      => 'bank_reconciliation',
                'source_id'   => $record->id,
                'lines'       => [
                    ['account_id' => $bankAccount->id, 'debit' => $amount, 'credit' => 0,      'description' => "Bank — {$statement->bankAccount->name}"],
                    ['account_id' => $arAccount->id,   'debit' => 0,       'credit' => $amount, 'description' => "AR receipt — {$number}"],
                ],
            ],
            $user,
            true
        );
    }

    private function getAccountByCategory($company, string $category): Account
    {
        $account = Account::where('company_id', $company->id)
            ->where('category', $category)
            ->where('is_active', true)
            ->first();

        if (!$account) {
            throw new \Exception("No active account found for category '{$category}'. Please set up your Chart of Accounts.");
        }

        return $account;
    }
}
