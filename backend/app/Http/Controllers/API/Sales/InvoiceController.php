<?php

namespace App\Http\Controllers\API\Sales;

use App\Http\Controllers\Controller;
use App\Models\Sales\Invoice;
use App\Services\Accounting\DoubleEntryService;
use App\Services\Sync\EventSourceService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class InvoiceController extends Controller
{
    public function __construct(
        protected DoubleEntryService $doubleEntryService,
        protected EventSourceService $eventSourceService,
    ) {}

    /**
     * Get all invoices
     */
    public function index(Request $request)
    {
        $query = Invoice::with(['customer', 'currency', 'lines.account'])
            ->orderByDesc('date')
            ->orderByDesc('created_at');

        if ($request->has('status')) {
            $query->where('status', $request->status);
        }
        if ($request->has('customer_id')) {
            $query->where('customer_id', $request->customer_id);
        }
        if ($request->has('start_date')) {
            $query->where('date', '>=', $request->start_date);
        }
        if ($request->has('end_date')) {
            $query->where('date', '<=', $request->end_date);
        }
        if ($request->boolean('unpaid_only')) {
            $query->unpaid();
        }

        $perPage = $request->input('per_page', 20);
        return response()->json($query->paginate($perPage));
    }

    /**
     * Get single invoice
     */
    public function show($id)
    {
        $invoice = $this->resolveInvoice($id, ['customer', 'currency', 'lines.account', 'payments', 'journalEntry']);
        if (! $invoice) {
            return response()->json(['message' => 'Invoice not found'], 404);
        }

        return response()->json(['invoice' => $invoice]);
    }

    /**
     * Create invoice
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            // company_id / currency_id optional: desktop sends currency_code, no company_id.
            'company_id'           => 'nullable|exists:companies,id',
            'customer_id'          => 'required',
            'date'                 => 'required|date',
            'due_date'             => 'nullable|date',
            'currency_id'          => 'nullable|exists:currencies,id',
            'currency_code'        => 'nullable|string|size:3',
            'lines'                => 'required|array|min:1',
            // account_id may be an integer PK or desktop code like "acct-125".
            'lines.*.account_id'   => 'required',
            'lines.*.description'  => 'nullable|string',
            // quantity / unit_price optional: desktop may send amount only.
            'lines.*.quantity'     => 'nullable|numeric|min:0',
            'lines.*.unit_price'   => 'nullable|numeric|min:0',
            'lines.*.amount'       => 'nullable|numeric|min:0',
            'lines.*.tax_rate'     => 'nullable|numeric|min:0|max:100',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        try {
            DB::beginTransaction();

            $companyId  = $request->company_id ?? \App\Models\Company::first()?->id;
            $currencyId = $request->currency_id
                ?? \App\Models\Currency::where('code', $request->currency_code ?? 'UGX')->value('id')
                ?? \App\Models\Currency::first()?->id;

            // Resolve customer: integer PK or string key.
            $rawCustomerId = $request->customer_id;
            $customerId    = ctype_digit((string) $rawCustomerId)
                ? (int) $rawCustomerId
                : \App\Models\Sales\Customer::where('id', $rawCustomerId)->value('id');
            if (! $customerId) {
                DB::rollBack();
                return response()->json(['message' => "Customer '{$rawCustomerId}' not found"], 422);
            }

            // Idempotency: if the desktop already pushed this UUID, return the
            // existing record instead of creating a duplicate.
            $clientUuid = $request->input('id');
            if ($clientUuid) {
                $existing = Invoice::where('client_uuid', $clientUuid)->first();
                if ($existing) {
                    DB::rollBack();
                    $fresh = $existing->fresh(['lines', 'customer']);
                    return response()->json(['message' => 'Invoice created successfully', 'invoice' => $fresh], 201);
                }
            }

            $invoice = Invoice::create([
                'company_id'   => $companyId,
                'customer_id'  => $customerId,
                'client_uuid'  => $clientUuid,
                'date'         => $request->date,
                'due_date'     => $request->due_date,
                'reference'    => $request->reference,
                'notes'        => $request->notes,
                'terms'        => $request->terms,
                'currency_id'  => $currencyId,
                'exchange_rate'=> $request->exchange_rate ?? 1,
            ]);

            foreach ($request->lines as $lineData) {
                // Resolve account: integer PK or "acct-NNN" / "NNN" code string.
                $rawAcctId = $lineData['account_id'];
                $code      = str_starts_with((string) $rawAcctId, 'acct-')
                    ? substr($rawAcctId, 5)
                    : (string) $rawAcctId;
                $account   = ctype_digit($code)
                    ? (\App\Models\Accounting\Account::find((int) $code)
                        ?? \App\Models\Accounting\Account::where('code', $code)->firstOrFail())
                    : \App\Models\Accounting\Account::where('code', $code)->firstOrFail();

                $amount    = (float) ($lineData['amount']
                    ?? (($lineData['unit_price'] ?? 0) * ($lineData['quantity'] ?? 1)));
                $quantity  = (float) ($lineData['quantity'] ?? 1);
                $unitPrice = $quantity > 0
                    ? (float) ($lineData['unit_price'] ?? ($amount / $quantity))
                    : 0.0;

                $invoice->lines()->create([
                    'account_id'  => $account->id,
                    'description' => $lineData['description'] ?? $account->name ?? '',
                    'quantity'    => $quantity,
                    'unit_price'  => $unitPrice,
                    'tax_rate'    => $lineData['tax_rate'] ?? 0,
                ]);
            }

            $invoice->calculateTotals();
            $invoice->save();

            if ($request->boolean('create_journal_entry')) {
                $journalEntry = $this->doubleEntryService->createInvoiceJournalEntry(
                    $invoice, $request->user(), $request->boolean('auto_post', false)
                );
                $invoice->journal_entry_id = $journalEntry->id;
                $invoice->save();
            }

            DB::commit();

            $fresh = $invoice->fresh(['lines', 'customer']);
            $this->emitEvent('invoice.created', $invoice->id, $fresh->toArray());

            return response()->json(['message' => 'Invoice created successfully', 'invoice' => $fresh], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['message' => 'Failed to create invoice', 'error' => $e->getMessage()], 400);
        }
    }

    /**
     * Update invoice
     */
    public function update(Request $request, $id)
    {
        $invoice = $this->resolveInvoice($id);
        if (! $invoice) {
            return response()->json(['message' => 'Invoice not found'], 404);
        }

        if (!in_array($invoice->status, [Invoice::STATUS_DRAFT])) {
            return response()->json(['message' => 'Only draft invoices can be modified'], 403);
        }

        $validator = Validator::make($request->all(), [
            'date'      => 'sometimes|date',
            'due_date'  => 'nullable|date',
            'reference' => 'nullable|string',
            'notes'     => 'nullable|string',
            'terms'     => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $invoice->update($request->all());
        $fresh = $invoice->fresh(['lines', 'customer']);
        $this->emitEvent('invoice.updated', $invoice->id, $fresh->toArray());

        return response()->json(['message' => 'Invoice updated successfully', 'invoice' => $fresh]);
    }

    /**
     * Delete invoice
     */
    public function destroy($id)
    {
        $invoice = $this->resolveInvoice($id);
        if (! $invoice) {
            return response()->json(['message' => 'Invoice not found'], 404);
        }

        if ($invoice->status !== Invoice::STATUS_DRAFT) {
            return response()->json(['message' => 'Only draft invoices can be deleted'], 403);
        }

        $this->emitEvent('invoice.deleted', $invoice->id, ['id' => $invoice->id]);
        $invoice->delete();

        return response()->json(['message' => 'Invoice deleted successfully']);
    }

    /**
     * Send invoice to customer
     */
    public function send($id, Request $request)
    {
        $invoice = $this->resolveInvoice($id);
        if (! $invoice) {
            return response()->json(['message' => 'Invoice not found'], 404);
        }

        if ($invoice->status !== Invoice::STATUS_DRAFT) {
            return response()->json(['message' => 'Only draft invoices can be sent'], 400);
        }

        if (!$invoice->journal_entry_id) {
            $journalEntry = $this->doubleEntryService->createInvoiceJournalEntry(
                $invoice, $request->user(), true
            );
            $invoice->journal_entry_id = $journalEntry->id;
        }

        $invoice->markAsSent();
        $this->emitEvent('invoice.updated', $invoice->id, $invoice->fresh()->toArray());

        return response()->json(['message' => 'Invoice sent successfully', 'invoice' => $invoice->fresh()]);
    }

    /**
     * Record payment
     */
    public function recordPayment($id, Request $request)
    {
        $invoice = $this->resolveInvoice($id);
        if (! $invoice) {
            return response()->json(['message' => 'Invoice not found'], 404);
        }

        $validator = Validator::make($request->all(), [
            'amount'             => 'required|numeric|min:0.01',
            'date'               => 'required|date',
            'method'             => 'required|in:cash,bank_transfer,cheque,mobile_money,credit_card,other',
            'deposit_account_id' => 'required|exists:accounts,id',
            'reference'          => 'nullable|string',
            'notes'              => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        if ($request->amount > $invoice->balance) {
            return response()->json(['message' => 'Payment amount exceeds invoice balance'], 400);
        }

        try {
            DB::beginTransaction();

            $payment = $invoice->payments()->create([
                'company_id'         => $invoice->company_id,
                'customer_id'        => $invoice->customer_id,
                'deposit_account_id' => $request->deposit_account_id,
                'date'               => $request->date,
                'amount'             => $request->amount,
                'currency_id'        => $invoice->currency_id,
                'exchange_rate'      => $invoice->exchange_rate,
                'method'             => $request->method,
                'reference'          => $request->reference,
                'notes'              => $request->notes,
                'status'             => 'cleared',
            ]);

            $journalEntry = $this->doubleEntryService->createPaymentReceivedJournalEntry(
                $payment, $request->user(), true
            );
            $payment->journal_entry_id = $journalEntry->id;
            $payment->save();

            DB::commit();

            $this->emitEvent('payment.created', $payment->id, array_merge(
                $payment->toArray(), ['invoice_id' => $invoice->id]
            ));

            return response()->json([
                'message' => 'Payment recorded successfully',
                'payment' => $payment,
                'invoice' => $invoice->fresh(),
            ], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['message' => 'Failed to record payment', 'error' => $e->getMessage()], 400);
        }
    }

    /**
     * Download invoice PDF
     */
    public function downloadPdf($id)
    {
        $invoice = $this->resolveInvoice($id, ['customer', 'lines.account', 'company']);
        if (! $invoice) {
            return response()->json(['message' => 'Invoice not found'], 404);
        }

        return response()->json(['message' => 'PDF generation not yet implemented', 'invoice' => $invoice]);
    }

    /**
     * Resolve an Invoice by integer PK or by client_uuid.
     * Desktop clients route PUT/DELETE to /invoices/{uuid}; the uuid is stored
     * in client_uuid so both paths resolve the same record.
     */
    private function resolveInvoice(mixed $id, array $with = []): ?Invoice
    {
        $query = Invoice::query();
        if ($with) {
            $query->with($with);
        }
        return $query->where('id', $id)
            ->orWhere('client_uuid', $id)
            ->first();
    }

    private function emitEvent(string $eventType, string $aggregateId, array $data): void
    {
        try {
            $this->eventSourceService->createEvent('invoice', $aggregateId, $eventType, $data);
        } catch (\Throwable) {
            // Non-critical: never fail a REST response because of a sync event failure.
        }
    }
}
