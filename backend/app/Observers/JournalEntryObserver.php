<?php

namespace App\Observers;

use App\Models\Accounting\JournalEntry;
use App\Services\Sync\EventSourceService;
use Illuminate\Support\Facades\DB;

class JournalEntryObserver
{
    public function __construct(
        protected EventSourceService $eventSourceService
    ) {}

    public function created(JournalEntry $entry): void
    {
        // Capture the materializing flag NOW (synchronously inside the observer).
        // DB::afterCommit() fires after the outermost transaction commits, at which
        // point EventSourceService::$materializing has already been reset to false
        // by the finally block in materializeEvent().  Without capturing the flag
        // here we would emit a duplicate "echo" event for every journal entry that
        // gets created during sync materialisation, corrupting the event log and
        // causing repeated line-deletion cycles on subsequent syncs.
        $wasMaterializing = EventSourceService::isCurrentlyMaterializing();

        // Fire AFTER the surrounding transaction commits so that journal lines
        // (created separately after the entry) are already persisted and loadable.
        DB::afterCommit(function () use ($entry, $wasMaterializing) {
            // Skip if this entry was created as part of materialising an incoming
            // sync event — the event already exists in the log; echoing it would
            // create an infinite re-materialise loop on other devices.
            if ($wasMaterializing) {
                return;
            }

            $entry->refresh();
            $lines = $entry->lines->map(fn($l) => [
                'account_id'    => $l->account_id,
                'description'   => $l->description,
                'debit'         => (float) $l->debit,
                'credit'        => (float) $l->credit,
                'currency_id'   => $l->currency_id,
                'exchange_rate' => (float) $l->exchange_rate,
                'debit_foreign' => (float) $l->debit_foreign,
                'credit_foreign'=> (float) $l->credit_foreign,
                'order'         => $l->order,
            ])->toArray();

            $this->eventSourceService->createEvent(
                aggregateType: 'journal_entry',
                aggregateId:   (string) $entry->id,
                eventType:     'journal_entry.created',
                eventData: [
                    'company_id'   => $entry->company_id,
                    'entry_number' => $entry->entry_number,
                    'date'         => $entry->date,
                    'description'  => $entry->description,
                    'reference'    => $entry->reference,
                    'status'       => $entry->status,
                    'type'         => $entry->type,
                    'created_by'   => $entry->created_by,
                    'lines'        => $lines,
                ]
            );
        });
    }

    public function updated(JournalEntry $entry): void
    {
        $changes = $entry->getDirty();
        if (empty($changes)) {
            return;
        }

        $wasMaterializing = EventSourceService::isCurrentlyMaterializing();

        DB::afterCommit(function () use ($entry, $changes, $wasMaterializing) {
            if ($wasMaterializing) {
                return;
            }

            $this->eventSourceService->createEvent(
                aggregateType: 'journal_entry',
                aggregateId:   (string) $entry->id,
                eventType:     'journal_entry.updated',
                eventData: [
                    'company_id' => $entry->company_id,
                    'changes'    => $changes,
                    'status'     => $entry->status,
                    'type'       => $entry->type,
                ]
            );
        });
    }

    public function deleted(JournalEntry $entry): void
    {
        $this->eventSourceService->createEvent(
            aggregateType: 'journal_entry',
            aggregateId:   (string) $entry->id,
            eventType:     'journal_entry.deleted',
            eventData:     ['deleted_at' => now()->toIso8601String()]
        );
    }
}
