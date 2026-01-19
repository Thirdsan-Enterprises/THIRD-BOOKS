<?php

namespace App\Http\Controllers\API\Purchases;

use App\Http\Controllers\Controller;
use App\Models\Purchases\Vendor;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class VendorController extends Controller
{
    public function index(Request $request)
    {
        $query = Vendor::with('currency')->orderBy('name');

        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        if ($request->has('search')) {
            $search = $request->search;
            $query->where(function($q) use ($search) {
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
            'vendor' => $vendor,
            'outstanding_balance' => $vendor->getOutstandingBalance(),
        ]);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'company_id' => 'required|exists:companies,id',
            'name' => 'required|string|max:255',
            'email' => 'nullable|email',
            'currency_id' => 'required|exists:currencies,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $vendor = Vendor::create($request->all());

        return response()->json(['message' => 'Vendor created successfully', 'vendor' => $vendor], 201);
    }

    public function update(Request $request, $id)
    {
        $vendor = Vendor::findOrFail($id);

        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|string|max:255',
            'email' => 'nullable|email',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $vendor->update($request->all());

        return response()->json(['message' => 'Vendor updated successfully', 'vendor' => $vendor]);
    }

    public function destroy($id)
    {
        $vendor = Vendor::findOrFail($id);

        if ($vendor->bills()->exists()) {
            return response()->json(['message' => 'Cannot delete vendor with existing bills'], 409);
        }

        $vendor->delete();

        return response()->json(['message' => 'Vendor deleted successfully']);
    }

    public function statement($id, Request $request)
    {
        $vendor = Vendor::findOrFail($id);

        $startDate = $request->input('start_date', now()->subMonths(3)->format('Y-m-d'));
        $endDate = $request->input('end_date', now()->format('Y-m-d'));

        $bills = $vendor->bills()
            ->whereBetween('date', [$startDate, $endDate])
            ->orderBy('date')
            ->get();

        $payments = $vendor->billPayments()
            ->whereBetween('date', [$startDate, $endDate])
            ->orderBy('date')
            ->get();

        return response()->json([
            'vendor' => $vendor,
            'period' => ['start_date' => $startDate, 'end_date' => $endDate],
            'bills' => $bills,
            'payments' => $payments,
            'outstanding_balance' => $vendor->getOutstandingBalance(),
        ]);
    }

    public function aging($id)
    {
        $vendor = Vendor::findOrFail($id);

        $bills = $vendor->bills()
            ->whereIn('status', ['approved', 'partial', 'overdue'])
            ->orderBy('due_date')
            ->get();

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
            'vendor' => $vendor,
            'aging' => $aging,
            'total_outstanding' => array_sum($aging),
        ]);
    }
}
