<?php

namespace App\Http\Controllers\API\Purchases;

use App\Http\Controllers\Controller;
use App\Models\Purchases\Vendor;
use App\Services\Sync\EventSourceService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class VendorController extends Controller
{
    public function __construct(
        protected EventSourceService $eventSourceService,
    ) {}

    public function index(Request $request)
    {
        $query = Vendor::with('currency')->orderBy('name');

        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        if ($request->has('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'ILIKE', "%{$search}%")
                  ->orWhere('email', 'ILIKE', "%{$search}%")
                  ->orWhere('vendor_number', 'ILIKE', "%{$search}%");
            });
        }

        $perPage = $request->input('per_page', 20);
        return response()->json($query->paginate($perPage));
    }

    public function show($id)
    {
        $vendor = Vendor::with(['currency', 'bills', 'billPayments'])->findOrFail($id);

        return response()->json([
            'vendor'              => $vendor,
            'outstanding_balance' => $vendor->getOutstandingBalance(),
        ]);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            // company_id / currency_id are optional: desktop clients don't send them.
            'company_id'    => 'nullable|exists:companies,id',
            'name'          => 'required|string|max:255',
            'email'         => 'nullable|email',
            'currency_id'   => 'nullable|exists:currencies,id',
            'currency_code' => 'nullable|string|size:3',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $companyId  = $request->company_id ?? \App\Models\Company::first()?->id;
        $currencyId = $request->currency_id
            ?? \App\Models\Currency::where('code', $request->currency_code ?? 'UGX')->value('id')
            ?? \App\Models\Currency::first()?->id;

        $vendor = Vendor::create(array_merge(
            $request->except(['company_id', 'currency_id', 'currency_code']),
            ['company_id' => $companyId, 'currency_id' => $currencyId]
        ));
        $this->emitEvent('vendor.created', $vendor->id, $vendor->toArray());

        return response()->json(['message' => 'Vendor created successfully', 'vendor' => $vendor], 201);
    }

    public function update(Request $request, $id)
    {
        $vendor = Vendor::findOrFail($id);

        $validator = Validator::make($request->all(), [
            'name'  => 'sometimes|string|max:255',
            'email' => 'nullable|email',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $vendor->update($request->all());
        $this->emitEvent('vendor.updated', $vendor->id, $vendor->toArray());

        return response()->json(['message' => 'Vendor updated successfully', 'vendor' => $vendor]);
    }

    public function destroy($id)
    {
        $vendor = Vendor::findOrFail($id);

        if ($vendor->bills()->exists()) {
            return response()->json(['message' => 'Cannot delete vendor with existing bills'], 409);
        }

        $this->emitEvent('vendor.deleted', $vendor->id, ['id' => $vendor->id]);
        $vendor->delete();

        return response()->json(['message' => 'Vendor deleted successfully']);
    }

    public function statement($id, Request $request)
    {
        $vendor = Vendor::findOrFail($id);

        $startDate = $request->input('start_date', now()->subMonths(3)->format('Y-m-d'));
        $endDate   = $request->input('end_date', now()->format('Y-m-d'));

        $bills    = $vendor->bills()->whereBetween('date', [$startDate, $endDate])->orderBy('date')->get();
        $payments = $vendor->billPayments()->whereBetween('date', [$startDate, $endDate])->orderBy('date')->get();

        return response()->json([
            'vendor'              => $vendor,
            'period'              => ['start_date' => $startDate, 'end_date' => $endDate],
            'bills'               => $bills,
            'payments'            => $payments,
            'outstanding_balance' => $vendor->getOutstandingBalance(),
        ]);
    }

    public function aging($id)
    {
        $vendor = Vendor::findOrFail($id);

        $bills = $vendor->bills()->whereIn('status', ['approved', 'partial', 'overdue'])->orderBy('due_date')->get();

        $aging = ['current' => 0, '30_days' => 0, '60_days' => 0, '90_plus_days' => 0];

        foreach ($bills as $bill) {
            $daysOverdue = now()->diffInDays($bill->due_date, false);
            if ($daysOverdue <= 0) {
                $aging['current'] += $bill->balance;
            } elseif ($daysOverdue <= 30) {
                $aging['30_days'] += $bill->balance;
            } elseif ($daysOverdue <= 60) {
                $aging['60_days'] += $bill->balance;
            } else {
                $aging['90_plus_days'] += $bill->balance;
            }
        }

        return response()->json([
            'vendor'            => $vendor,
            'aging'             => $aging,
            'total_outstanding' => array_sum($aging),
        ]);
    }

    private function emitEvent(string $eventType, string $aggregateId, array $data): void
    {
        try {
            $this->eventSourceService->createEvent('vendor', $aggregateId, $eventType, $data);
        } catch (\Throwable) {
            // Non-critical.
        }
    }
}
