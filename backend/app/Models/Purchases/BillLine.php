<?php

namespace App\Models\Purchases;

use App\Models\Accounting\Account;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class BillLine extends Model
{
    use HasFactory;

    protected $fillable = [
        'bill_id',
        'account_id',
        'description',
        'quantity',
        'unit_price',
        'discount_percent',
        'discount_amount',
        'tax_rate',
        'tax_amount',
        'amount',
        'order',
    ];

    protected $casts = [
        'quantity' => 'decimal:4',
        'unit_price' => 'decimal:4',
        'discount_percent' => 'decimal:2',
        'discount_amount' => 'decimal:4',
        'tax_rate' => 'decimal:2',
        'tax_amount' => 'decimal:4',
        'amount' => 'decimal:4',
        'order' => 'integer',
    ];

    protected $attributes = [
        'quantity' => 1,
        'unit_price' => 0,
        'discount_percent' => 0,
        'discount_amount' => 0,
        'tax_rate' => 0,
        'tax_amount' => 0,
        'amount' => 0,
        'order' => 0,
    ];

    /**
     * Relationships
     */
    public function bill(): BelongsTo
    {
        return $this->belongsTo(Bill::class);
    }

    public function account(): BelongsTo
    {
        return $this->belongsTo(Account::class);
    }

    /**
     * Calculate line totals
     */
    public function calculateTotals(): void
    {
        $subtotal = $this->quantity * $this->unit_price;

        if ($this->discount_percent > 0) {
            $this->discount_amount = $subtotal * ($this->discount_percent / 100);
        }

        $amountBeforeTax = $subtotal - $this->discount_amount;

        if ($this->tax_rate > 0) {
            $this->tax_amount = $amountBeforeTax * ($this->tax_rate / 100);
        }

        $this->amount = $amountBeforeTax + $this->tax_amount;
    }

    /**
     * Boot method
     */
    protected static function boot()
    {
        parent::boot();

        static::saving(function ($line) {
            $line->calculateTotals();
        });

        static::saved(function ($line) {
            if ($line->bill) {
                $line->bill->calculateTotals();
                $line->bill->save();
            }
        });

        static::deleted(function ($line) {
            if ($line->bill) {
                $line->bill->calculateTotals();
                $line->bill->save();
            }
        });
    }
}
