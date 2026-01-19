<?php

namespace App\Services\Sync;

use App\Models\Sync\Event;
use App\Models\Sync\DeviceSyncState;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Auth;

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
    public function uploadEvents(array $events, string $deviceId): array
    {
        $tenantId = tenant('id');
        $uploadedEvents = [];
        $conflicts = [];

        DB::transaction(function () use (
            $events,
            $deviceId,
            $tenantId,
            &$uploadedEvents,
            &$conflicts
        ) {
            foreach ($events as $eventData) {
                try {
                    // Check for conflicts
                    $existingEvent = Event::where('tenant_id', $tenantId)
                        ->where('aggregate_id', $eventData['aggregate_id'])
                        ->where('event_type', $eventData['event_type'])
                        ->where('occurred_at', $eventData['occurred_at'])
                        ->first();

                    if ($existingEvent) {
                        $conflicts[] = [
                            'local_event' => $eventData,
                            'server_event' => $existingEvent,
                            'resolution' => 'server_wins', // Default strategy
                        ];
                        continue;
                    }

                    // Create event with new sequence number
                    $sequenceNumber = Event::getNextSequenceNumber($tenantId);

                    $event = Event::create([
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

                    $uploadedEvents[] = $event;
                } catch (\Exception $e) {
                    \Log::error('Failed to upload event', [
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
