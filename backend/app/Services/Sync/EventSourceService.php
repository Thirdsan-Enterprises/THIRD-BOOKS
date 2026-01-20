<?php

namespace App\Services\Sync;

use App\Models\Sync\Event;
use App\Models\Sync\DeviceSyncState;
use App\Models\Sync\Conflict;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;

class EventSourceService
{
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
    ): Event {
        return DB::transaction(function () use (
            $aggregateType,
            $aggregateId,
            $eventType,
            $eventData,
            $deviceId,
            $metadata
        ) {
            $tenantId = tenant('id');
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
        $tenantId = tenant('id');

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
        $tenantId = tenant('id');
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
                try {
                    // Detect concurrent modifications
                    $conflict = $this->detectConflict($tenantId, $eventData, $deviceId);

                    if ($conflict) {
                        // Create conflict record for resolution
                        $conflictRecord = $this->createConflictRecord(
                            $conflict['server_event'],
                            $eventData,
                            $deviceId,
                            $conflict['type']
                        );

                        // Auto-resolve based on strategy
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

                        // If client wins or manual, create the event
                        if ($resolutionStrategy === 'client_wins' || $resolutionStrategy === 'manual') {
                            $event = $this->createEventFromData($tenantId, $eventData, $deviceId);
                            $uploadedEvents[] = $event;
                        }

                        continue;
                    }

                    // No conflict, create event normally
                    $event = $this->createEventFromData($tenantId, $eventData, $deviceId);
                    $uploadedEvents[] = $event;

                } catch (\Exception $e) {
                    Log::error('Failed to upload event', [
                        'event' => $eventData,
                        'error' => $e->getMessage(),
                    ]);
                }
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
        $tenantId = tenant('id');

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
     * Update device sync state
     */
    public function updateDeviceSyncState(
        string $deviceId,
        int $lastSequence,
        ?string $deviceName = null,
        ?string $deviceType = null
    ): DeviceSyncState {
        $tenantId = tenant('id');

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
        $tenantId = tenant('id');

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
