<?php

namespace App\Http\Controllers\API\Purchases;

use App\Http\Controllers\Controller;
use App\Models\Accounting\Account;
use App\Models\Assets\AssetRegister;
use App\Models\Purchases\Bill;
use App\Models\Purchases\Vendor;
use App\Services\Accounting\DoubleEntryService;
use App\Services\Sync\EventSourceService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class BillController extends Controller
{
    public function __construct(
        protected DoubleEntryService $doubleEntryService,
        protected EventSourceService $eventSourceService,
    ) {}

    public function index(Request $request)
    {
        $query = Bill::with(['vendor', 'currency', 'lines.account'])
            ->orderByDesc('date');

        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        if ($request->has('vendor_id')) {
            $query->where('vendor_id', $request->vendor_id);
        }

        if ($request->boolean('unpaid_only')) {
            $query->unpaid();
        }

        $perPage = $request->input('per_page', 20);
        return response()->json($query->paginate($perPage));
    }

    public function show($id)
    {
        $bill = Bill::with(['vendor', 'currency', 'lines.account', 'payments', 'journalEntry'])
            ->findOrFail($id);

        return response()->json(['bill' => $bill]);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            // company_id / currency_id are optional: the desktop client sends
            // currency_code and no company_id (single-company tenants).
            'company_id'           => 'nullable|exists:companies,id',
            'vendor_id'            => 'required',   // string key or integer PK
            'date'                 => 'required|date',
            'currency_id'          => 'nullable|exists:currencies,id',
            'lines'                => 'required|array|min:1',
            // account_id may be an integer PK or a local code like "acct-125".
            'lines.*.account_id'   => 'required',
            'lines.*.description'  => 'nullable|string',
            // quantity and unit_price are optional: desktop sends amount directly.
            'lines.*.quantity'     => 'nullable|numeric|min:0',
            'lines.*.unit_price'   => 'nullable|numeric|min:0',
            'lines.*.amount'       => 'nullable|numeric|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        try {
            DB::beginTransaction();

            // Resolve company from request or tenant context.
            $companyId = $request->company_id ?? \App\Models\Company::first()?->id;
            if (! $companyId) {
                DB::rollBack();
                return response()->json(['message' => 'No company found for this tenant'], 422);
            }

            // Resolve currency: prefer explicit ID, then code, then default UGX.
            $currencyId = $request->currency_id
                ?? \App\Models\Currency::where('code', $request->currency_code ?? 'UGX')->value('id')
                ?? \App\Models\Currency::first()?->id;

            // Resolve vendor: accept integer PK or string key.
            $rawVendorId = $request->vendor_id;
            $vendorId    = ctype_digit((string) $rawVendorId)
                ? (int) $rawVendorId
                : \App\Models\Purchases\Vendor::where('id', $rawVendorId)->value('id');
            if (! $vendorId) {
                DB::rollBack();
                return response()->json(['message' => "Vendor '{$rawVendorId}' not found"], 422);
            }

            $bill = Bill::create([
                'company_id'           => $companyId,
                'vendor_id'            => $vendorId,
                'date'                 => $request->date,
                'due_date'             => $request->due_date,
                'reference'            => $request->reference,
                'notes'                => $request->notes,
                'currency_id'          => $currencyId,
                'exchange_rate'        => $request->exchange_rate ?? 1,
                'vendor_invoice_number'=> $request->vendor_invoice_number,
            ]);

            foreach ($request->lines as $lineData) {
                // Resolve account: integer PK or "acct-NNN" / "NNN" code string.
                $rawAcctId = $lineData['account_id'];
                $code      = str_starts_with((string) $rawAcctId, 'acct-')
                    ? substr($rawAcctId, 5)
                    : (string) $rawAcctId;
                $account   = ctype_digit($code)
                    ? (Account::find((int) $code) ?? Account::where('code', $code)->firstOrFail())
                    : Account::where('code', $code)->firstOrFail();

                // If the client sends amount directly (no qty/price), use qty=1,
                // unit_price=amount so BillLine::calculateTotals() works correctly.
                $amount    = (float) ($lineData['amount']
                    ?? (($lineData['unit_price'] ?? 0) * ($lineData['quantity'] ?? 1)));
                $quantity  = (float) ($lineData['quantity'] ?? 1);
                $unitPrice = $quantity > 0
                    ? (float) ($lineData['unit_price'] ?? ($amount / $quantity))
                    : 0.0;

                $bill->lines()->create([
                    'account_id'   => $account->id,
                    'description'  => $lineData['description'] ?? $account->name ?? '',
                    'quantity'     => $quantity,
                    'unit_price'   => $unitPrice,
                    'tax_rate'     => $lineData['tax_rate'] ?? 0,
                    'order'        => $lineData['order'] ?? 0,
                ]);
            }

            $bill->calculateTotals();
            $bill->save();

            // ── Auto-create Asset Register entries for fixed-asset and intangible lines ──
            // When a bill line uses a fixed_asset or intangible_asset CoA account we
            // create an AssetRegister record so the item appears in the Asset tab and
            // the user can configure depreciation (tangible) or amortization (intangible).
            $assetCount = 0;
            foreach ($bill->lines()->with('account')->get() as $line) {
                $account = $line->account;
                if (!$account) continue;

                $isFixedAsset     = $account->category === Account::CATEGORY_FIXED_ASSET;
                $isIntangibleAsset = $account->category === Account::CATEGORY_INTANGIBLE_ASSET;

                // Also catch intangibles that might be stored as generic 'asset' type
                // (e.g., accounts named "Software & Licenses" created before this feature)
                if (!$isFixedAsset && !$isIntangibleAsset && $account->type === Account::TYPE_ASSET) {
                    $inferredNature = AssetRegister::inferNatureFromAccountName($account->name);
                    if ($inferredNature === AssetRegister::NATURE_INTANGIBLE) {
                        $isIntangibleAsset = true;
                    }
                }

                if (!$isFixedAsset && !$isIntangibleAsset) {
                    continue;
                }

                // Skip current asset accounts (cash, bank, AR, inventory)
                if (in_array($account->category, [
                    Account::CATEGORY_BANK,
                    Account::CATEGORY_CASH,
                    Account::CATEGORY_ACCOUNTS_RECEIVABLE,
                    Account::CATEGORY_INVENTORY,
                ])) {
                    continue;
                }

                $nature   = $isIntangibleAsset ? AssetRegister::NATURE_INTANGIBLE : AssetRegister::NATURE_TANGIBLE;
                $category = AssetRegister::inferCategoryFromAccountName($account->name);

                AssetRegister::create([
                    'company_id'         => $bill->company_id,
                    'bill_id'            => $bill->id,
                    'bill_line_id'       => $line->id,
                    'coa_account_id'     => $account->id,
                    'name'               => $line->description ?: $account->name,
                    'category'           => $category,
                    'asset_nature'       => $nature,
                    'description'        => "Acquired via {$bill->bill_number} from {$bill->vendor->name}",
                    'cost'               => $line->amount,
                    // Intangibles: IAS 38 residual = 0; tangibles: user sets salvage later
                    'salvage_value'      => 0,
                    'current_book_value' => $line->amount,
                    'currency_code'      => $bill->currency?->code ?? 'UGX',
                    'acquisition_date'   => $bill->date,
                    'status'             => AssetRegister::STATUS_ACTIVE,
                    'created_by'         => $request->user()?->id,
                ]);
                $assetCount++;
            }

            DB::commit();

            $message = $assetCount > 0
                ? "Bill created successfully. {$assetCount} asset(s) added to the Asset Register."
                : 'Bill created successfully';

            $fresh = $bill->fresh(['lines', 'vendor']);
            $this->emitEvent('bill.created', $bill->id, $fresh->toArray());

            return response()->json(['message' => $message, 'bill' => $fresh], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['message' => 'Failed to create bill', 'error' => $e->getMessage()], 400);
        }
    }

    public function update(Request $request, $id)
    {
        $bill = Bill::findOrFail($id);

        if (!in_array($bill->status, [Bill::STATUS_DRAFT])) {
            return response()->json(['message' => 'Only draft bills can be modified'], 403);
        }

        $bill->update($request->only(['date', 'due_date', 'reference', 'notes', 'vendor_invoice_number']));
        $fresh = $bill->fresh(['lines', 'vendor']);
        $this->emitEvent('bill.updated', $bill->id, $fresh->toArray());

        return response()->json(['message' => 'Bill updated successfully', 'bill' => $fresh]);
    }

    public function destroy($id)
    {
        $bill = Bill::findOrFail($id);

        if ($bill->status !== Bill::STATUS_DRAFT) {
            return response()->json(['message' => 'Only draft bills can be deleted'], 403);
        }

        $this->emitEvent('bill.deleted', $bill->id, ['id' => $bill->id]);
        $bill->delete();

        return response()->json(['message' => 'Bill deleted successfully']);
    }

    public function recordPayment($id, Request $request)
    {
        $bill = Bill::findOrFail($id);

        $validator = Validator::make($request->all(), [
            'amount' => 'required|numeric|min:0.01',
            'date' => 'required|date',
            'method' => 'required|in:cash,bank_transfer,cheque,mobile_money,credit_card,other',
            'payment_account_id' => 'required|exists:accounts,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        if ($request->amount > $bill->balance) {
            return response()->json(['message' => 'Payment amount exceeds bill balance'], 400);
        }

        try {
            DB::beginTransaction();

            $payment = $bill->payments()->create([
                'company_id' => $bill->company_id,
                'vendor_id' => $bill->vendor_id,
                'payment_account_id' => $request->payment_account_id,
                'date' => $request->date,
                'amount' => $request->amount,
                'currency_id' => $bill->currency_id,
                'exchange_rate' => $bill->exchange_rate,
                'method' => $request->method,
                'reference' => $request->reference,
                'notes' => $request->notes,
                'status' => 'cleared',
            ]);

            $journalEntry = $this->doubleEntryService->createBillPaymentJournalEntry(
                $payment,
                $request->user(),
                true
            );

            $payment->journal_entry_id = $journalEntry->id;
            $payment->save();

            DB::commit();

            $this->emitEvent('payment.created', $payment->id, array_merge(
                $payment->toArray(), ['bill_id' => $bill->id]
            ));

            return response()->json([
                'message' => 'Payment recorded successfully',
                'payment' => $payment,
                'bill' => $bill->fresh(),
            ], 201);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['message' => 'Failed to record payment', 'error' => $e->getMessage()], 400);
        }
    }

    public function downloadPdf($id)
    {
        $bill = Bill::with(['vendor', 'lines.account', 'company'])->findOrFail($id);

        return response()->json(['message' => 'PDF generation not yet implemented', 'bill' => $bill]);
    }

    private function emitEvent(string $eventType, string $aggregateId, array $data): void
    {
        try {
            [$aggregate] = explode('.', $eventType);
            $this->eventSourceService->createEvent($aggregate, $aggregateId, $eventType, $data);
        } catch (\Throwable) {
            // Non-critical: never fail a REST response because of a sync event failure.
        }
    }
}
