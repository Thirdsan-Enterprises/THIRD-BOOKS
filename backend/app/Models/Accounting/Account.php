<?php

namespace App\Models\Accounting;

use App\Models\Company;
use App\Models\Currency;
use App\Traits\BelongsToCompany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Account extends Model
{
    use HasFactory, SoftDeletes, BelongsToCompany;

    protected $fillable = [
        'company_id',
        'parent_id',
        'code',
        'name',
        'description',
        'type',
        'subtype',
        'category',
        'currency_id',
        'opening_balance',
        'current_balance',
        'is_active',
        'is_system',
        'order',
        'settings',
    ];

    protected $casts = [
        'opening_balance' => 'decimal:4',
        'current_balance' => 'decimal:4',
        'is_active' => 'boolean',
        'is_system' => 'boolean',
        'order' => 'integer',
        'settings' => 'array',
    ];

    protected $attributes = [
        'is_active' => true,
        'is_system' => false,
        'opening_balance' => 0,
        'current_balance' => 0,
        'order' => 0,
    ];

    /**
     * Account Types
     */
    const TYPE_ASSET = 'asset';
    const TYPE_LIABILITY = 'liability';
    const TYPE_EQUITY = 'equity';
    const TYPE_INCOME = 'income';
    const TYPE_EXPENSE = 'expense';

    /**
     * Account Categories
     */
    const CATEGORY_BANK = 'bank';
    const CATEGORY_CASH = 'cash';
    const CATEGORY_ACCOUNTS_RECEIVABLE = 'accounts_receivable';
    const CATEGORY_INVENTORY = 'inventory';
    const CATEGORY_FIXED_ASSET = 'fixed_asset';
    const CATEGORY_INTANGIBLE_ASSET = 'intangible_asset';
    const CATEGORY_ACCOUNTS_PAYABLE = 'accounts_payable';
    const CATEGORY_CREDIT_CARD = 'credit_card';
    const CATEGORY_LONG_TERM_LIABILITY = 'long_term_liability';
    const CATEGORY_EQUITY = 'equity';
    const CATEGORY_INCOME = 'income';
    const CATEGORY_COGS = 'cost_of_goods_sold';
    const CATEGORY_EXPENSE = 'expense';
    const CATEGORY_OTHER_INCOME = 'other_income';
    const CATEGORY_OTHER_EXPENSE = 'other_expense';

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

    public function parent(): BelongsTo
    {
        return $this->belongsTo(Account::class, 'parent_id');
    }

    public function children(): HasMany
    {
        return $this->hasMany(Account::class, 'parent_id');
    }

    public function journalLines(): HasMany
    {
        return $this->hasMany(JournalLine::class);
    }

    public function generalLedger(): HasMany
    {
        return $this->hasMany(GeneralLedger::class);
    }

    /**
     * Helper methods
     */
    public function isDebitAccount(): bool
    {
        return in_array($this->type, [self::TYPE_ASSET, self::TYPE_EXPENSE]);
    }

    public function isCreditAccount(): bool
    {
        return in_array($this->type, [self::TYPE_LIABILITY, self::TYPE_EQUITY, self::TYPE_INCOME]);
    }

    public function getBalance(\DateTime $date = null): float
    {
        if (!$date) {
            return (float) $this->current_balance;
        }

        $ledger = $this->generalLedger()
            ->where('date', '<=', $date->format('Y-m-d'))
            ->orderBy('date', 'desc')
            ->orderBy('id', 'desc')
            ->first();

        return $ledger ? (float) $ledger->balance : (float) $this->opening_balance;
    }

    public function getLedgerEntries(\DateTime $startDate = null, \DateTime $endDate = null)
    {
        $query = $this->generalLedger()
            ->orderBy('date')
            ->orderBy('id');

        if ($startDate) {
            $query->where('date', '>=', $startDate->format('Y-m-d'));
        }

        if ($endDate) {
            $query->where('date', '<=', $endDate->format('Y-m-d'));
        }

        return $query->get();
    }

    /**
     * Recalculate and update the current balance from general ledger
     *
     * @return void
     */
    public function recalculateBalance(): void
    {
        $latestEntry = $this->generalLedger()
            ->orderBy('date', 'desc')
            ->orderBy('id', 'desc')
            ->first();

        $newBalance = $latestEntry ? $latestEntry->balance : $this->opening_balance;

        $this->update(['current_balance' => $newBalance]);
    }

    /**
     * Scopes
     */
    public function scopeActive($query)
    {
        return $query->where('is_active', true);
    }

    public function scopeOfType($query, string $type)
    {
        return $query->where('type', $type);
    }

    public function scopeOfCategory($query, string $category)
    {
        return $query->where('category', $category);
    }

    public function scopeParents($query)
    {
        return $query->whereNull('parent_id');
    }
}
