<?php

namespace App\Http\Controllers\API\Accounting;

use App\Http\Controllers\Controller;
use App\Models\Accounting\Account;
use App\Models\Company;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class AccountController extends Controller
{
    /**
     * Get all accounts
     */
    public function index(Request $request)
    {
        $query = Account::with(['currency', 'parent'])
            ->orderBy('code');

        // Filter by type
        if ($request->has('type')) {
            $query->where('type', $request->type);
        }

        // Filter by category
        if ($request->has('category')) {
            $query->where('category', $request->category);
        }

        // Filter by active status
        if ($request->has('is_active')) {
            $query->where('is_active', $request->boolean('is_active'));
        }

        // Only parent accounts
        if ($request->boolean('parents_only')) {
            $query->whereNull('parent_id');
        }

        // for_reconciliation=true → return ALL types (assets, liabilities, equity, etc.)
        // so the bank reconciliation CoA picker shows loans, bank accounts, and everything else.
        // When this flag is present, any 'type' filter passed above is IGNORED.
        if ($request->boolean('for_reconciliation')) {
            $query->getQuery()->wheres = array_filter(
                $query->getQuery()->wheres,
                fn($w) => ($w['column'] ?? '') !== 'type'
            );
            $query->getQuery()->bindings['where'] = [];
        }

        $accounts = $query->get();

        return response()->json([
            'accounts' => $accounts,
        ]);
    }

    /**
     * Get single account
     */
    public function show($id)
    {
        $account = Account::with(['currency', 'parent', 'children'])->findOrFail($id);

        return response()->json([
            'account' => $account,
        ]);
    }

    /**
     * Create new account
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'company_id' => 'required|exists:companies,id',
            'code' => 'required|string|max:50|unique:accounts,code',
            'name' => 'required|string|max:255',
            'type' => 'required|in:asset,liability,equity,income,expense',
            'category' => 'nullable|string',
            'currency_id' => 'required|exists:currencies,id',
            'parent_id' => 'nullable|exists:accounts,id',
            'description' => 'nullable|string',
            'opening_balance' => 'nullable|numeric',
            'is_active' => 'boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $account = Account::create($request->all());

        return response()->json([
            'message' => 'Account created successfully',
            'account' => $account,
        ], 201);
    }

    /**
     * Update account
     */
    public function update(Request $request, $id)
    {
        $account = Account::findOrFail($id);

        if ($account->is_system) {
            return response()->json([
                'message' => 'System accounts cannot be modified',
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'code' => 'sometimes|string|max:50|unique:accounts,code,' . $id,
            'name' => 'sometimes|string|max:255',
            'type' => 'sometimes|in:asset,liability,equity,income,expense',
            'category' => 'nullable|string',
            'parent_id' => 'nullable|exists:accounts,id',
            'description' => 'nullable|string',
            'is_active' => 'boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $account->update($request->all());

        return response()->json([
            'message' => 'Account updated successfully',
            'account' => $account,
        ]);
    }

    /**
     * Delete account
     */
    public function destroy($id)
    {
        $account = Account::findOrFail($id);

        if ($account->is_system) {
            return response()->json([
                'message' => 'System accounts cannot be deleted',
            ], 403);
        }

        // Check if account has transactions
        if ($account->journalLines()->exists()) {
            return response()->json([
                'message' => 'Cannot delete account with existing transactions',
            ], 409);
        }

        $account->delete();

        return response()->json([
            'message' => 'Account deleted successfully',
        ]);
    }

    /**
     * Get account balance
     */
    public function balance($id, Request $request)
    {
        $account = Account::findOrFail($id);

        $date = $request->has('date')
            ? new \DateTime($request->date)
            : null;

        $balance = $account->getBalance($date);

        return response()->json([
            'account_id' => $account->id,
            'account_code' => $account->code,
            'account_name' => $account->name,
            'balance' => $balance,
            'date' => $date ? $date->format('Y-m-d') : now()->format('Y-m-d'),
            'currency' => $account->currency->code,
        ]);
    }

    /**
     * Get account ledger
     */
    public function ledger($id, Request $request)
    {
        $account = Account::findOrFail($id);

        $startDate = $request->has('start_date')
            ? new \DateTime($request->start_date)
            : null;

        $endDate = $request->has('end_date')
            ? new \DateTime($request->end_date)
            : null;

        $entries = $account->getLedgerEntries($startDate, $endDate);

        return response()->json([
            'account' => [
                'id' => $account->id,
                'code' => $account->code,
                'name' => $account->name,
                'type' => $account->type,
            ],
            'entries' => $entries,
            'opening_balance' => $account->opening_balance,
            'closing_balance' => $account->current_balance,
        ]);
    }

    /**
     * Bulk create accounts
     */
    public function bulkCreate(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'company_id' => 'required|exists:companies,id',
            'accounts' => 'required|array|min:1',
            'accounts.*.code' => 'required|string|max:50',
            'accounts.*.name' => 'required|string|max:255',
            'accounts.*.type' => 'required|in:asset,liability,equity,income,expense',
            'accounts.*.currency_id' => 'required|exists:currencies,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $createdAccounts = [];
        $errors = [];

        foreach ($request->accounts as $accountData) {
            try {
                $accountData['company_id'] = $request->company_id;
                $account = Account::create($accountData);
                $createdAccounts[] = $account;
            } catch (\Exception $e) {
                $errors[] = [
                    'code' => $accountData['code'],
                    'error' => $e->getMessage(),
                ];
            }
        }

        return response()->json([
            'message' => count($createdAccounts) . ' accounts created successfully',
            'accounts' => $createdAccounts,
            'errors' => $errors,
        ], 201);
    }
}
