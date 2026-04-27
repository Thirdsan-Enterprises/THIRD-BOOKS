<?php

namespace App\Http\Controllers\API\Sales;

use App\Http\Controllers\Controller;
use App\Models\Sales\Customer;
use App\Services\Sync\EventSourceService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class CustomerController extends Controller
{
    public function __construct(
        protected EventSourceService $eventSourceService,
    ) {}

    public function index(Request $request)
    {
        $query = Customer::with('currency')->orderBy('name');

        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        if ($request->has('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('name', 'ILIKE', "%{$search}%")
                  ->orWhere('email', 'ILIKE', "%{$search}%")
                  ->orWhere('customer_number', 'ILIKE', "%{$search}%");
            });
        }

        $perPage = $request->input('per_page', 20);
        return response()->json($query->paginate($perPage));
    }

    public function show($id)
    {
        $customer = Customer::with(['currency', 'invoices', 'payments'])->findOrFail($id);

        return response()->json([
            'customer' => $customer,
            'outstanding_balance' => $customer->getOutstandingBalance(),
            'has_exceeded_credit_limit' => $customer->hasExceededCreditLimit(),
        ]);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            // company_id / currency_id are optional: desktop clients don't send them.
            'company_id'         => 'nullable|exists:companies,id',
            'name'               => 'required|string|max:255',
            'email'              => 'nullable|email',
            'phone'              => 'nullable|string|max:20',
            'currency_id'        => 'nullable|exists:currencies,id',
            'currency_code'      => 'nullable|string|size:3',
            'credit_limit'       => 'nullable|numeric|min:0',
            'payment_terms_days' => 'nullable|integer|min:0',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $companyId  = $request->company_id ?? \App\Models\Company::first()?->id;
        $currencyId = $request->currency_id
            ?? \App\Models\Currency::where('code', $request->currency_code ?? 'UGX')->value('id')
            ?? \App\Models\Currency::first()?->id;

        $customer = Customer::create(array_merge(
            $request->except(['company_id', 'currency_id', 'currency_code']),
            ['company_id' => $companyId, 'currency_id' => $currencyId]
        ));
        $this->emitEvent('customer.created', $customer->id, $customer->toArray());

        return response()->json(['message' => 'Customer created successfully', 'customer' => $customer], 201);
    }

    public function update(Request $request, $id)
    {
        $customer = Customer::findOrFail($id);

        $validator = Validator::make($request->all(), [
            'name'               => 'sometimes|string|max:255',
            'email'              => 'nullable|email',
            'phone'              => 'nullable|string|max:20',
            'credit_limit'       => 'nullable|numeric|min:0',
            'payment_terms_days' => 'nullable|integer|min:0',
            'status'             => 'sometimes|in:active,inactive',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $customer->update($request->all());
        $this->emitEvent('customer.updated', $customer->id, $customer->toArray());

        return response()->json(['message' => 'Customer updated successfully', 'customer' => $customer]);
    }

    public function destroy($id)
    {
        $customer = Customer::findOrFail($id);

        if ($customer->invoices()->exists()) {
            return response()->json(['message' => 'Cannot delete customer with existing invoices'], 409);
        }

        $this->emitEvent('customer.deleted', $customer->id, ['id' => $customer->id]);
        $customer->delete();

        return response()->json(['message' => 'Customer deleted successfully']);
    }

    public function statement($id, Request $request)
    {
        $customer = Customer::findOrFail($id);

        $startDate = $request->input('start_date', now()->subMonths(3)->format('Y-m-d'));
        $endDate   = $request->input('end_date', now()->format('Y-m-d'));

        $invoices = $customer->invoices()
            ->whereBetween('date', [$startDate, $endDate])
            ->orderBy('date')
            ->get();

        $payments = $customer->payments()
            ->whereBetween('date', [$startDate, $endDate])
            ->orderBy('date')
            ->get();

        return response()->json([
            'customer'            => $customer,
            'period'              => ['start_date' => $startDate, 'end_date' => $endDate],
            'invoices'            => $invoices,
            'payments'            => $payments,
            'outstanding_balance' => $customer->getOutstandingBalance(),
        ]);
    }

    public function aging($id)
    {
        $customer = Customer::findOrFail($id);

        $invoices = $customer->invoices()
            ->whereIn('status', ['sent', 'viewed', 'partial', 'overdue'])
            ->orderBy('due_date')
            ->get();

        $aging = ['current' => 0, '30_days' => 0, '60_days' => 0, '90_plus_days' => 0];

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
            'customer'          => $customer,
            'aging'             => $aging,
            'total_outstanding' => array_sum($aging),
            'overdue_invoices'  => $customer->getOverdueInvoices(),
        ]);
    }

    private function emitEvent(string $eventType, string $aggregateId, array $data): void
    {
        try {
            $this->eventSourceService->createEvent('customer', $aggregateId, $eventType, $data);
        } catch (\Throwable) {
            // Non-critical.
        }
    }
}
