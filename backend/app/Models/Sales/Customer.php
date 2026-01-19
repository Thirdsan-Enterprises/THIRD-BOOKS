<?php

namespace App\Models\Sales;

use App\Models\Company;
use App\Models\Currency;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Customer extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'company_id',
        'customer_number',
        'name',
        'company_name',
        'email',
        'phone',
        'mobile',
        'billing_address',
        'shipping_address',
        'city',
        'state',
        'postal_code',
        'country',
        'tax_id',
        'currency_id',
        'credit_limit',
        'payment_terms_days',
        'status',
        'notes',
    ];

    protected $casts = [
        'credit_limit' => 'decimal:4',
        'payment_terms_days' => 'integer',
    ];

    protected $attributes = [
        'country' => 'UG',
        'credit_limit' => 0,
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

    public function invoices(): HasMany
    {
        return $this->hasMany(Invoice::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }

    /**
     * Get total outstanding balance
     */
    public function getOutstandingBalance(): float
    {
        return (float) $this->invoices()
            ->whereIn('status', ['sent', 'partial', 'overdue'])
            ->sum('balance');
    }

    /**
     * Check if customer has exceeded credit limit
     */
    public function hasExceededCreditLimit(): bool
    {
        if ($this->credit_limit <= 0) {
            return false;
        }

        return $this->getOutstandingBalance() > $this->credit_limit;
    }

    /**
     * Get overdue invoices
     */
    public function getOverdueInvoices()
    {
        return $this->invoices()
            ->where('status', 'overdue')
            ->orderBy('due_date')
            ->get();
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

        static::creating(function ($customer) {
            if (!$customer->customer_number) {
                $customer->customer_number = static::generateCustomerNumber($customer->company_id);
            }
        });
    }

    /**
     * Generate customer number
     */
    private static function generateCustomerNumber(int $companyId): string
    {
        $prefix = 'CUST-';
        $lastCustomer = static::where('company_id', $companyId)
            ->where('customer_number', 'like', $prefix . '%')
            ->orderByDesc('customer_number')
            ->first();

        if ($lastCustomer) {
            $lastNumber = (int) str_replace($prefix, '', $lastCustomer->customer_number);
            $newNumber = $lastNumber + 1;
        } else {
            $newNumber = 1;
        }

        return $prefix . str_pad($newNumber, 6, '0', STR_PAD_LEFT);
    }
}
