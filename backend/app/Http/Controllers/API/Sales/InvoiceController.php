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
        $query = Invoice::with(['customer', 'currency'])
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
        $invoice = Invoice::with(['customer', 'currency', 'lines.account', 'payments', 'journalEntry'])
            ->findOrFail($id);

        return response()->json(['invoice' => $invoice]);
    }

    /**
     * Create invoice
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'company_id'           => 'required|exists:companies,id',
            'customer_id'          => 'required|exists:customers,id',
            'date'                 => 'required|date',
            'due_date'             => 'nullable|date|after_or_equal:date',
            'currency_id'          => 'required|exists:currencies,id',
            'lines'                => 'required|array|min:1',
            'lines.*.account_id'   => 'required|exists:accounts,id',
            'lines.*.description'  => 'required|string',
            'lines.*.quantity'     => 'required|numeric|min:0.01',
            'lines.*.unit_price'   => 'required|numeric|min:0',
            'lines.*.tax_rate'     => 'nullable|numeric|min:0|max:100',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        try {
            DB::beginTransaction();

            $invoice = Invoice::create($request->only([
                'company_id', 'customer_id', 'date', 'due_date',
                'reference', 'notes', 'terms', 'currency_id', 'exchange_rate',
            ]));

            foreach ($request->lines as $lineData) {
                $invoice->lines()->create($lineData);
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
        $invoice = Invoice::findOrFail($id);

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
        $invoice = Invoice::findOrFail($id);

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
        $invoice = Invoice::findOrFail($id);

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
        $invoice = Invoice::findOrFail($id);

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
        $invoice = Invoice::with(['customer', 'lines.account', 'company'])->findOrFail($id);

        return response()->json(['message' => 'PDF generation not yet implemented', 'invoice' => $invoice]);
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
