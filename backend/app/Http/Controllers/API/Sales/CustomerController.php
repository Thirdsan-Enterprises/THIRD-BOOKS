<?php

namespace App\Http\Controllers\API\Sales;

use App\Http\Controllers\Controller;
use App\Models\Sales\Customer;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class CustomerController extends Controller
{
    /**
     * Get all customers
     */
    public function index(Request $request)
    {
        $query = Customer::with('currency')->orderBy('name');

        // Filter by status
        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        // Search
        if ($request->has('search')) {
            $search = $request->search;
            $query->where(function($q) use ($search) {
                $q->where('name', 'ILIKE', "%{$search}%")
                  ->orWhere('email', 'ILIKE', "%{$search}%")
                  ->orWhere('customer_number', 'ILIKE', "%{$search}%");
            });
        }

        $perPage = $request->input('per_page', 20);
        $customers = $query->paginate($perPage);

        return response()->json($customers);
    }

    /**
     * Get single customer
     */
    public function show($id)
    {
        $customer = Customer::with(['currency', 'invoices', 'payments'])->findOrFail($id);

        return response()->json([
            'customer' => $customer,
            'outstanding_balance' => $customer->getOutstandingBalance(),
            'has_exceeded_credit_limit' => $customer->hasExceededCreditLimit(),
        ]);
    }

    /**
     * Create customer
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'company_id' => 'required|exists:companies,id',
            'name' => 'required|string|max:255',
            'email' => 'nullable|email',
            'phone' => 'nullable|string|max:20',
            'currency_id' => 'required|exists:currencies,id',
            'credit_limit' => 'nullable|numeric|min:0',
            'payment_terms_days' => 'nullable|integer|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $customer = Customer::create($request->all());

        return response()->json([
            'message' => 'Customer created successfully',
            'customer' => $customer,
        ], 201);
    }

    /**
     * Update customer
     */
    public function update(Request $request, $id)
    {
        $customer = Customer::findOrFail($id);

        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|string|max:255',
            'email' => 'nullable|email',
            'phone' => 'nullable|string|max:20',
            'credit_limit' => 'nullable|numeric|min:0',
            'payment_terms_days' => 'nullable|integer|min:0',
            'status' => 'sometimes|in:active,inactive',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $customer->update($request->all());

        return response()->json([
            'message' => 'Customer updated successfully',
            'customer' => $customer,
        ]);
    }

    /**
     * Delete customer
     */
    public function destroy($id)
    {
        $customer = Customer::findOrFail($id);

        if ($customer->invoices()->exists()) {
            return response()->json([
                'message' => 'Cannot delete customer with existing invoices',
            ], 409);
        }

        $customer->delete();

        return response()->json([
            'message' => 'Customer deleted successfully',
        ]);
    }

    /**
     * Get customer statement
     */
    public function statement($id, Request $request)
    {
        $customer = Customer::findOrFail($id);

        $startDate = $request->input('start_date', now()->subMonths(3)->format('Y-m-d'));
        $endDate = $request->input('end_date', now()->format('Y-m-d'));

        $invoices = $customer->invoices()
            ->whereBetween('date', [$startDate, $endDate])
            ->orderBy('date')
            ->get();

        $payments = $customer->payments()
            ->whereBetween('date', [$startDate, $endDate])
            ->orderBy('date')
            ->get();

        return response()->json([
            'customer' => $customer,
            'period' => [
                'start_date' => $startDate,
                'end_date' => $endDate,
            ],
            'invoices' => $invoices,
            'payments' => $payments,
            'outstanding_balance' => $customer->getOutstandingBalance(),
        ]);
    }

    /**
     * Get customer aging report
     */
    public function aging($id)
    {
        $customer = Customer::findOrFail($id);

        $invoices = $customer->invoices()
            ->whereIn('status', ['sent', 'viewed', 'partial', 'overdue'])
            ->orderBy('due_date')
            ->get();

        $aging = [
            'current' => 0,       // 0-30 days
            '30_days' => 0,       // 31-60 days
            '60_days' => 0,       // 61-90 days
            '90_plus_days' => 0,  // 90+ days
        ];

        foreach ($invoices as $invoice) {
            $daysOverdue = now()->diffInDays($invoice->due_date, false);

            if ($daysOverdue <= 0) {
                $aging['current'] += $invoice->balance;
            } elseif ($daysOverdue <= 30) {
                $aging['30_days'] += $invoice->balance;
            } elseif ($daysOverdue <= 60) {
                $aging['60_days'] += $invoice->balance;
            } else {
                $aging['90_plus_days'] += $invoice->balance;
            }
        }

        return response()->json([
            'customer' => $customer,
            'aging' => $aging,
            'total_outstanding' => array_sum($aging),
            'overdue_invoices' => $customer->getOverdueInvoices(),
        ]);
    }
}
