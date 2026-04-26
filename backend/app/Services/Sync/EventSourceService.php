<?php

namespace App\Services\Sync;

use App\Models\Sync\Event;
use App\Models\Sync\DeviceSyncState;
use App\Models\Sync\Conflict;
use App\Models\Accounting\Account;
use App\Models\Accounting\JournalEntry;
use App\Models\Accounting\JournalLine;
use App\Models\Sales\Customer;
use App\Models\Sales\Invoice;
use App\Models\Sales\InvoiceLine;
use App\Models\Purchases\Vendor;
use App\Models\Purchases\Bill;
use App\Models\Purchases\BillLine;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;

class EventSourceService
{
    // Static so it is shared across ALL instances in the same request.
    // SyncController and each Observer get their own EventSourceService instance
    // via DI — a static flag ensures the materializing guard works across all of them.
    private static bool $materializing = false;

    /**
     * Create a new event
     */
    public function createEvent(
        string $aggregateType,
        string $aggregateId,
        string $eventType,
        array $eventData,
        ?string $deviceId = null,
        ?array $metadata = null
    ): ?Event {
        // Skip if we're inside materializeEvent to break the observer loop
        if (self::$materializing) {
            return null;
        }

        $tenantId = tenant('id') ?? Auth::user()?->tenant_id;

        // No tenant context (e.g. direct DB writes from scripts) — skip silently
        if (! $tenantId) {
            return null;
        }

        return DB::transaction(function () use (
            $aggregateType,
            $aggregateId,
            $eventType,
            $eventData,
            $deviceId,
            $metadata,
            $tenantId
        ) {
            $sequenceNumber = Event::getNextSequenceNumber($tenantId);

            $event = Event::create([
                'id' => Str::uuid(),
                'tenant_id' => $tenantId,
                'aggregate_type' => $aggregateType,
                'aggregate_id' => $aggregateId,
                'event_type' => $eventType,
                'event_data' => $eventData,
                'metadata' => array_merge($metadata ?? [], [
                    'user_id' => Auth::id(),
                    'ip_address' => request()->ip(),
                    'user_agent' => request()->userAgent(),
                ]),
                'sequence_number' => $sequenceNumber,
                'device_id' => $deviceId ?? request()->header('X-Device-ID'),
                'user_id' => Auth::id(),
                'occurred_at' => now(),
            ]);

            return $event;
        });
    }

    /**
     * Get events for sync (after a specific sequence number)
     */
    public function getEventsForSync(string $deviceId, ?int $afterSequence = null): array
    {
        $tenantId = tenant('id') ?? Auth::user()?->tenant_id;

        // Get or create device sync state
        $deviceState = DeviceSyncState::where('tenant_id', $tenantId)
            ->where('device_id', $deviceId)
            ->first();

        $afterSequence = $afterSequence ?? ($deviceState?->last_synced_sequence ?? 0);

        $events = Event::where('tenant_id', $tenantId)
            ->afterSequence($afterSequence)
            ->where(function ($query) use ($deviceId) {
                // Don't send events created by this device (they already have them)
                $query->where('device_id', '!=', $deviceId)
                    ->orWhereNull('device_id');
            })
            ->limit(100) // Batch size
            ->get();

        return [
            'events' => $events,
            'last_sequence' => $events->last()?->sequence_number ?? $afterSequence,
            'has_more' => $events->count() === 100,
        ];
    }

    /**
     * Upload events from device
     */
    public function uploadEvents(array $events, string $deviceId, string $resolutionStrategy = 'server_wins'): array
    {
        $tenantId = tenant('id') ?? Auth::user()?->tenant_id;

        if (! $tenantId) {
            Log::error('[SYNC PUSH] No tenant context — aborting upload', ['device_id' => $deviceId]);
            throw new \RuntimeException('No tenant context for sync upload.');
        }

        $uploadedEvents = [];
        $conflicts = [];

        DB::transaction(function () use (
            $events,
            $deviceId,
            $tenantId,
            $resolutionStrategy,
            &$uploadedEvents,
            &$conflicts
        ) {
            foreach ($events as $eventData) {
                // Detect concurrent modifications
                $conflict = $this->detectConflict($tenantId, $eventData, $deviceId);

                if ($conflict) {
                    $conflictRecord = $this->createConflictRecord(
                        $conflict['server_event'],
                        $eventData,
                        $deviceId,
                        $conflict['type']
                    );

                    if ($resolutionStrategy !== 'manual') {
                        $conflictRecord->autoResolve($resolutionStrategy);
                    }

                    $conflicts[] = [
                        'conflict_id' => $conflictRecord->id,
                        'type' => $conflict['type'],
                        'aggregate_id' => $eventData['aggregate_id'],
                        'local_event' => $eventData,
                        'server_event' => $conflict['server_event'],
                        'resolution' => $resolutionStrategy,
                    ];

                    if ($resolutionStrategy === 'client_wins' || $resolutionStrategy === 'manual') {
                        $event = $this->createEventFromData($tenantId, $eventData, $deviceId);
                        $this->materializeEvent($event);
                        $uploadedEvents[] = $event;
                    }

                    continue;
                }

                // No conflict — store and materialize
                $event = $this->createEventFromData($tenantId, $eventData, $deviceId);
                $this->materializeEvent($event);
                $uploadedEvents[] = $event;
            }
        });

        return [
            'uploaded_count' => count($uploadedEvents),
            'conflicts_count' => count($conflicts),
            'conflicts' => $conflicts,
        ];
    }

    /**
     * Detect conflicts between client and server events
     */
    protected function detectConflict(string $tenantId, array $clientEventData, string $deviceId): ?array
    {
        $aggregateId = $clientEventData['aggregate_id'];
        $eventType = $clientEventData['event_type'];

        // Get recent events for this aggregate from other devices
        $recentServerEvents = Event::where('tenant_id', $tenantId)
            ->where('aggregate_id', $aggregateId)
            ->where('device_id', '!=', $deviceId)
            ->where('occurred_at', '>=', now()->subHours(24)) // Check last 24 hours
            ->orderBy('occurred_at', 'desc')
            ->get();

        foreach ($recentServerEvents as $serverEvent) {
            // Check for concurrent updates (same aggregate, overlapping time)
            if ($this->isConcurrentUpdate($serverEvent, $clientEventData)) {
                return [
                    'type' => 'concurrent_update',
                    'server_event' => $serverEvent,
                ];
            }

            // Check for delete-modify conflict
            if ($this->isDeleteModifyConflict($serverEvent, $clientEventData)) {
                return [
                    'type' => 'delete_modified',
                    'server_event' => $serverEvent,
                ];
            }
        }

        return null;
    }

    /**
     * Check if events represent concurrent updates
     */
    protected function isConcurrentUpdate(Event $serverEvent, array $clientEventData): bool
    {
        // Same entity, both are update events, within 5 minutes
        if (str_contains($serverEvent->event_type, '.updated') &&
            str_contains($clientEventData['event_type'], '.updated')) {

            $timeDiff = abs(
                strtotime($serverEvent->occurred_at) -
                strtotime($clientEventData['occurred_at'])
            );

            return $timeDiff < 300; // 5 minutes
        }

        return false;
    }

    /**
     * Check if delete-modify conflict exists
     */
    protected function isDeleteModifyConflict(Event $serverEvent, array $clientEventData): bool
    {
        // Server deleted, client modified
        return str_contains($serverEvent->event_type, '.deleted') &&
               str_contains($clientEventData['event_type'], '.updated');
    }

    /**
     * Create a conflict record
     */
    protected function createConflictRecord(
        Event $serverEvent,
        array $clientEventData,
        string $clientDeviceId,
        string $conflictType
    ): Conflict {
        // Create the client event temporarily to get its ID
        $clientEvent = $this->createEventFromData(
            $serverEvent->tenant_id,
            $clientEventData,
            $clientDeviceId
        );

        $conflict = Conflict::create([
            'tenant_id' => $serverEvent->tenant_id,
            'server_event_id' => $serverEvent->id,
            'client_event_id' => $clientEvent->id,
            'aggregate_type' => $serverEvent->aggregate_type,
            'aggregate_id' => $serverEvent->aggregate_id,
            'conflict_type' => $conflictType,
            'server_data' => $serverEvent->event_data,
            'client_data' => $clientEventData['event_data'],
            'conflict_fields' => $this->identifyConflictFields(
                $serverEvent->event_data,
                $clientEventData['event_data']
            ),
            'server_device_id' => $serverEvent->device_id,
            'client_device_id' => $clientDeviceId,
            'status' => 'pending',
        ]);

        return $conflict;
    }

    /**
     * Identify fields that differ between server and client
     */
    protected function identifyConflictFields(array $serverData, array $clientData): array
    {
        $conflicts = [];

        foreach ($serverData as $key => $serverValue) {
            if (isset($clientData[$key]) && $serverValue !== $clientData[$key]) {
                $conflicts[] = $key;
            }
        }

        foreach ($clientData as $key => $clientValue) {
            if (!isset($serverData[$key]) && !in_array($key, $conflicts)) {
                $conflicts[] = $key;
            }
        }

        return $conflicts;
    }

    /**
     * Create event from event data array
     */
    protected function createEventFromData(string $tenantId, array $eventData, string $deviceId): Event
    {
        $sequenceNumber = Event::getNextSequenceNumber($tenantId);

        return Event::create([
            'id' => $eventData['id'] ?? Str::uuid(),
            'tenant_id' => $tenantId,
            'aggregate_type' => $eventData['aggregate_type'],
            'aggregate_id' => $eventData['aggregate_id'],
            'event_type' => $eventData['event_type'],
            'event_data' => $eventData['event_data'],
            'metadata' => array_merge($eventData['metadata'] ?? [], [
                'uploaded_from_device' => $deviceId,
            ]),
            'sequence_number' => $sequenceNumber,
            'device_id' => $deviceId,
            'user_id' => $eventData['user_id'] ?? Auth::id(),
            'occurred_at' => $eventData['occurred_at'],
        ]);
    }

    /**
     * Replay events to rebuild state
     */
    public function replayEventsForAggregate(string $aggregateType, string $aggregateId): array
    {
        $tenantId = tenant('id') ?? Auth::user()?->tenant_id;

        $events = Event::where('tenant_id', $tenantId)
            ->forAggregate($aggregateType, $aggregateId)
            ->get();

        $state = [];

        foreach ($events as $event) {
            $state = $this->applyEvent($state, $event);
        }

        return $state;
    }

    /**
     * Apply an event to a state
     */
    protected function applyEvent(array $state, Event $event): array
    {
        // This is where you define how each event type affects the state
        // Example implementation:

        switch ($event->event_type) {
            case 'invoice.created':
                $state = array_merge($state, $event->event_data);
                $state['status'] = 'draft';
                break;

            case 'invoice.sent':
                $state['status'] = 'sent';
                $state['sent_at'] = $event->occurred_at;
                break;

            case 'payment.recorded':
                $paid = ($state['paid_amount'] ?? 0) + $event->event_data['amount'];
                $state['paid_amount'] = $paid;
                $state['balance'] = $state['total'] - $paid;
                $state['status'] = $state['balance'] <= 0 ? 'paid' : 'partial';
                break;

            case 'invoice.cancelled':
                $state['status'] = 'cancelled';
                $state['cancelled_at'] = $event->occurred_at;
                break;

            // Add more event types as needed
        }

        return $state;
    }

    /**
     * Apply a stored event to the actual database tables (materialization).
     * Called immediately after an event is persisted so that other devices
     * can query the entity tables directly and see up-to-date data.
     */
    public function materializeEvent(Event $event): void
    {
        self::$materializing = true;
        try {
            $data        = $event->event_data ?? [];
            $eventType   = $event->event_type;
            $aggregateId = $event->aggregate_id;

            $parts  = explode('.', $eventType);
            $action = end($parts);

            match ($event->aggregate_type) {
                'account'       => $this->materializeAccount($action, $aggregateId, $data),
                'customer'      => $this->materializeCustomer($action, $aggregateId, $data),
                'vendor'        => $this->materializeVendor($action, $aggregateId, $data),
                'invoice'       => $this->materializeInvoice($action, $aggregateId, $data),
                'bill'          => $this->materializeBill($action, $aggregateId, $data),
                'journal_entry' => $this->materializeJournalEntry($action, $aggregateId, $data),
                default         => null,
            };
        } catch (\Throwable $e) {
            Log::warning('[SYNC MATERIALIZE] Failed to materialize event', [
                'event_id'       => $event->id,
                'aggregate_type' => $event->aggregate_type,
                'event_type'     => $event->event_type,
                'error'          => $e->getMessage(),
            ]);
        } finally {
            self::$materializing = false;
        }
    }

    protected function materializeAccount(string $action, string $id, array $data): void
    {
        if ($action === 'deleted') {
            Account::where('id', $id)->delete();
            return;
        }

        $companyId = $data['company_id'] ?? $this->resolveDefaultCompanyId();
        if (!$companyId) return;

        Account::updateOrCreate(['id' => $id], array_filter([
            'company_id'      => $companyId,
            'code'            => $data['code'] ?? null,
            'name'            => $data['name'] ?? null,
            'type'            => $data['type'] ?? 'asset',
            'category'        => $data['category'] ?? null,
            'description'     => $data['description'] ?? null,
            'parent_id'       => $data['parent_id'] ?? null,
            'is_active'       => $data['is_active'] ?? true,
        ], fn($v) => $v !== null));
    }

    protected function materializeCustomer(string $action, string $id, array $data): void
    {
        if ($action === 'deleted') {
            Customer::where('id', $id)->delete();
            return;
        }

        $companyId = $data['company_id'] ?? $this->resolveDefaultCompanyId();
        if (!$companyId) return;

        Customer::updateOrCreate(['id' => $id], array_filter([
            'company_id'        => $companyId,
            'name'              => $data['name'] ?? null,
            'email'             => $data['email'] ?? null,
            'phone'             => $data['phone'] ?? null,
            'billing_address'   => $data['billing_address'] ?? $data['address'] ?? null,
            'city'              => $data['city'] ?? null,
            'country'           => $data['country'] ?? 'UG',
            'tax_id'            => $data['tax_id'] ?? null,
            'notes'             => $data['notes'] ?? null,
            'status'            => $data['status'] ?? 'active',
        ], fn($v) => $v !== null));
    }

    protected function materializeVendor(string $action, string $id, array $data): void
    {
        if ($action === 'deleted') {
            Vendor::where('id', $id)->delete();
            return;
        }

        $companyId = $data['company_id'] ?? $this->resolveDefaultCompanyId();
        if (!$companyId) return;

        Vendor::updateOrCreate(['id' => $id], array_filter([
            'company_id'      => $companyId,
            'name'            => $data['name'] ?? null,
            'email'           => $data['email'] ?? null,
            'phone'           => $data['phone'] ?? null,
            'address'         => $data['address'] ?? null,
            'city'            => $data['city'] ?? null,
            'country'         => $data['country'] ?? 'UG',
            'tax_id'          => $data['tax_id'] ?? null,
            'notes'           => $data['notes'] ?? null,
            'status'          => $data['status'] ?? 'active',
        ], fn($v) => $v !== null));
    }

    protected function materializeInvoice(string $action, string $id, array $data): void
    {
        if ($action === 'deleted') {
            Invoice::where('id', $id)->delete();
            return;
        }

        $companyId = $data['company_id'] ?? $this->resolveDefaultCompanyId();
        if (!$companyId || empty($data['customer_id'])) return;

        $invoice = Invoice::updateOrCreate(['id' => $id], array_filter([
            'company_id'     => $companyId,
            'customer_id'    => $data['customer_id'],
            'invoice_number' => $data['invoice_number'] ?? null,
            'date'           => $data['date'] ?? null,
            'due_date'       => $data['due_date'] ?? null,
            'reference'      => $data['reference'] ?? null,
            'notes'          => $data['notes'] ?? null,
            'terms'          => $data['terms'] ?? null,
            'subtotal'       => $data['subtotal'] ?? 0,
            'tax_amount'     => $data['tax_amount'] ?? 0,
            'total'          => $data['total'] ?? 0,
            'paid_amount'    => $data['paid_amount'] ?? $data['amount_paid'] ?? 0,
            'balance'        => ($data['total'] ?? 0) - ($data['paid_amount'] ?? $data['amount_paid'] ?? 0),
            'status'         => $data['status'] ?? 'draft',
        ], fn($v) => $v !== null));

        // Sync lines when present
        if (!empty($data['lines'])) {
            $invoice->lines()->delete();
            foreach ($data['lines'] as $line) {
                InvoiceLine::create(array_filter([
                    'invoice_id'  => $invoice->id,
                    'account_id'  => $line['account_id'] ?? null,
                    'description' => $line['description'] ?? '',
                    'quantity'    => $line['quantity'] ?? 1,
                    'unit_price'  => $line['unit_price'] ?? 0,
                    'tax_rate'    => $line['tax_rate'] ?? 0,
                    'tax_amount'  => $line['tax_amount'] ?? 0,
                    'amount'      => $line['amount'] ?? 0,
                ], fn($v) => $v !== null));
            }
        }
    }

    protected function materializeBill(string $action, string $id, array $data): void
    {
        if ($action === 'deleted') {
            Bill::where('id', $id)->delete();
            return;
        }

        $companyId = $data['company_id'] ?? $this->resolveDefaultCompanyId();
        if (!$companyId || empty($data['vendor_id'])) return;

        $bill = Bill::updateOrCreate(['id' => $id], array_filter([
            'company_id'  => $companyId,
            'vendor_id'   => $data['vendor_id'],
            'bill_number' => $data['bill_number'] ?? null,
            'date'        => $data['date'] ?? null,
            'due_date'    => $data['due_date'] ?? null,
            'reference'   => $data['reference'] ?? null,
            'notes'       => $data['notes'] ?? null,
            'subtotal'    => $data['subtotal'] ?? 0,
            'tax_amount'  => $data['tax_amount'] ?? 0,
            'total'       => $data['total'] ?? 0,
            'paid_amount' => $data['paid_amount'] ?? $data['amount_paid'] ?? 0,
            'balance'     => ($data['total'] ?? 0) - ($data['paid_amount'] ?? $data['amount_paid'] ?? 0),
            'status'      => $data['status'] ?? 'draft',
        ], fn($v) => $v !== null));

        if (!empty($data['lines'])) {
            $bill->lines()->delete();
            foreach ($data['lines'] as $line) {
                if (empty($line['account_id'])) continue;
                BillLine::create(array_filter([
                    'bill_id'     => $bill->id,
                    'account_id'  => $line['account_id'],
                    'description' => $line['description'] ?? '',
                    'quantity'    => $line['quantity'] ?? 1,
                    'unit_price'  => $line['unit_price'] ?? 0,
                    'tax_rate'    => $line['tax_rate'] ?? 0,
                    'tax_amount'  => $line['tax_amount'] ?? 0,
                    'amount'      => $line['amount'] ?? 0,
                ], fn($v) => $v !== null));
            }
        }
    }

    protected function materializeJournalEntry(string $action, string $id, array $data): void
    {
        if ($action === 'deleted') {
            JournalEntry::where('id', $id)->delete();
            return;
        }

        $companyId = $data['company_id'] ?? $this->resolveDefaultCompanyId();
        if (!$companyId) return;

        $entry = JournalEntry::updateOrCreate(['id' => $id], array_filter([
            'company_id'   => $companyId,
            'entry_number' => $data['entry_number'] ?? null,
            'date'         => $data['date'] ?? null,
            'description'  => $data['description'] ?? '',
            'reference'    => $data['reference'] ?? null,
            'status'       => $data['status'] ?? 'draft',
            'type'         => $data['type'] ?? 'manual',
            'created_by'   => $data['created_by'] ?? Auth::id(),
        ], fn($v) => $v !== null));

        if (!empty($data['lines'])) {
            $entry->lines()->delete();
            foreach ($data['lines'] as $line) {
                if (empty($line['account_id'])) continue;
                JournalLine::create([
                    'journal_entry_id' => $entry->id,
                    'account_id'       => $line['account_id'],
                    'description'      => $line['description'] ?? null,
                    'debit'            => $line['debit'] ?? 0,
                    'credit'           => $line['credit'] ?? 0,
                ]);
            }
        }
    }

    /**
     * Resolve a fallback company_id from the current tenant context.
     * Used when a client-pushed event omits company_id.
     */
    protected function resolveDefaultCompanyId(): ?int
    {
        try {
            return \App\Models\Company::first()?->id;
        } catch (\Throwable) {
            return null;
        }
    }

    /**
     * Update device sync state
     */
    public function updateDeviceSyncState(
        string $deviceId,
        int $lastSequence,
        ?string $deviceName = null,
        ?string $deviceType = null
    ): DeviceSyncState {
        $tenantId = tenant('id') ?? Auth::user()?->tenant_id;

        $deviceState = DeviceSyncState::getOrCreateDevice(
            $tenantId,
            $deviceId,
            $deviceName ?? 'Unknown Device',
            $deviceType ?? 'unknown'
        );

        $deviceState->updateSyncState($lastSequence);

        return $deviceState;
    }

    /**
     * Get sync statistics
     */
    public function getSyncStatistics(string $deviceId): array
    {
        $tenantId = tenant('id') ?? Auth::user()?->tenant_id;

        $deviceState = DeviceSyncState::where('tenant_id', $tenantId)
            ->where('device_id', $deviceId)
            ->first();

        $totalEvents = Event::where('tenant_id', $tenantId)->count();
        $unsyncedEvents = Event::where('tenant_id', $tenantId)
            ->afterSequence($deviceState?->last_synced_sequence ?? 0)
            ->count();

        return [
            'device_id' => $deviceId,
            'last_synced_sequence' => $deviceState?->last_synced_sequence ?? 0,
            'last_sync_at' => $deviceState?->last_sync_at,
            'total_events' => $totalEvents,
            'unsynced_events' => $unsyncedEvents,
            'is_synced' => $unsyncedEvents === 0,
        ];
    }
}
