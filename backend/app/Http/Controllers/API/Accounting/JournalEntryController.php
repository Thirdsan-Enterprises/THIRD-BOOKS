<?php

namespace App\Http\Controllers\API\Accounting;

use App\Http\Controllers\Controller;
use App\Models\Accounting\JournalEntry;
use App\Models\Company;
use App\Services\Accounting\DoubleEntryService;
use App\Services\Sync\EventSourceService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class JournalEntryController extends Controller
{
    public function __construct(
        protected DoubleEntryService $doubleEntryService,
        protected EventSourceService $eventSourceService,
    ) {}

    public function index(Request $request)
    {
        $query = JournalEntry::with(['lines.account', 'creator'])
            ->orderByDesc('date')
            ->orderByDesc('created_at');

        if ($request->has('status')) {
            $query->where('status', $request->status);
        }
        if ($request->has('type')) {
            $query->where('type', $request->type);
        }
        if ($request->has('start_date')) {
            $query->where('date', '>=', $request->start_date);
        }
        if ($request->has('end_date')) {
            $query->where('date', '<=', $request->end_date);
        }

        $perPage = $request->input('per_page', 20);
        return response()->json($query->paginate($perPage));
    }

    public function show($id)
    {
        $entry = $this->resolveEntry($id, ['lines.account.currency', 'creator', 'poster']);
        if (! $entry) {
            return response()->json(['message' => 'Journal entry not found'], 404);
        }

        return response()->json([
            'journal_entry'  => $entry,
            'is_balanced'    => $entry->isBalanced(),
            'total_debits'   => $entry->getTotalDebits(),
            'total_credits'  => $entry->getTotalCredits(),
        ]);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            // company_id is optional: desktop clients don't carry it (single-
            // company tenants). When absent we resolve it from the tenant context.
            'company_id'           => 'nullable|exists:companies,id',
            'date'                 => 'required|date',
            'reference'            => 'nullable|string|max:255',
            'description'          => 'nullable|string',
            'auto_post'            => 'boolean',
            'lines'                => 'required|array|min:2',
            // account_id may be an integer PK or a local code like "acct-125".
            // Accept any non-empty value and resolve the real account in the loop.
            'lines.*.account_id'   => 'required',
            'lines.*.debit'        => 'nullable|numeric|min:0',
            'lines.*.credit'       => 'nullable|numeric|min:0',
            'lines.*.description'  => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        foreach ($request->lines as $index => $line) {
            $debit  = $line['debit'] ?? 0;
            $credit = $line['credit'] ?? 0;
            if ($debit > 0 && $credit > 0) {
                return response()->json([
                    'message' => 'Validation failed',
                    'errors'  => ["lines.{$index}" => ['Line cannot have both debit and credit']],
                ], 422);
            }
            if ($debit == 0 && $credit == 0) {
                return response()->json([
                    'message' => 'Validation failed',
                    'errors'  => ["lines.{$index}" => ['Line must have either debit or credit']],
                ], 422);
            }
        }

        try {
            // Resolve company: use the provided ID or fall back to the tenant's
            // only company (single-company tenants from the desktop client).
            $companyId = $request->company_id ?? Company::first()?->id;
            if (! $companyId) {
                return response()->json(['message' => 'No company found for this tenant'], 422);
            }
            $company = Company::findOrFail($companyId);

            // If the desktop supplied its local UUID as 'id', use it as
            // client_uuid so subsequent PUT requests can resolve the record.
            $clientUuid = $request->input('id');
            if ($clientUuid) {
                $existing = JournalEntry::where('client_uuid', $clientUuid)->first();
                if ($existing) {
                    $fresh = $existing->load(['lines.account']);
                    return response()->json(['message' => 'Journal entry created successfully', 'journal_entry' => $fresh], 201);
                }
            }

            $journalEntry = $this->doubleEntryService->createJournalEntry(
                $company, $request->all(), $request->user(), $request->boolean('auto_post', false)
            );

            if ($clientUuid) {
                $journalEntry->update(['client_uuid' => $clientUuid]);
            }

            $fresh = $journalEntry->load(['lines.account']);
            $this->emitEvent('journal_entry.created', $journalEntry->id, $fresh->toArray());

            return response()->json(['message' => 'Journal entry created successfully', 'journal_entry' => $fresh], 201);

        } catch (\Exception $e) {
            return response()->json(['message' => 'Failed to create journal entry', 'error' => $e->getMessage()], 400);
        }
    }

    public function update(Request $request, $id)
    {
        $entry = $this->resolveEntry($id);
        if (! $entry) {
            return response()->json(['message' => 'Journal entry not found'], 404);
        }

        if ($entry->isPosted()) {
            return response()->json(['message' => 'Posted journal entries cannot be modified'], 403);
        }
        if ($entry->isLocked()) {
            return response()->json(['message' => 'Locked journal entries cannot be modified'], 403);
        }

        $validator = Validator::make($request->all(), [
            'date'        => 'sometimes|date',
            'reference'   => 'nullable|string|max:255',
            'description' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json(['message' => 'Validation failed', 'errors' => $validator->errors()], 422);
        }

        $entry->update($request->only(['date', 'reference', 'description']));
        $fresh = $entry->fresh(['lines.account']);
        $this->emitEvent('journal_entry.updated', $entry->id, $fresh->toArray());

        return response()->json(['message' => 'Journal entry updated successfully', 'journal_entry' => $fresh]);
    }

    public function destroy($id)
    {
        $entry = $this->resolveEntry($id);
        if (! $entry) {
            return response()->json(['message' => 'Journal entry not found'], 404);
        }

        if ($entry->isPosted()) {
            return response()->json(['message' => 'Posted journal entries cannot be deleted. Unpost first.'], 403);
        }
        if ($entry->isLocked()) {
            return response()->json(['message' => 'Locked journal entries cannot be deleted'], 403);
        }

        $this->emitEvent('journal_entry.deleted', $entry->id, ['id' => $entry->id]);
        $entry->delete();

        return response()->json(['message' => 'Journal entry deleted successfully']);
    }

    public function post($id, Request $request)
    {
        $entry = $this->resolveEntry($id);
        if (! $entry) {
            return response()->json(['message' => 'Journal entry not found'], 404);
        }
        $user  = $request->user();

        if (!$user->canPostTransactions()) {
            return response()->json(['message' => 'You do not have permission to post transactions'], 403);
        }

        try {
            $entry->post($user);
            $fresh = $entry->fresh(['lines.account']);
            $this->emitEvent('journal_entry.updated', $entry->id, $fresh->toArray());

            return response()->json(['message' => 'Journal entry posted successfully', 'journal_entry' => $fresh]);

        } catch (\Exception $e) {
            return response()->json(['message' => 'Failed to post journal entry', 'error' => $e->getMessage()], 400);
        }
    }

    public function unpost($id, Request $request)
    {
        $entry = $this->resolveEntry($id);
        if (! $entry) {
            return response()->json(['message' => 'Journal entry not found'], 404);
        }
        $user  = $request->user();

        if (!$user->isAccountant()) {
            return response()->json(['message' => 'Only accountants can unpost transactions'], 403);
        }

        try {
            $entry->unpost();
            $fresh = $entry->fresh(['lines.account']);
            $this->emitEvent('journal_entry.updated', $entry->id, $fresh->toArray());

            return response()->json(['message' => 'Journal entry unposted successfully', 'journal_entry' => $fresh]);

        } catch (\Exception $e) {
            return response()->json(['message' => 'Failed to unpost journal entry', 'error' => $e->getMessage()], 400);
        }
    }

    public function preview($id)
    {
        $entry = $this->resolveEntry($id, ['lines.account.currency']);
        if (! $entry) {
            return response()->json(['message' => 'Journal entry not found'], 404);
        }

        return response()->json([
            'entry_number'  => $entry->entry_number,
            'date'          => $entry->date,
            'description'   => $entry->description,
            'status'        => $entry->status,
            'is_balanced'   => $entry->isBalanced(),
            'total_debits'  => $entry->getTotalDebits(),
            'total_credits' => $entry->getTotalCredits(),
            'difference'    => $entry->getTotalDebits() - $entry->getTotalCredits(),
            'lines'         => $entry->lines->map(fn($line) => [
                'account_code' => $line->account->code,
                'account_name' => $line->account->name,
                'description'  => $line->description,
                'debit'        => $line->debit,
                'credit'       => $line->credit,
                'currency'     => $line->currency->code,
            ]),
            'can_post' => $entry->isDraft() && $entry->isBalanced() && $entry->lines()->count() >= 2,
        ]);
    }

    /**
     * Resolve a JournalEntry by its integer PK or by client_uuid.
     * Desktop clients pass their local UUID as the route parameter; the
     * server stores this in client_uuid so both lookup paths work.
     */
    private function resolveEntry(mixed $id, array $with = []): ?JournalEntry
    {
        $query = JournalEntry::query();
        if ($with) {
            $query->with($with);
        }
        return $query->where('id', $id)
            ->orWhere('client_uuid', $id)
            ->first();
    }

    private function emitEvent(string $eventType, string $aggregateId, array $data): void
    {
        try {
            $this->eventSourceService->createEvent('journal_entry', $aggregateId, $eventType, $data);
        } catch (\Throwable) {
            // Non-critical.
        }
    }
}
