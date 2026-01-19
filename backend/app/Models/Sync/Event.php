<?php

namespace App\Models\Sync;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Event extends Model
{
    use HasUuids;

    protected $fillable = [
        'tenant_id',
        'aggregate_type',
        'aggregate_id',
        'event_type',
        'event_data',
        'metadata',
        'sequence_number',
        'device_id',
        'user_id',
        'occurred_at',
        'synced_at',
    ];

    protected $casts = [
        'event_data' => 'array',
        'metadata' => 'array',
        'occurred_at' => 'datetime',
        'synced_at' => 'datetime',
    ];

    /**
     * Get the next sequence number for this tenant
     */
    public static function getNextSequenceNumber(string $tenantId): int
    {
        $lastEvent = static::where('tenant_id', $tenantId)
            ->orderBy('sequence_number', 'desc')
            ->first();

        return $lastEvent ? $lastEvent->sequence_number + 1 : 1;
    }

    /**
     * Sync queue entries for this event
     */
    public function syncQueue(): HasMany
    {
        return $this->hasMany(SyncQueue::class);
    }

    /**
     * Scope to get events after a specific sequence
     */
    public function scopeAfterSequence($query, int $sequence)
    {
        return $query->where('sequence_number', '>', $sequence)
            ->orderBy('sequence_number', 'asc');
    }

    /**
     * Scope to get unsynced events for a device
     */
    public function scopeUnsyncedForDevice($query, string $deviceId)
    {
        return $query->whereDoesntHave('syncQueue', function ($q) use ($deviceId) {
            $q->where('device_id', $deviceId)
              ->where('status', 'synced');
        })->orderBy('sequence_number', 'asc');
    }

    /**
     * Scope to get events by date range
     */
    public function scopeBetweenDates($query, $startDate, $endDate)
    {
        return $query->whereBetween('occurred_at', [$startDate, $endDate]);
    }

    /**
     * Scope to get events by aggregate
     */
    public function scopeForAggregate($query, string $aggregateType, string $aggregateId)
    {
        return $query->where('aggregate_type', $aggregateType)
            ->where('aggregate_id', $aggregateId)
            ->orderBy('sequence_number', 'asc');
    }

    /**
     * Mark event as synced
     */
    public function markAsSynced(): void
    {
        if (!$this->synced_at) {
            $this->update(['synced_at' => now()]);
        }
    }
}
