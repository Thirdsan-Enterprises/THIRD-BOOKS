<?php

namespace App\Http\Controllers\API\Accounting;

use App\Http\Controllers\Controller;
use App\Models\Accounting\Account;
use App\Models\Company;
use App\Services\Sync\EventSourceService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class AccountController extends Controller
{
    public function __construct(
        protected EventSourceService $eventSourceService,
    ) {}

    public function index(Request $request)
    {
        $query = Account::with(['currency', 'parent'])->orderBy('code');

        if ($request->has('type')) {
            $query->where('type', $request->type);
        }
        if ($request->has('category')) {
            $query->where('category', $request->category);
        }
        if ($request->has('is_active')) {
            $query->where('is_active', $request->boolean('is_active'));
        }
        if ($request->boolean('parents_only')) {
            $query->whereNull('parent_id');
        }

        // for_reconciliation=true → ignore type filter so all account types appear
        if ($request->boolean('for_reconciliation')) {
            $query->getQuery()->wheres = array_filter(
                $query->getQuery()->wheres,
                fn($w) => ($w['column'] ?? '') !== 'type'
            );
            $query->getQuery()->bindings['where'] = [];
        }

        return response()->json(['accounts' => $query->get()]);
    }

    public function show($id)
    {
        $account = Account::with(['currency', 'parent', 'children'])->findOrFail($id);
        return response()->json(['account' => $account]);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'company_id'      => 'required|exists:companies,id',
            'code'            => 'required|string|max:50|unique:accounts,code',
            'name'            => 'required|string|max:255',
            'type'            => 'required|in:asset,liability,equity,income,expense',
            'category'        => 'nullable|string',
            'currency_id'     => 'required|exists:currencies,id',
            'parent_id'       => 'nullable|exists:accounts,id',
            'description'     => 'nullable|string',
            'opening_balance' => 'nullable|numeric',
            'is_active'       => 'boolean',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $account = Account::create($request->all());
        $this->emitEvent('account.created', $account->id, $account->toArray());

        return response()->json(['message' => 'Account created successfully', 'account' => $account], 201);
    }

    public function update(Request $request, $id)
    {
        $account = Account::findOrFail($id);

        if ($account->is_system) {
            return response()->json(['message' => 'System accounts cannot be modified'], 403);
        }

        $validator = Validator::make($request->all(), [
            'code'        => 'sometimes|string|max:50|unique:accounts,code,' . $id,
            'name'        => 'sometimes|string|max:255',
            'type'        => 'sometimes|in:asset,liability,equity,income,expense',
            'category'    => 'nullable|string',
            'parent_id'   => 'nullable|exists:accounts,id',
            'description' => 'nullable|string',
            'is_active'   => 'boolean',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $account->update($request->all());
        $this->emitEvent('account.updated', $account->id, $account->toArray());

        return response()->json(['message' => 'Account updated successfully', 'account' => $account]);
    }

    public function destroy($id)
    {
        $account = Account::findOrFail($id);

        if ($account->is_system) {
            return response()->json(['message' => 'System accounts cannot be deleted'], 403);
        }

        if ($account->journalLines()->exists()) {
            return response()->json(['message' => 'Cannot delete account with existing transactions'], 409);
        }

        $this->emitEvent('account.deleted', $account->id, ['id' => $account->id]);
        $account->delete();

        return response()->json(['message' => 'Account deleted successfully']);
    }

    public function balance($id, Request $request)
    {
        $account = Account::findOrFail($id);
        $date    = $request->has('date') ? new \DateTime($request->date) : null;
        $balance = $account->getBalance($date);

        return response()->json([
            'account_id'   => $account->id,
            'account_code' => $account->code,
            'account_name' => $account->name,
            'balance'      => $balance,
            'date'         => $date ? $date->format('Y-m-d') : now()->format('Y-m-d'),
            'currency'     => $account->currency->code,
        ]);
    }

    public function ledger($id, Request $request)
    {
        $account   = Account::findOrFail($id);
        $startDate = $request->has('start_date') ? new \DateTime($request->start_date) : null;
        $endDate   = $request->has('end_date') ? new \DateTime($request->end_date) : null;
        $entries   = $account->getLedgerEntries($startDate, $endDate);

        return response()->json([
            'account' => [
                'id'   => $account->id,
                'code' => $account->code,
                'name' => $account->name,
                'type' => $account->type,
            ],
            'entries'         => $entries,
            'opening_balance' => $account->opening_balance,
            'closing_balance' => $account->current_balance,
        ]);
    }

    public function bulkCreate(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'company_id'             => 'required|exists:companies,id',
            'accounts'               => 'required|array|min:1',
            'accounts.*.code'        => 'required|string|max:50',
            'accounts.*.name'        => 'required|string|max:255',
            'accounts.*.type'        => 'required|in:asset,liability,equity,income,expense',
            'accounts.*.currency_id' => 'required|exists:currencies,id',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $createdAccounts = [];
        $errors          = [];

        foreach ($request->accounts as $accountData) {
            try {
                $accountData['company_id'] = $request->company_id;
                $account                   = Account::create($accountData);
                $this->emitEvent('account.created', $account->id, $account->toArray());
                $createdAccounts[] = $account;
            } catch (\Exception $e) {
                $errors[] = ['code' => $accountData['code'], 'error' => $e->getMessage()];
            }
        }

        return response()->json([
            'message'  => count($createdAccounts) . ' accounts created successfully',
            'accounts' => $createdAccounts,
            'errors'   => $errors,
        ], 201);
    }

    private function emitEvent(string $eventType, string $aggregateId, array $data): void
    {
        try {
            $this->eventSourceService->createEvent('account', $aggregateId, $eventType, $data);
        } catch (\Throwable) {
            // Non-critical.
        }
    }
}
