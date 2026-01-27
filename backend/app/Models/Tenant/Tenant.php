<?php

namespace App\Models\Tenant;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Stancl\Tenancy\Database\Models\Tenant as BaseTenant;
use Stancl\Tenancy\Contracts\TenantWithDatabase;
use Stancl\Tenancy\Database\Concerns\HasDatabase;
use Stancl\Tenancy\Database\Concerns\HasDomains;

class Tenant extends BaseTenant implements TenantWithDatabase
{
    use HasDatabase, HasDomains, HasFactory, HasUuids, SoftDeletes;

    protected $fillable = [
        'id',
        'name',
        'company_name',
        'email',
        'phone',
        'address',
        'country',
        'base_currency',
        'fiscal_year_start',
        'plan',
        'trial_ends_at',
        'subscription_ends_at',
        'status',
        'settings',
        'data',
    ];

    protected $casts = [
        'trial_ends_at' => 'datetime',
        'subscription_ends_at' => 'datetime',
        'settings' => 'array',
        'data' => 'array',
    ];

    protected $attributes = [
        'country' => 'UG', // Uganda
        'base_currency' => 'UGX',
        'fiscal_year_start' => '01-01', // January 1st
        'plan' => 'trial',
        'status' => 'active',
    ];

    /**
     * Get the tenant's domains
     */
    public function domains(): HasMany
    {
        return $this->hasMany(Domain::class);
    }

    /**
     * Check if tenant is on trial
     */
    public function isOnTrial(): bool
    {
        return $this->plan === 'trial' &&
               $this->trial_ends_at &&
               $this->trial_ends_at->isFuture();
    }

    /**
     * Check if tenant subscription is active
     */
    public function isSubscriptionActive(): bool
    {
        return $this->status === 'active' &&
               (!$this->subscription_ends_at || $this->subscription_ends_at->isFuture());
    }

    /**
     * Check if tenant can access the system
     */
    public function canAccess(): bool
    {
        return $this->status === 'active' &&
               ($this->isOnTrial() || $this->isSubscriptionActive());
    }

    /**
     * Get setting value
     */
    public function getSetting(string $key, $default = null)
    {
        return data_get($this->settings, $key, $default);
    }

    /**
     * Set setting value
     */
    public function setSetting(string $key, $value): void
    {
        $settings = $this->settings ?? [];
        data_set($settings, $key, $value);
        $this->settings = $settings;
        $this->save();
    }

    /**
     * Get the internal database connection name
     *
     * Uses the tenant connection from config (supports MySQL and PostgreSQL)
     */
    public function getInternalDatabaseConnectionName(): string
    {
        return config('tenancy.database.tenant_connection', 'tenant_mysql');
    }

    /**
     * Get the internal database name
     */
    public function getInternalDatabaseName(): string
    {
        return config('tenancy.database.prefix') . $this->id . config('tenancy.database.suffix');
    }
}
