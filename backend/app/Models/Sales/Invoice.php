<?php

namespace App\Models\Sales;

use App\Models\Accounting\JournalEntry;
use App\Models\Company;
use App\Models\Currency;
use App\Traits\BelongsToCompany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Invoice extends Model
{
    use HasFactory, SoftDeletes, BelongsToCompany;

    protected $fillable = [
        'company_id',
        'customer_id',
        'journal_entry_id',
        'client_uuid',
        'invoice_number',
        'date',
        'due_date',
        'reference',
        'notes',
        'terms',
        'currency_id',
        'exchange_rate',
        'subtotal',
        'tax_amount',
        'discount_amount',
        'total',
        'paid_amount',
        'balance',
        'status',
        'sent_at',
        'viewed_at',
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
        'sent_at' => 'datetime',
        'viewed_at' => 'datetime',
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
    const STATUS_SENT = 'sent';
    const STATUS_VIEWED = 'viewed';
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

    public function customer(): BelongsTo
    {
        return $this->belongsTo(Customer::class);
    }

    public function currency(): BelongsTo
    {
        return $this->belongsTo(Currency::class);
    }

    public function journalEntry(): BelongsTo
    {
        return $this->belongsTo(JournalEntry::class);
    }

    public function lines(): HasMany
    {
        return $this->hasMany(InvoiceLine::class);
    }

    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
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
     * Check if overdue
     */
    public function isOverdue(): bool
    {
        return $this->due_date < now() &&
               in_array($this->status, [self::STATUS_SENT, self::STATUS_VIEWED, self::STATUS_PARTIAL]);
    }

    /**
     * Mark as sent
     */
    public function markAsSent(): void
    {
        if ($this->status === self::STATUS_DRAFT) {
            $this->status = self::STATUS_SENT;
            $this->sent_at = now();
            $this->save();
        }
    }

    /**
     * Scopes
     */
    public function scopeUnpaid($query)
    {
        return $query->whereIn('status', [self::STATUS_SENT, self::STATUS_VIEWED, self::STATUS_PARTIAL, self::STATUS_OVERDUE]);
    }

    public function scopeOverdue($query)
    {
        return $query->where('due_date', '<', now())
            ->whereIn('status', [self::STATUS_SENT, self::STATUS_VIEWED, self::STATUS_PARTIAL]);
    }

    /**
     * Boot method
     */
    protected static function boot()
    {
        parent::boot();

        static::creating(function ($invoice) {
            if (!$invoice->invoice_number) {
                $invoice->invoice_number = static::generateInvoiceNumber($invoice->company_id);
            }

            if (!$invoice->due_date && $invoice->customer) {
                $invoice->due_date = $invoice->date->addDays($invoice->customer->payment_terms_days);
            }
        });

        static::saved(function ($invoice) {
            // Update status to overdue if past due date
            if ($invoice->isOverdue() && $invoice->status !== self::STATUS_OVERDUE) {
                $invoice->status = self::STATUS_OVERDUE;
                $invoice->saveQuietly();
            }
        });
    }

    /**
     * Generate invoice number
     */
    private static function generateInvoiceNumber(int $companyId): string
    {
        $year = date('Y');
        $prefix = "INV-{$year}-";

        $lastInvoice = static::where('company_id', $companyId)
            ->where('invoice_number', 'like', $prefix . '%')
            ->orderByDesc('invoice_number')
            ->first();

        if ($lastInvoice) {
            $lastNumber = (int) str_replace($prefix, '', $lastInvoice->invoice_number);
            $newNumber = $lastNumber + 1;
        } else {
            $newNumber = 1;
        }

        return $prefix . str_pad($newNumber, 6, '0', STR_PAD_LEFT);
    }
}
