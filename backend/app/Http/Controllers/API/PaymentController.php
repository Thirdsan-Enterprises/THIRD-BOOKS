<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Sales\Payment as ReceivedPayment;
use App\Models\Purchases\BillPayment;
use App\Models\Accounting\Account;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

/**
 * Unified payment endpoint.
 *
 * GET  /payments  — returns all received (Sales\Payment) and made (BillPayment)
 *                   payments for the current company, in a single list keyed by
 *                   payment_type so the Flutter client can parse them with
 *                   Payment.fromJson().
 *
 * POST /payments  — stores a payment in the correct table depending on
 *                   payment_type ('received' → payments, 'made' → bill_payments).
 *                   Idempotent: if client_id already exists the existing record is
 *                   returned (prevents duplicates when re-syncing).
 */
class PaymentController extends Controller
{
    // ── GET /payments ─────────────────────────────────────────────────────────

    public function index(Request $request): JsonResponse
    {
        $companyId = $request->user()->company->id ?? null;

        // Received payments (customer / invoice side)
        $received = ReceivedPayment::with(['customer', 'depositAccount'])
            ->when($companyId, fn($q) => $q->where('company_id', $companyId))
            ->orderByDesc('date')
            ->get()
            ->map(fn($p) => $this->formatReceived($p));

        // Made payments (vendor / bill side)
        $made = BillPayment::with(['vendor', 'paymentAccount'])
            ->when($companyId, fn($q) => $q->where('company_id', $companyId))
            ->orderByDesc('date')
            ->get()
            ->map(fn($p) => $this->formatMade($p));

        $all = $received->merge($made)->sortByDesc('payment_date')->values();

        return response()->json(['data' => $all]);
    }

    // ── POST /payments ────────────────────────────────────────────────────────

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'payment_type'   => 'required|in:received,made',
            'amount'         => 'required|numeric|min:0.01',
            'payment_date'   => 'required|date',
            'payment_method' => 'required|string',
            'client_id'      => 'nullable|string|max:64',
            'vendor_id'      => 'nullable|string',
            'customer_id'    => 'nullable|string',
            'account_id'     => 'nullable|string',
            'reference'      => 'nullable|string|max:255',
            'notes'          => 'nullable|string',
            'currency_code'  => 'nullable|string|size:3',
        ]);

        $companyId = $request->user()->company->id ?? null;
        $clientId  = $validated['client_id'] ?? null;
        $method    = $this->normaliseMethod($validated['payment_method']);

        if ($validated['payment_type'] === 'received') {
            // Idempotency: skip if client_id already synced
            if ($clientId) {
                $existing = ReceivedPayment::where('client_id', $clientId)->first();
                if ($existing) {
                    return response()->json(['payment' => $this->formatReceived($existing)], 200);
                }
            }

            $depositAccountId = $this->resolveAccountId($validated['account_id'] ?? null);

            $payment = ReceivedPayment::create([
                'company_id'         => $companyId,
                'customer_id'        => $validated['customer_id'] ?? null,
                'deposit_account_id' => $depositAccountId,
                'date'               => $validated['payment_date'],
                'amount'             => $validated['amount'],
                'method'             => $method,
                'reference'          => $validated['reference'] ?? null,
                'notes'              => $validated['notes'] ?? null,
                'status'             => 'cleared',
                'client_id'          => $clientId,
            ]);

            return response()->json(['payment' => $this->formatReceived($payment->fresh())], 201);
        }

        // payment_type === 'made'
        if ($clientId) {
            $existing = BillPayment::where('client_id', $clientId)->first();
            if ($existing) {
                return response()->json(['payment' => $this->formatMade($existing)], 200);
            }
        }

        $paymentAccountId = $this->resolveAccountId($validated['account_id'] ?? null);

        $payment = BillPayment::create([
            'company_id'         => $companyId,
            'vendor_id'          => $validated['vendor_id'] ?? null,
            'payment_account_id' => $paymentAccountId,
            'date'               => $validated['payment_date'],
            'amount'             => $validated['amount'],
            'method'             => $method,
            'reference'          => $validated['reference'] ?? null,
            'notes'              => $validated['notes'] ?? null,
            'status'             => 'cleared',
            'client_id'          => $clientId,
        ]);

        return response()->json(['payment' => $this->formatMade($payment->fresh())], 201);
    }

    // ── Formatters ────────────────────────────────────────────────────────────

    private function formatReceived(ReceivedPayment $p): array
    {
        return [
            'id'             => (string) $p->id,
            'payment_number' => $p->payment_number,
            'payment_type'   => 'received',
            'customer_id'    => $p->customer_id ? (string) $p->customer_id : null,
            'customer_name'  => $p->customer?->name,
            'vendor_id'      => null,
            'vendor_name'    => null,
            'payment_date'   => $p->date?->toIso8601String(),
            'amount'         => (float) $p->amount,
            'payment_method' => $p->method,
            'reference'      => $p->reference,
            'notes'          => $p->notes,
            'account_id'     => $p->deposit_account_id ? (string) $p->deposit_account_id : null,
            'account_name'   => $p->depositAccount?->name,
            'status'         => $p->status,
            'currency_code'  => 'UGX',
            'created_at'     => $p->created_at?->toIso8601String(),
            'updated_at'     => $p->updated_at?->toIso8601String(),
        ];
    }

    private function formatMade(BillPayment $p): array
    {
        return [
            'id'             => (string) $p->id,
            'payment_number' => $p->payment_number,
            'payment_type'   => 'made',
            'customer_id'    => null,
            'customer_name'  => null,
            'vendor_id'      => $p->vendor_id ? (string) $p->vendor_id : null,
            'vendor_name'    => $p->vendor?->name,
            'payment_date'   => $p->date?->toIso8601String(),
            'amount'         => (float) $p->amount,
            'payment_method' => $p->method,
            'reference'      => $p->reference,
            'notes'          => $p->notes,
            'account_id'     => $p->payment_account_id ? (string) $p->payment_account_id : null,
            'account_name'   => $p->paymentAccount?->name,
            'status'         => $p->status,
            'currency_code'  => 'UGX',
            'created_at'     => $p->created_at?->toIso8601String(),
            'updated_at'     => $p->updated_at?->toIso8601String(),
        ];
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private function resolveAccountId(?string $clientId): ?int
    {
        if (!$clientId) return null;
        // Client sends either an integer string "5" or a UUID prefixed with "acct-"
        if (is_numeric($clientId)) return (int) $clientId;
        // Try stripping known prefix patterns used by the Flutter seed data
        $stripped = preg_replace('/^acct-/', '', $clientId);
        if (is_numeric($stripped)) return (int) $stripped;
        // Last resort: find by code
        return Account::where('code', $clientId)->value('id');
    }

    private function normaliseMethod(string $raw): string
    {
        $map = [
            'cash'          => 'cash',
            'bank transfer' => 'bank_transfer',
            'bank_transfer' => 'bank_transfer',
            'cheque'        => 'cheque',
            'check'         => 'cheque',
            'mobile money'  => 'mobile_money',
            'mobile_money'  => 'mobile_money',
            'credit card'   => 'credit_card',
            'credit_card'   => 'credit_card',
        ];
        return $map[strtolower($raw)] ?? 'other';
    }
}
