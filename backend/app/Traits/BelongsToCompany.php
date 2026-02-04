<?php

namespace App\Traits;

use App\Models\Company;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * BelongsToCompany Trait
 *
 * Automatically scopes all queries to the current company within a tenant.
 * This provides data isolation at the company level.
 *
 * Usage: Add `use BelongsToCompany;` to any model that should be company-scoped.
 */
trait BelongsToCompany
{
    /**
     * Boot the trait
     */
    public static function bootBelongsToCompany(): void
    {
        // Automatically set company_id when creating a new model
        static::creating(function (Model $model) {
            if (!$model->company_id && static::getCurrentCompanyId()) {
                $model->company_id = static::getCurrentCompanyId();
            }
        });

        // Add global scope to filter by company
        static::addGlobalScope('company', function (Builder $builder) {
            $companyId = static::getCurrentCompanyId();

            if ($companyId) {
                $builder->where($builder->getModel()->getTable() . '.company_id', $companyId);
            }
        });
    }

    /**
     * Get the current company ID from various sources
     */
    protected static function getCurrentCompanyId(): ?int
    {
        // 1. Check request header
        if (request() && request()->header('X-Company-ID')) {
            return (int) request()->header('X-Company-ID');
        }

        // 2. Check app-level company binding
        if (app()->bound('current_company_id')) {
            return app('current_company_id');
        }

        // 3. Get the default company for the current tenant
        if (app()->bound('current_company')) {
            return app('current_company')->id;
        }

        return null;
    }

    /**
     * Define the company relationship
     */
    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    /**
     * Scope to a specific company
     */
    public function scopeForCompany(Builder $query, int $companyId): Builder
    {
        return $query->withoutGlobalScope('company')
                     ->where($this->getTable() . '.company_id', $companyId);
    }

    /**
     * Scope without company filtering (use with caution)
     */
    public function scopeWithoutCompanyScope(Builder $query): Builder
    {
        return $query->withoutGlobalScope('company');
    }

    /**
     * Check if model belongs to the current company
     */
    public function belongsToCurrentCompany(): bool
    {
        return $this->company_id === static::getCurrentCompanyId();
    }
}
