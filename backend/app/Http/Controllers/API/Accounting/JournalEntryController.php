<?php

namespace App\Http\Controllers\API\Accounting;

use App\Http\Controllers\Controller;
use App\Models\Accounting\JournalEntry;
use App\Models\Company;
use App\Services\Accounting\DoubleEntryService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class JournalEntryController extends Controller
{
    protected $doubleEntryService;

    public function __construct(DoubleEntryService $doubleEntryService)
    {
        $this->doubleEntryService = $doubleEntryService;
    }

    /**
     * Get all journal entries
     */
    public function index(Request $request)
    {
        $query = JournalEntry::with(['lines.account', 'creator'])
            ->orderByDesc('date')
            ->orderByDesc('created_at');

        // Filter by status
        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        // Filter by type
        if ($request->has('type')) {
            $query->where('type', $request->type);
        }

        // Filter by date range
        if ($request->has('start_date')) {
            $query->where('date', '>=', $request->start_date);
        }

        if ($request->has('end_date')) {
            $query->where('date', '<=', $request->end_date);
        }

        $perPage = $request->input('per_page', 20);
        $entries = $query->paginate($perPage);

        return response()->json($entries);
    }

    /**
     * Get single journal entry
     */
    public function show($id)
    {
        $entry = JournalEntry::with(['lines.account.currency', 'creator', 'poster'])
            ->findOrFail($id);

        return response()->json([
            'journal_entry' => $entry,
            'is_balanced' => $entry->isBalanced(),
            'total_debits' => $entry->getTotalDebits(),
            'total_credits' => $entry->getTotalCredits(),
        ]);
    }

    /**
     * Create new journal entry
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'company_id' => 'required|exists:companies,id',
            'date' => 'required|date',
            'reference' => 'nullable|string|max:255',
            'description' => 'nullable|string',
            'auto_post' => 'boolean',
            'lines' => 'required|array|min:2',
            'lines.*.account_id' => 'required|exists:accounts,id',
            'lines.*.debit' => 'nullable|numeric|min:0',
            'lines.*.credit' => 'nullable|numeric|min:0',
            'lines.*.description' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        // Validate each line has either debit or credit, not both
        foreach ($request->lines as $index => $line) {
            $debit = $line['debit'] ?? 0;
            $credit = $line['credit'] ?? 0;

            if ($debit > 0 && $credit > 0) {
                return response()->json([
                    'message' => 'Validation failed',
                    'errors' => [
                        "lines.{$index}" => ['Line cannot have both debit and credit'],
                    ],
                ], 422);
            }

            if ($debit == 0 && $credit == 0) {
                return response()->json([
                    'message' => 'Validation failed',
                    'errors' => [
                        "lines.{$index}" => ['Line must have either debit or credit'],
                    ],
                ], 422);
            }
        }

        try {
            $company = Company::findOrFail($request->company_id);
            $user = $request->user();

            $journalEntry = $this->doubleEntryService->createJournalEntry(
                $company,
                $request->all(),
                $user,
                $request->boolean('auto_post', false)
            );

            return response()->json([
                'message' => 'Journal entry created successfully',
                'journal_entry' => $journalEntry->load(['lines.account']),
            ], 201);

        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Failed to create journal entry',
                'error' => $e->getMessage(),
            ], 400);
        }
    }

    /**
     * Update journal entry
     */
    public function update(Request $request, $id)
    {
        $entry = JournalEntry::findOrFail($id);

        if ($entry->isPosted()) {
            return response()->json([
                'message' => 'Posted journal entries cannot be modified',
            ], 403);
        }

        if ($entry->isLocked()) {
            return response()->json([
                'message' => 'Locked journal entries cannot be modified',
            ], 403);
        }

        $validator = Validator::make($request->all(), [
            'date' => 'sometimes|date',
            'reference' => 'nullable|string|max:255',
            'description' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $entry->update($request->only(['date', 'reference', 'description']));

        return response()->json([
            'message' => 'Journal entry updated successfully',
            'journal_entry' => $entry->fresh(['lines.account']),
        ]);
    }

    /**
     * Delete journal entry
     */
    public function destroy($id)
    {
        $entry = JournalEntry::findOrFail($id);

        if ($entry->isPosted()) {
            return response()->json([
                'message' => 'Posted journal entries cannot be deleted. Unpost first.',
            ], 403);
        }

        if ($entry->isLocked()) {
            return response()->json([
                'message' => 'Locked journal entries cannot be deleted',
            ], 403);
        }

        $entry->delete();

        return response()->json([
            'message' => 'Journal entry deleted successfully',
        ]);
    }

    /**
     * Post journal entry
     */
    public function post($id, Request $request)
    {
        $entry = JournalEntry::findOrFail($id);
        $user = $request->user();

        if (!$user->canPostTransactions()) {
            return response()->json([
                'message' => 'You do not have permission to post transactions',
            ], 403);
        }

        try {
            $entry->post($user);

            return response()->json([
                'message' => 'Journal entry posted successfully',
                'journal_entry' => $entry->fresh(['lines.account']),
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Failed to post journal entry',
                'error' => $e->getMessage(),
            ], 400);
        }
    }

    /**
     * Unpost journal entry
     */
    public function unpost($id, Request $request)
    {
        $entry = JournalEntry::findOrFail($id);
        $user = $request->user();

        if (!$user->isAccountant()) {
            return response()->json([
                'message' => 'Only accountants can unpost transactions',
            ], 403);
        }

        try {
            $entry->unpost();

            return response()->json([
                'message' => 'Journal entry unposted successfully',
                'journal_entry' => $entry->fresh(['lines.account']),
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Failed to unpost journal entry',
                'error' => $e->getMessage(),
            ], 400);
        }
    }

    /**
     * Preview journal entry before posting
     */
    public function preview($id)
    {
        $entry = JournalEntry::with(['lines.account.currency'])->findOrFail($id);

        $preview = [
            'entry_number' => $entry->entry_number,
            'date' => $entry->date,
            'description' => $entry->description,
            'status' => $entry->status,
            'is_balanced' => $entry->isBalanced(),
            'total_debits' => $entry->getTotalDebits(),
            'total_credits' => $entry->getTotalCredits(),
            'difference' => $entry->getTotalDebits() - $entry->getTotalCredits(),
            'lines' => $entry->lines->map(function ($line) {
                return [
                    'account_code' => $line->account->code,
                    'account_name' => $line->account->name,
                    'description' => $line->description,
                    'debit' => $line->debit,
                    'credit' => $line->credit,
                    'currency' => $line->currency->code,
                ];
            }),
            'can_post' => $entry->isDraft() && $entry->isBalanced() && $entry->lines()->count() >= 2,
        ];

        return response()->json($preview);
    }
}
