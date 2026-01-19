<?php

namespace App\Models;

use App\Models\Tenant\Tenant;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable, SoftDeletes;

    protected $fillable = [
        'tenant_id',
        'name',
        'email',
        'password',
        'phone',
        'role',
        'is_active',
        'email_verified_at',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'is_active' => 'boolean',
        'password' => 'hashed',
    ];

    protected $attributes = [
        'role' => 'user',
        'is_active' => true,
    ];

    /**
     * Roles
     */
    const ROLE_ADMIN = 'admin';
    const ROLE_ACCOUNTANT = 'accountant';
    const ROLE_MANAGER = 'manager';
    const ROLE_USER = 'user';
    const ROLE_VIEWER = 'viewer';

    /**
     * Get the tenant
     */
    public function tenant(): BelongsTo
    {
        return $this->belongsTo(Tenant::class);
    }

    /**
     * Check if user has role
     */
    public function hasRole(string $role): bool
    {
        return $this->role === $role;
    }

    /**
     * Check if user is admin
     */
    public function isAdmin(): bool
    {
        return $this->role === self::ROLE_ADMIN;
    }

    /**
     * Check if user is accountant
     */
    public function isAccountant(): bool
    {
        return in_array($this->role, [self::ROLE_ADMIN, self::ROLE_ACCOUNTANT]);
    }

    /**
     * Check if user can post transactions
     */
    public function canPostTransactions(): bool
    {
        return in_array($this->role, [self::ROLE_ADMIN, self::ROLE_ACCOUNTANT, self::ROLE_MANAGER]);
    }

    /**
     * Check if user can only view
     */
    public function isViewerOnly(): bool
    {
        return $this->role === self::ROLE_VIEWER;
    }

    /**
     * Scopes
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    public function scopeByRole($query, string $role)
    {
        return $query->where('role', $role);
    }
}
