<?php

namespace App\Traits;

use App\Models\Tenant\Tenant;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * BelongsToTenant Trait
 *
 * Automatically scopes all queries to the current tenant.
 * This provides data isolation in single-database multi-tenant mode.
 *
 * Usage: Add `use BelongsToTenant;` to any model that should be tenant-scoped.
 */
trait BelongsToTenant
{
    /**
     * Boot the trait
     */
    public static function bootBelongsToTenant(): void
    {
        // Automatically set tenant_id when creating a new model
        static::creating(function (Model $model) {
            if (!$model->tenant_id && static::getCurrentTenantId()) {
                $model->tenant_id = static::getCurrentTenantId();
            }
        });

        // Add global scope to filter by tenant
        static::addGlobalScope('tenant', function (Builder $builder) {
            $tenantId = static::getCurrentTenantId();

            if ($tenantId) {
                $builder->where($builder->getModel()->getTable() . '.tenant_id', $tenantId);
            }
        });
    }

    /**
     * Get the current tenant ID from various sources
     */
    protected static function getCurrentTenantId(): ?string
    {
        // 1. Check if tenancy is initialized via Stancl/Tenancy
        if (function_exists('tenant') && tenant()) {
            return tenant()->id;
        }

        // 2. Check request header
        if (request() && request()->header('X-Tenant-ID')) {
            return request()->header('X-Tenant-ID');
        }

        // 3. Check authenticated user's tenant
        if (auth()->check() && auth()->user()->tenant_id) {
            return auth()->user()->tenant_id;
        }

        // 4. Check app-level tenant binding
        if (app()->bound('current_tenant_id')) {
            return app('current_tenant_id');
        }

        return null;
    }

    /**
     * Define the tenant relationship
     */
    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    /**
     * Scope to a specific tenant
     */
    public function scopeForTenant(Builder $query, string $tenantId): Builder
    {
        return $query->withoutGlobalScope('tenant')
                     ->where($this->getTable() . '.tenant_id', $tenantId);
    }

    /**
     * Scope without tenant filtering (use with caution)
     */
    public function scopeWithoutTenantScope(Builder $query): Builder
    {
        return $query->withoutGlobalScope('tenant');
    }

    /**
     * Check if model belongs to the current tenant
     */
    public function belongsToCurrentTenant(): bool
    {
        return $this->tenant_id === static::getCurrentTenantId();
    }
}
