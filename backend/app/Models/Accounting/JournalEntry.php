<?php

namespace App\Models\Accounting;

use App\Models\Company;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class JournalEntry extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'company_id',
        'entry_number',
        'date',
        'reference',
        'description',
        'status',
        'type',
        'source',
        'source_id',
        'created_by',
        'posted_by',
        'posted_at',
        'is_locked',
    ];

    protected $casts = [
        'date' => 'date',
        'posted_at' => 'datetime',
        'is_locked' => 'boolean',
    ];

    protected $attributes = [
        'status' => 'draft',
        'type' => 'manual',
        'is_locked' => false,
    ];

    /**
     * Status constants
     */
    const STATUS_DRAFT = 'draft';
    const STATUS_POSTED = 'posted';

    /**
     * Type constants
     */
    const TYPE_MANUAL = 'manual';
    const TYPE_AUTOMATIC = 'automatic';

    /**
     * Relationships
     */
    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function poster(): BelongsTo
    {
        return $this->belongsTo(User::class, 'posted_by');
    }

    public function lines(): HasMany
    {
        return $this->hasMany(JournalLine::class);
    }

    /**
     * Helper methods
     */
    public function isDraft(): bool
    {
        return $this->status === self::STATUS_DRAFT;
    }

    public function isPosted(): bool
    {
        return $this->status === self::STATUS_POSTED;
    }

    public function isLocked(): bool
    {
        return $this->is_locked;
    }

    public function isBalanced(): bool
    {
        $totalDebits = $this->lines()->sum('debit');
        $totalCredits = $this->lines()->sum('credit');

        return bccomp($totalDebits, $totalCredits, 4) === 0;
    }

    public function getTotalDebits(): float
    {
        return (float) $this->lines()->sum('debit');
    }

    public function getTotalCredits(): float
    {
        return (float) $this->lines()->sum('credit');
    }

    /**
     * Post journal entry
     */
    public function post(User $user): bool
    {
        if ($this->isPosted()) {
            throw new \Exception('Journal entry is already posted');
        }

        if ($this->isLocked()) {
            throw new \Exception('Journal entry is locked');
        }

        if (!$this->isBalanced()) {
            throw new \Exception('Journal entry must be balanced (debits = credits)');
        }

        if ($this->lines()->count() < 2) {
            throw new \Exception('Journal entry must have at least 2 lines');
        }

        $this->update([
            'status' => self::STATUS_POSTED,
            'posted_by' => $user->id,
            'posted_at' => now(),
        ]);

        return true;
    }

    /**
     * Unpost journal entry
     */
    public function unpost(): bool
    {
        if (!$this->isPosted()) {
            throw new \Exception('Journal entry is not posted');
        }

        if ($this->isLocked()) {
            throw new \Exception('Journal entry is locked - period is closed');
        }

        // Delete general ledger entries
        GeneralLedger::where('journal_entry_id', $this->id)->delete();

        // Recalculate account balances
        foreach ($this->lines as $line) {
            $line->account->recalculateBalance();
        }

        $this->update([
            'status' => self::STATUS_DRAFT,
            'posted_by' => null,
            'posted_at' => null,
        ]);

        return true;
    }

    /**
     * Scopes
     */
    public function scopeDraft($query)
    {
        return $query->where('status', self::STATUS_DRAFT);
    }

    public function scopePosted($query)
    {
        return $query->where('status', self::STATUS_POSTED);
    }

    public function scopeInDateRange($query, $startDate, $endDate)
    {
        return $query->whereBetween('date', [$startDate, $endDate]);
    }
}
