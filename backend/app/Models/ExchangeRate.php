<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ExchangeRate extends Model
{
    use HasFactory;

    protected $fillable = [
        'currency_id',
        'date',
        'rate',
        'source',
    ];

    protected $casts = [
        'date' => 'date',
        'rate' => 'decimal:10',
    ];

    /**
     * Get the currency
     */
    public function currency(): BelongsTo
    {
        return $this->belongsTo(Currency::class);
    }

    /**
     * Get rate for a specific currency and date
     */
    public static function getRateForDate(int $currencyId, string $date): ?float
    {
        $rate = static::where('currency_id', $currencyId)
            ->where('date', '<=', $date)
            ->orderBy('date', 'desc')
            ->first();

        return $rate ? (float) $rate->rate : null;
    }
}
