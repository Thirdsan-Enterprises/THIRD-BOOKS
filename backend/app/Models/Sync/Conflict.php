<?php

namespace App\Models\Sync;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Conflict extends Model
{
    use HasUuids;

    protected $fillable = [
        'tenant_id',
        'server_event_id',
        'client_event_id',
        'aggregate_type',
        'aggregate_id',
        'conflict_type',
        'server_data',
        'client_data',
        'conflict_fields',
        'resolution_strategy',
        'resolved_data',
        'resolved_by',
        'resolved_at',
        'server_device_id',
        'client_device_id',
        'status',
    ];

    protected $casts = [
        'server_data' => 'array',
        'client_data' => 'array',
        'conflict_fields' => 'array',
        'resolved_data' => 'array',
        'resolved_at' => 'datetime',
    ];

    /**
     * Get the server event
     */
    public function serverEvent(): BelongsTo
    {
        return $this->belongsTo(Event::class, 'server_event_id');
    }

    /**
     * Get the client event
     */
    public function clientEvent(): BelongsTo
    {
        return $this->belongsTo(Event::class, 'client_event_id');
    }

    /**
     * Scope for pending conflicts
     */
    public function scopePending($query)
    {
        return $query->where('status', 'pending');
    }

    /**
     * Scope for resolved conflicts
     */
    public function scopeResolved($query)
    {
        return $query->where('status', 'resolved');
    }

    /**
     * Scope for specific aggregate
     */
    public function scopeForAggregate($query, string $aggregateType, string $aggregateId)
    {
        return $query->where('aggregate_type', $aggregateType)
            ->where('aggregate_id', $aggregateId);
    }

    /**
     * Scope for specific device
     */
    public function scopeForDevice($query, string $deviceId)
    {
        return $query->where('client_device_id', $deviceId);
    }

    /**
     * Resolve conflict with server data
     */
    public function resolveWithServer(string $userId): bool
    {
        $this->update([
            'resolution_strategy' => 'server_wins',
            'resolved_data' => $this->server_data,
            'resolved_by' => $userId,
            'resolved_at' => now(),
            'status' => 'resolved',
        ]);

        return true;
    }

    /**
     * Resolve conflict with client data
     */
    public function resolveWithClient(string $userId): bool
    {
        $this->update([
            'resolution_strategy' => 'client_wins',
            'resolved_data' => $this->client_data,
            'resolved_by' => $userId,
            'resolved_at' => now(),
            'status' => 'resolved',
        ]);

        return true;
    }

    /**
     * Resolve conflict with merged data
     */
    public function resolveWithMerge(array $mergedData, string $userId): bool
    {
        $this->update([
            'resolution_strategy' => 'merge',
            'resolved_data' => $mergedData,
            'resolved_by' => $userId,
            'resolved_at' => now(),
            'status' => 'resolved',
        ]);

        return true;
    }

    /**
     * Ignore the conflict
     */
    public function ignore(string $userId): bool
    {
        $this->update([
            'resolution_strategy' => 'ignored',
            'resolved_by' => $userId,
            'resolved_at' => now(),
            'status' => 'ignored',
        ]);

        return true;
    }

    /**
     * Identify which fields are in conflict
     */
    public function identifyConflictFields(): array
    {
        $conflicts = [];
        $serverData = $this->server_data;
        $clientData = $this->client_data;

        foreach ($serverData as $key => $serverValue) {
            if (isset($clientData[$key]) && $serverValue !== $clientData[$key]) {
                $conflicts[] = [
                    'field' => $key,
                    'server_value' => $serverValue,
                    'client_value' => $clientData[$key],
                ];
            }
        }

        // Check for fields in client but not in server
        foreach ($clientData as $key => $clientValue) {
            if (!isset($serverData[$key])) {
                $conflicts[] = [
                    'field' => $key,
                    'server_value' => null,
                    'client_value' => $clientValue,
                ];
            }
        }

        return $conflicts;
    }

    /**
     * Auto-resolve based on strategy
     */
    public function autoResolve(string $strategy = 'server_wins'): bool
    {
        return match ($strategy) {
            'server_wins' => $this->resolveWithServer('system'),
            'client_wins' => $this->resolveWithClient('system'),
            'last_write_wins' => $this->resolveByTimestamp(),
            default => false,
        };
    }

    /**
     * Resolve by timestamp (last write wins)
     */
    protected function resolveByTimestamp(): bool
    {
        $serverTime = $this->serverEvent->occurred_at;
        $clientTime = $this->clientEvent->occurred_at;

        if ($clientTime->gt($serverTime)) {
            return $this->resolveWithClient('system');
        }

        return $this->resolveWithServer('system');
    }
}
