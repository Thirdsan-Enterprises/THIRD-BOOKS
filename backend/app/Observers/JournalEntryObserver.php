<?php

namespace App\Observers;

use App\Models\Accounting\JournalEntry;
use App\Services\Sync\EventSourceService;

class JournalEntryObserver
{
    public function __construct(
        protected EventSourceService $eventSourceService
    ) {}

    public function created(JournalEntry $entry): void
    {
        $lines = $entry->lines->map(fn($l) => [
            'account_id'  => $l->account_id,
            'description' => $l->description,
            'debit'       => $l->debit,
            'credit'      => $l->credit,
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
                'lines'        => $lines,
            ]
        );
    }

    public function updated(JournalEntry $entry): void
    {
        $changes = $entry->getDirty();
        if (empty($changes)) {
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
            ]
        );
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
