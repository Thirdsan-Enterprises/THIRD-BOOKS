<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Currency extends Model
{
    use HasFactory;

    protected $fillable = [
        'code',
        'name',
        'symbol',
        'decimal_places',
        'is_active',
    ];

    protected $casts = [
        'decimal_places' => 'integer',
        'is_active' => 'boolean',
    ];

    protected $attributes = [
        'decimal_places' => 2,
        'is_active' => true,
    ];

    /**
     * Get exchange rates
     */
    public function exchangeRates(): HasMany
    {
        return $this->hasMany(ExchangeRate::class);
    }

    /**
     * Get latest exchange rate
     */
    public function getLatestRate(string $date = null): ?float
    {
        $query = $this->exchangeRates()->orderBy('date', 'desc');

        if ($date) {
            $query->where('date', '<=', $date);
        }

        $rate = $query->first();

        return $rate ? (float) $rate->rate : null;
    }

    /**
     * Format amount according to currency
     */
    public function format(float $amount, bool $includeSymbol = true): string
    {
        $formatted = number_format($amount, $this->decimal_places);

        if ($includeSymbol) {
            return $this->symbol . ' ' . $formatted;
        }

        return $formatted;
    }

    /**
     * Scope active currencies
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }
}
