<?php

namespace App\Models\Purchases;

use App\Models\Company;
use App\Models\Currency;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Vendor extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'company_id',
        'vendor_number',
        'name',
        'company_name',
        'email',
        'phone',
        'mobile',
        'address',
        'city',
        'state',
        'postal_code',
        'country',
        'tax_id',
        'currency_id',
        'payment_terms_days',
        'status',
        'notes',
    ];

    protected $casts = [
        'payment_terms_days' => 'integer',
    ];

    protected $attributes = [
        'country' => 'UG',
        'payment_terms_days' => 30,
        'status' => 'active',
    ];

    /**
     * Relationships
     */
    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function currency(): BelongsTo
    {
        return $this->belongsTo(Currency::class);
    }

    public function bills(): HasMany
    {
        return $this->hasMany(Bill::class);
    }

    public function billPayments(): HasMany
    {
        return $this->hasMany(BillPayment::class);
    }

    /**
     * Get total outstanding balance
     */
    public function getOutstandingBalance(): float
    {
        return (float) $this->bills()
            ->whereIn('status', ['approved', 'partial', 'overdue'])
            ->sum('balance');
    }

    /**
     * Scopes
     */
    public function scopeActive($query)
    {
        return $query->where('status', 'active');
    }

    /**
     * Boot method
     */
    protected static function boot()
    {
        parent::boot();

        static::creating(function ($vendor) {
            if (!$vendor->vendor_number) {
                $vendor->vendor_number = static::generateVendorNumber($vendor->company_id);
            }
        });
    }

    /**
     * Generate vendor number
     */
    private static function generateVendorNumber(int $companyId): string
    {
        $prefix = 'VEN-';
        $lastVendor = static::where('company_id', $companyId)
            ->where('vendor_number', 'like', $prefix . '%')
            ->orderByDesc('vendor_number')
            ->first();

        if ($lastVendor) {
            $lastNumber = (int) str_replace($prefix, '', $lastVendor->vendor_number);
            $newNumber = $lastNumber + 1;
        } else {
            $newNumber = 1;
        }

        return $prefix . str_pad($newNumber, 6, '0', STR_PAD_LEFT);
    }
}
