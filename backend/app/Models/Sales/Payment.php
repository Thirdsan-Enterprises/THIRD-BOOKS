<?php

namespace App\Models\Sales;

use App\Models\Accounting\Account;
use App\Models\Accounting\JournalEntry;
use App\Models\Company;
use App\Models\Currency;
use App\Traits\BelongsToCompany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Payment extends Model
{
    use HasFactory, SoftDeletes, BelongsToCompany;

    protected $fillable = [
        'company_id',
        'customer_id',
        'invoice_id',
        'journal_entry_id',
        'deposit_account_id',
        'payment_number',
        'date',
        'amount',
        'currency_id',
        'exchange_rate',
        'method',
        'reference',
        'notes',
        'status',
        'client_id',
    ];

    protected $casts = [
        'date' => 'date',
        'amount' => 'decimal:4',
        'exchange_rate' => 'decimal:10',
    ];

    protected $attributes = [
        'exchange_rate' => 1,
        'method' => 'cash',
        'status' => 'cleared',
    ];

    /**
     * Payment methods
     */
    const METHOD_CASH = 'cash';
    const METHOD_BANK_TRANSFER = 'bank_transfer';
    const METHOD_CHEQUE = 'cheque';
    const METHOD_MOBILE_MONEY = 'mobile_money';
    const METHOD_CREDIT_CARD = 'credit_card';
    const METHOD_OTHER = 'other';

    /**
     * Status constants
     */
    const STATUS_PENDING = 'pending';
    const STATUS_CLEARED = 'cleared';
    const STATUS_BOUNCED = 'bounced';
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

    public function invoice(): BelongsTo
    {
        return $this->belongsTo(Invoice::class);
    }

    public function currency(): BelongsTo
    {
        return $this->belongsTo(Currency::class);
    }

    public function depositAccount(): BelongsTo
    {
        return $this->belongsTo(Account::class, 'deposit_account_id');
    }

    public function journalEntry(): BelongsTo
    {
        return $this->belongsTo(JournalEntry::class);
    }

    public function attachments(): MorphMany
    {
        return $this->morphMany(\App\Models\Attachment::class, 'attachable');
    }

    /**
     * Boot method
     */
    protected static function boot()
    {
        parent::boot();

        static::creating(function ($payment) {
            if (!$payment->payment_number) {
                $payment->payment_number = static::generatePaymentNumber($payment->company_id);
            }
        });

        static::created(function ($payment) {
            if ($payment->invoice && $payment->status === self::STATUS_CLEARED) {
                $payment->invoice->recordPayment($payment->amount);
            }
        });
    }

    /**
     * Generate payment number
     */
    private static function generatePaymentNumber(int $companyId): string
    {
        $year = date('Y');
        $prefix = "PAY-{$year}-";

        $lastPayment = static::where('company_id', $companyId)
            ->where('payment_number', 'like', $prefix . '%')
            ->orderByDesc('payment_number')
            ->first();

        if ($lastPayment) {
            $lastNumber = (int) str_replace($prefix, '', $lastPayment->payment_number);
            $newNumber = $lastNumber + 1;
        } else {
            $newNumber = 1;
        }

        return $prefix . str_pad($newNumber, 6, '0', STR_PAD_LEFT);
    }
}
