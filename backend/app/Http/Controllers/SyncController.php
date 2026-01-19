<?php

namespace App\Http\Controllers;

use App\Services\Sync\EventSourceService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class SyncController extends Controller
{
    public function __construct(
        protected EventSourceService $eventSourceService
    ) {}

    /**
     * Pull events from server (download)
     *
     * GET /api/sync/pull
     */
    public function pull(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'device_id' => 'required|string|max:255',
            'after_sequence' => 'nullable|integer|min:0',
        ]);

        $result = $this->eventSourceService->getEventsForSync(
            $validated['device_id'],
            $validated['after_sequence'] ?? null
        );

        return $this->success($result, 'Events retrieved successfully');
    }

    /**
     * Push events to server (upload)
     *
     * POST /api/sync/push
     */
    public function push(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'device_id' => 'required|string|max:255',
            'events' => 'required|array',
            'events.*.aggregate_type' => 'required|string',
            'events.*.aggregate_id' => 'required|string',
            'events.*.event_type' => 'required|string',
            'events.*.event_data' => 'required|array',
            'events.*.occurred_at' => 'required|date',
            'events.*.user_id' => 'nullable|string',
            'events.*.metadata' => 'nullable|array',
        ]);

        $result = $this->eventSourceService->uploadEvents(
            $validated['events'],
            $validated['device_id']
        );

        if ($result['conflicts_count'] > 0) {
            return $this->success($result, 'Events uploaded with conflicts', 207); // 207 Multi-Status
        }

        return $this->success($result, 'Events uploaded successfully');
    }

    /**
     * Full sync - bi-directional sync
     *
     * POST /api/sync
     */
    public function sync(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'device_id' => 'required|string|max:255',
            'device_name' => 'nullable|string|max:255',
            'device_type' => 'nullable|string|in:mobile,web,desktop',
            'after_sequence' => 'nullable|integer|min:0',
            'events' => 'nullable|array',
            'events.*.aggregate_type' => 'required_with:events|string',
            'events.*.aggregate_id' => 'required_with:events|string',
            'events.*.event_type' => 'required_with:events|string',
            'events.*.event_data' => 'required_with:events|array',
            'events.*.occurred_at' => 'required_with:events|date',
            'events.*.user_id' => 'nullable|string',
            'events.*.metadata' => 'nullable|array',
        ]);

        $result = [
            'pushed' => null,
            'pulled' => null,
        ];

        // Upload local events first
        if (!empty($validated['events'])) {
            $result['pushed'] = $this->eventSourceService->uploadEvents(
                $validated['events'],
                $validated['device_id']
            );
        }

        // Download server events
        $result['pulled'] = $this->eventSourceService->getEventsForSync(
            $validated['device_id'],
            $validated['after_sequence'] ?? null
        );

        // Update device sync state
        $this->eventSourceService->updateDeviceSyncState(
            $validated['device_id'],
            $result['pulled']['last_sequence'],
            $validated['device_name'] ?? null,
            $validated['device_type'] ?? null
        );

        return $this->success($result, 'Sync completed successfully');
    }

    /**
     * Get sync status for device
     *
     * GET /api/sync/status
     */
    public function status(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'device_id' => 'required|string|max:255',
        ]);

        $stats = $this->eventSourceService->getSyncStatistics($validated['device_id']);

        return $this->success($stats);
    }

    /**
     * Update device sync state
     *
     * POST /api/sync/device
     */
    public function updateDevice(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'device_id' => 'required|string|max:255',
            'device_name' => 'required|string|max:255',
            'device_type' => 'required|string|in:mobile,web,desktop',
            'last_sequence' => 'required|integer|min:0',
            'metadata' => 'nullable|array',
        ]);

        $deviceState = $this->eventSourceService->updateDeviceSyncState(
            $validated['device_id'],
            $validated['last_sequence'],
            $validated['device_name'],
            $validated['device_type']
        );

        return $this->success($deviceState, 'Device state updated successfully');
    }

    /**
     * Replay events for aggregate (debugging/recovery)
     *
     * GET /api/sync/replay/{aggregateType}/{aggregateId}
     */
    public function replay(string $aggregateType, string $aggregateId): JsonResponse
    {
        $state = $this->eventSourceService->replayEventsForAggregate(
            $aggregateType,
            $aggregateId
        );

        return $this->success([
            'aggregate_type' => $aggregateType,
            'aggregate_id' => $aggregateId,
            'rebuilt_state' => $state,
        ], 'Events replayed successfully');
    }
}
