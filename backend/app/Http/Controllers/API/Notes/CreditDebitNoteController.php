<?php

namespace App\Http\Controllers\API\Notes;

use App\Http\Controllers\Controller;
use App\Models\Sales\CreditNote;
use App\Models\Purchases\DebitNote;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

/**
 * Credit & Debit Note management.
 *
 * Credit Notes — issued to customers, reduce their invoice balance.
 * Debit Notes  — issued to (or received from) vendors, reduce a bill/payable.
 *
 * All operations are scoped to the authenticated company via BelongsToCompany.
 */
class CreditDebitNoteController extends Controller
{
    // ──────────────────────────────────────────────────────────────────────────
    // CREDIT NOTES
    // ──────────────────────────────────────────────────────────────────────────

    public function indexCredit(Request $request): JsonResponse
    {
        $notes = CreditNote::with('customer')
            ->when($request->customer_id, fn($q) => $q->where('customer_id', $request->customer_id))
            ->when($request->status,      fn($q) => $q->where('status', $request->status))
            ->orderByDesc('date')
            ->get();

        return response()->json(['credit_notes' => $notes]);
    }

    public function storeCredit(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'customer_id'        => 'required|exists:customers,id',
            'invoice_id'         => 'nullable|exists:invoices,id',
            'date'               => 'required|date',
            'amount'             => 'required|numeric|min:0.01',
            'reason'             => 'required|string|max:500',
            'notes'              => 'nullable|string',
            'currency_code'      => 'nullable|string|size:3',
        ]);

        $companyId = $request->input('company_id')
            ?? \App\Models\Company::first()?->id;

        $note = CreditNote::create([
            ...$validated,
            'company_id'         => $companyId,
            'credit_note_number' => $this->nextCreditNoteNumber(),
            'status'             => 'draft',
            'currency_code'      => $validated['currency_code'] ?? 'UGX',
        ]);

        return response()->json(['credit_note' => $note->load('customer')], 201);
    }

    public function showCredit(CreditNote $creditNote): JsonResponse
    {
        return response()->json(['credit_note' => $creditNote->load('customer', 'invoice')]);
    }

    public function updateCredit(Request $request, CreditNote $creditNote): JsonResponse
    {
        if ($creditNote->status === 'applied') {
            return response()->json(['message' => 'Cannot modify an applied credit note.'], 422);
        }

        $validated = $request->validate([
            'date'   => 'sometimes|date',
            'amount' => 'sometimes|numeric|min:0.01',
            'reason' => 'sometimes|string|max:500',
            'notes'  => 'nullable|string',
            'status' => 'sometimes|in:draft,issued,applied,cancelled',
        ]);

        $creditNote->update($validated);

        return response()->json(['credit_note' => $creditNote->fresh()]);
    }

    public function destroyCredit(CreditNote $creditNote): JsonResponse
    {
        if ($creditNote->status === 'applied') {
            return response()->json(['message' => 'Cannot delete an applied credit note.'], 422);
        }

        $creditNote->delete();
        return response()->json(['message' => 'Credit note deleted']);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // DEBIT NOTES
    // ──────────────────────────────────────────────────────────────────────────

    public function indexDebit(Request $request): JsonResponse
    {
        $notes = DebitNote::with('vendor')
            ->when($request->vendor_id, fn($q) => $q->where('vendor_id', $request->vendor_id))
            ->when($request->status,    fn($q) => $q->where('status', $request->status))
            ->orderByDesc('date')
            ->get();

        return response()->json(['debit_notes' => $notes]);
    }

    public function storeDebit(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'vendor_id'     => 'required|exists:vendors,id',
            'bill_id'       => 'nullable|exists:bills,id',
            'date'          => 'required|date',
            'amount'        => 'required|numeric|min:0.01',
            'reason'        => 'required|string|max:500',
            'notes'         => 'nullable|string',
            'currency_code' => 'nullable|string|size:3',
        ]);

        $companyId = $request->input('company_id')
            ?? \App\Models\Company::first()?->id;

        $note = DebitNote::create([
            ...$validated,
            'company_id'        => $companyId,
            'debit_note_number' => $this->nextDebitNoteNumber(),
            'status'            => 'draft',
            'currency_code'     => $validated['currency_code'] ?? 'UGX',
        ]);

        return response()->json(['debit_note' => $note->load('vendor')], 201);
    }

    public function showDebit(DebitNote $debitNote): JsonResponse
    {
        return response()->json(['debit_note' => $debitNote->load('vendor', 'bill')]);
    }

    public function updateDebit(Request $request, DebitNote $debitNote): JsonResponse
    {
        if ($debitNote->status === 'applied') {
            return response()->json(['message' => 'Cannot modify an applied debit note.'], 422);
        }

        $validated = $request->validate([
            'date'   => 'sometimes|date',
            'amount' => 'sometimes|numeric|min:0.01',
            'reason' => 'sometimes|string|max:500',
            'notes'  => 'nullable|string',
            'status' => 'sometimes|in:draft,issued,applied,cancelled',
        ]);

        $debitNote->update($validated);

        return response()->json(['debit_note' => $debitNote->fresh()]);
    }

    public function destroyDebit(DebitNote $debitNote): JsonResponse
    {
        if ($debitNote->status === 'applied') {
            return response()->json(['message' => 'Cannot delete an applied debit note.'], 422);
        }

        $debitNote->delete();
        return response()->json(['message' => 'Debit note deleted']);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────────────────────────────────

    private function nextCreditNoteNumber(): string
    {
        $last = CreditNote::withTrashed()->orderByDesc('id')->value('credit_note_number');
        if (!$last) return 'CN-0001';
        $num = (int) substr($last, 3);
        return 'CN-' . str_pad($num + 1, 4, '0', STR_PAD_LEFT);
    }

    private function nextDebitNoteNumber(): string
    {
        $last = DebitNote::withTrashed()->orderByDesc('id')->value('debit_note_number');
        if (!$last) return 'DN-0001';
        $num = (int) substr($last, 3);
        return 'DN-' . str_pad($num + 1, 4, '0', STR_PAD_LEFT);
    }
}
