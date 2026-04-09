<?php

namespace App\Models\Banking;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class BankStatementLine extends Model
{
    use HasFactory;

    protected $fillable = [
        'bank_statement_id',
        'date',
        'description',
        'reference',
        'debit',
        'credit',
        'balance',
        'reconciled_amount',
        'status',
        'notes',
    ];

    protected $casts = [
        'date' => 'date',
        'debit' => 'decimal:4',
        'credit' => 'decimal:4',
        'balance' => 'decimal:4',
        'reconciled_amount' => 'decimal:4',
    ];

    protected $attributes = [
        'debit' => 0,
        'credit' => 0,
        'reconciled_amount' => 0,
        'status' => 'unmatched',
    ];

    const STATUS_UNMATCHED = 'unmatched';
    const STATUS_PARTIAL = 'partial';
    const STATUS_RECONCILED = 'reconciled';

    public function statement(): BelongsTo
    {
        return $this->belongsTo(BankStatement::class, 'bank_statement_id');
    }

    public function reconciliationItems(): HasMany
    {
        return $this->hasMany(ReconciliationItem::class);
    }

    /**
     * The net amount of the line (credit = positive inflow, debit = outflow).
     */
    public function getNetAmountAttribute(): float
    {
        return (float) ($this->credit - $this->debit);
    }

    /**
     * Absolute transaction amount (whichever side is non-zero).
     */
    public function getTransactionAmountAttribute(): float
    {
        return (float) ($this->debit > 0 ? $this->debit : $this->credit);
    }

    /**
     * Remaining unreconciled amount.
     */
    public function getRemainingAmountAttribute(): float
    {
        return (float) ($this->transaction_amount - $this->reconciled_amount);
    }

    /**
     * Add a reconciliation allocation and refresh the line status.
     */
    public function addReconciliation(float $amount): void
    {
        $this->reconciled_amount = bcadd((string) $this->reconciled_amount, (string) $amount, 4);

        $transactionAmount = $this->transaction_amount;

        if (bccomp((string) $this->reconciled_amount, (string) $transactionAmount, 4) >= 0) {
            $this->status = self::STATUS_RECONCILED;
        } elseif (bccomp((string) $this->reconciled_amount, '0', 4) > 0) {
            $this->status = self::STATUS_PARTIAL;
        }

        $this->save();
    }

    /**
     * Remove a reconciliation amount (when item is unlinked).
     */
    public function removeReconciliation(float $amount): void
    {
        $newAmount = bcsub((string) $this->reconciled_amount, (string) $amount, 4);
        $this->reconciled_amount = max(0, (float) $newAmount);

        if ($this->reconciled_amount <= 0) {
            $this->status = self::STATUS_UNMATCHED;
        } else {
            $this->status = self::STATUS_PARTIAL;
        }

        $this->save();
    }
}
