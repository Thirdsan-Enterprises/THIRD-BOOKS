<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Outlet extends Model
{
    protected $fillable = [
        'outlet_code',
        'name',
        'address',
        'city',
        'postal_code',
        'region',
        'venue_type',
        'owner_name',
        'owner_contact',
        'commission_rate',
        'is_active',
        'notes',
    ];

    protected $casts = [
        'commission_rate' => 'decimal:2',
        'is_active'       => 'boolean',
    ];
}
