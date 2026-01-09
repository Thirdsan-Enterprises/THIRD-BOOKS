<?php

namespace App\Models\Accounting;

use App\Models\Currency;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class JournalLine extends Model
{
    use HasFactory;

    protected $fillable = [
        'journal_entry_id',
        'account_id',
        'description',
        'debit',
        'credit',
        'currency_id',
        'exchange_rate',
        'debit_foreign',
        'credit_foreign',
        'order',
    ];

    protected $casts = [
        'debit' => 'decimal:4',
        'credit' => 'decimal:4',
        'exchange_rate' => 'decimal:10',
        'debit_foreign' => 'decimal:4',
        'credit_foreign' => 'decimal:4',
        'order' => 'integer',
    ];

    protected $attributes = [
        'debit' => 0,
        'credit' => 0,
        'exchange_rate' => 1,
        'debit_foreign' => 0,
        'credit_foreign' => 0,
        'order' => 0,
    ];

    /**
     * Relationships
     */
    public function journalEntry(): BelongsTo
    {
        return $this->belongsTo(JournalEntry::class);
    }

    public function account(): BelongsTo
    {
        return $this->belongsTo(Account::class);
    }

    public function currency(): BelongsTo
    {
        return $this->belongsTo(Currency::class);
    }

    /**
     * Helper methods
     */
    public function isDebit(): bool
    {
        return $this->debit > 0;
    }

    public function isCredit(): bool
    {
        return $this->credit > 0;
    }

    public function getAmount(): float
    {
        return (float) ($this->isDebit() ? $this->debit : $this->credit);
    }

    public function getType(): string
    {
        return $this->isDebit() ? 'debit' : 'credit';
    }

    /**
     * Boot method to add validation
     */
    protected static function boot()
    {
        parent::boot();

        static::saving(function ($line) {
            // Ensure only debit OR credit is set, not both
            if ($line->debit > 0 && $line->credit > 0) {
                throw new \Exception('Journal line cannot have both debit and credit');
            }

            // Ensure at least one is set
            if ($line->debit == 0 && $line->credit == 0) {
                throw new \Exception('Journal line must have either debit or credit');
            }

            // Validate amounts are not negative
            if ($line->debit < 0 || $line->credit < 0) {
                throw new \Exception('Debit and credit amounts cannot be negative');
            }
        });
    }
}
