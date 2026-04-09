<?php

namespace App\Models\Purchases;

use App\Models\Accounting\JournalEntry;
use App\Models\Company;
use App\Models\Currency;
use App\Models\User;
use App\Traits\BelongsToCompany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Bill extends Model
{
    use HasFactory, SoftDeletes, BelongsToCompany;

    protected $fillable = [
        'company_id',
        'vendor_id',
        'journal_entry_id',
        'bill_number',
        'vendor_invoice_number',
        'date',
        'due_date',
        'reference',
        'notes',
        'currency_id',
        'exchange_rate',
        'subtotal',
        'tax_amount',
        'discount_amount',
        'total',
        'paid_amount',
        'balance',
        'status',
        'approved_at',
        'approved_by',
        'paid_at',
    ];

    protected $casts = [
        'date' => 'date',
        'due_date' => 'date',
        'exchange_rate' => 'decimal:10',
        'subtotal' => 'decimal:4',
        'tax_amount' => 'decimal:4',
        'discount_amount' => 'decimal:4',
        'total' => 'decimal:4',
        'paid_amount' => 'decimal:4',
        'balance' => 'decimal:4',
        'approved_at' => 'datetime',
        'paid_at' => 'datetime',
    ];

    protected $attributes = [
        'exchange_rate' => 1,
        'subtotal' => 0,
        'tax_amount' => 0,
        'discount_amount' => 0,
        'total' => 0,
        'paid_amount' => 0,
        'balance' => 0,
        'status' => 'draft',
    ];

    /**
     * Status constants
     */
    const STATUS_DRAFT = 'draft';
    const STATUS_APPROVED = 'approved';
    const STATUS_PARTIAL = 'partial';
    const STATUS_PAID = 'paid';
    const STATUS_OVERDUE = 'overdue';
    const STATUS_CANCELLED = 'cancelled';

    /**
     * Relationships
     */
    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function vendor(): BelongsTo
    {
        return $this->belongsTo(Vendor::class);
    }

    public function currency(): BelongsTo
    {
        return $this->belongsTo(Currency::class);
    }

    public function journalEntry(): BelongsTo
    {
        return $this->belongsTo(JournalEntry::class);
    }

    public function approvedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'approved_by');
    }

    public function lines(): HasMany
    {
        return $this->hasMany(BillLine::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(BillPayment::class);
    }

    public function attachments(): MorphMany
    {
        return $this->morphMany(\App\Models\Attachment::class, 'attachable');
    }

    /**
     * Calculate totals from lines
     */
    public function calculateTotals(): void
    {
        $this->subtotal = $this->lines->sum(fn($line) => $line->quantity * $line->unit_price - $line->discount_amount);
        $this->tax_amount = $this->lines->sum('tax_amount');
        $this->total = $this->subtotal + $this->tax_amount;
        $this->balance = $this->total - $this->paid_amount;
    }

    /**
     * Record payment
     */
    public function recordPayment(float $amount): void
    {
        $this->paid_amount += $amount;
        $this->balance = $this->total - $this->paid_amount;

        if ($this->balance <= 0.01) {
            $this->status = self::STATUS_PAID;
            $this->paid_at = now();
        } elseif ($this->paid_amount > 0) {
            $this->status = self::STATUS_PARTIAL;
        }

        $this->save();
    }

    /**
     * Approve bill
     */
    public function approve(User $user): void
    {
        if ($this->status === self::STATUS_DRAFT) {
            $this->status = self::STATUS_APPROVED;
            $this->approved_by = $user->id;
            $this->approved_at = now();
            $this->save();
        }
    }

    /**
     * Check if overdue
     */
    public function isOverdue(): bool
    {
        return $this->due_date < now() &&
               in_array($this->status, [self::STATUS_APPROVED, self::STATUS_PARTIAL]);
    }

    /**
     * Scopes
     */
    public function scopeUnpaid($query)
    {
        return $query->whereIn('status', [self::STATUS_APPROVED, self::STATUS_PARTIAL, self::STATUS_OVERDUE]);
    }

    public function scopeOverdue($query)
    {
        return $query->where('due_date', '<', now())
            ->whereIn('status', [self::STATUS_APPROVED, self::STATUS_PARTIAL]);
    }

    /**
     * Boot method
     */
    protected static function boot()
    {
        parent::boot();

        static::creating(function ($bill) {
            if (!$bill->bill_number) {
                $bill->bill_number = static::generateBillNumber($bill->company_id);
            }

            if (!$bill->due_date && $bill->vendor) {
                $bill->due_date = $bill->date->addDays($bill->vendor->payment_terms_days);
            }
        });

        static::saved(function ($bill) {
            if ($bill->isOverdue() && $bill->status !== self::STATUS_OVERDUE) {
                $bill->status = self::STATUS_OVERDUE;
                $bill->saveQuietly();
            }
        });
    }

    /**
     * Generate bill number
     */
    private static function generateBillNumber(int $companyId): string
    {
        $year = date('Y');
        $prefix = "BILL-{$year}-";

        $lastBill = static::where('company_id', $companyId)
            ->where('bill_number', 'like', $prefix . '%')
            ->orderByDesc('bill_number')
            ->first();

        if ($lastBill) {
            $lastNumber = (int) str_replace($prefix, '', $lastBill->bill_number);
            $newNumber = $lastNumber + 1;
        } else {
            $newNumber = 1;
        }

        return $prefix . str_pad($newNumber, 6, '0', STR_PAD_LEFT);
    }
}
