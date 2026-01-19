<?php

namespace App\Models\Sync;

use Illuminate\Database\Eloquent\Model;

class DeviceSyncState extends Model
{
    protected $table = 'device_sync_state';

    protected $fillable = [
        'tenant_id',
        'device_id',
        'device_name',
        'device_type',
        'last_synced_sequence',
        'last_sync_at',
        'sync_metadata',
        'is_active',
    ];

    protected $casts = [
        'sync_metadata' => 'array',
        'last_sync_at' => 'datetime',
        'is_active' => 'boolean',
    ];

    /**
     * Update sync state
     */
    public function updateSyncState(int $sequenceNumber): void
    {
        $this->update([
            'last_synced_sequence' => $sequenceNumber,
            'last_sync_at' => now(),
        ]);
    }

    /**
     * Get or create device sync state
     */
    public static function getOrCreateDevice(
        string $tenantId,
        string $deviceId,
        string $deviceName,
        string $deviceType,
        ?array $metadata = null
    ): self {
        return static::firstOrCreate(
            [
                'tenant_id' => $tenantId,
                'device_id' => $deviceId,
            ],
            [
                'device_name' => $deviceName,
                'device_type' => $deviceType,
                'sync_metadata' => $metadata ?? [],
                'is_active' => true,
            ]
        );
    }

    /**
     * Scope to get active devices
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }
}
