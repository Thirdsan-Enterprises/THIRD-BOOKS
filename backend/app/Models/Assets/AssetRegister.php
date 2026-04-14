<?php

namespace App\Models\Assets;

use App\Models\Accounting\Account;
use App\Models\Company;
use App\Models\Purchases\Bill;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class AssetRegister extends Model
{
    use HasFactory, SoftDeletes;

    protected $table = 'asset_registers';

    const STATUS_ACTIVE     = 'active';
    const STATUS_DISPOSED   = 'disposed';
    const STATUS_DAMAGED    = 'damaged';
    const STATUS_WRITTEN_OFF = 'written_off';

    const METHOD_STRAIGHT_LINE     = 'straight_line';
    const METHOD_DECLINING_BALANCE = 'declining_balance';

    const PERIOD_MONTHLY = 'monthly';
    const PERIOD_YEARLY  = 'yearly';

    const CATEGORIES = [
        'Equipment', 'Vehicle', 'Furniture', 'Electronics',
        'Building', 'Land', 'Machinery',
    ];

    protected $fillable = [
        'company_id',
        'bill_id',
        'bill_line_id',
        'coa_account_id',
        'asset_code',
        'name',
        'category',
        'description',
        'cost',
        'salvage_value',
        'current_book_value',
        'currency_code',
        'acquisition_date',
        'disposal_date',
        'status',
        'location',
        'responsible_person',
        'depreciation_method',
        'depreciation_rate',
        'depreciation_period',
        'useful_life_years',
        'depreciation_start_date',
        'last_depreciation_date',
        'created_by',
    ];

    protected $casts = [
        'cost'                    => 'decimal:4',
        'salvage_value'           => 'decimal:4',
        'current_book_value'      => 'decimal:4',
        'depreciation_rate'       => 'decimal:4',
        'useful_life_years'       => 'decimal:2',
        'acquisition_date'        => 'date',
        'disposal_date'           => 'date',
        'depreciation_start_date' => 'date',
        'last_depreciation_date'  => 'date',
    ];

    // ── Relationships ────────────────────────────────────────────────────────

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function bill(): BelongsTo
    {
        return $this->belongsTo(Bill::class);
    }

    public function coaAccount(): BelongsTo
    {
        return $this->belongsTo(Account::class, 'coa_account_id');
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    public function depreciationEntries(): HasMany
    {
        return $this->hasMany(DepreciationEntry::class, 'asset_register_id');
    }

    // ── Computed attributes ──────────────────────────────────────────────────

    public function getAccumulatedDepreciationAttribute(): float
    {
        return (float) $this->cost - (float) $this->current_book_value;
    }

    public function getIsFullyDepreciatedAttribute(): bool
    {
        return (float) $this->current_book_value <= (float) $this->salvage_value;
    }

    /**
     * Calculate the next depreciation amount (does NOT persist).
     */
    public function calculateNextDepreciation(): float
    {
        if (!$this->depreciation_method || !$this->depreciation_rate) {
            return 0;
        }

        $annualRate    = (float) $this->depreciation_rate / 100;
        $periodFactor  = $this->depreciation_period === self::PERIOD_MONTHLY ? 1 / 12 : 1;
        $periodRate    = $annualRate * $periodFactor;
        $bookValue     = (float) $this->current_book_value;
        $salvage       = (float) $this->salvage_value;

        if ($this->depreciation_method === self::METHOD_DECLINING_BALANCE) {
            $amount = $bookValue * $periodRate;
        } else {
            // Straight-line: (cost − salvage) / useful_life periods
            $usefulLifeYears = (float) ($this->useful_life_years ?? 5);
            $periods = $this->depreciation_period === self::PERIOD_MONTHLY
                ? $usefulLifeYears * 12
                : $usefulLifeYears;
            $amount = ((float) $this->cost - $salvage) / $periods;
        }

        // Never depreciate below salvage value
        $amount = min($amount, $bookValue - $salvage);
        return max(0, round($amount, 4));
    }

    // ── Scopes ───────────────────────────────────────────────────────────────

    public function scopeActive($query)
    {
        return $query->where('status', self::STATUS_ACTIVE);
    }

    public function scopeDepreciable($query)
    {
        return $query->active()
            ->whereNotNull('depreciation_method')
            ->whereNotNull('depreciation_rate');
    }

    /**
     * Infer asset category from a CoA account name.
     * Mirrors the _inferAssetCategory() function in the Flutter bills screen.
     */
    public static function inferCategoryFromAccountName(string $name): string
    {
        $lower = strtolower($name);
        if (str_contains($lower, 'vehicle') || str_contains($lower, 'motor') || str_contains($lower, 'car')) {
            return 'Vehicle';
        }
        if (str_contains($lower, 'furniture') || str_contains($lower, 'fittings')) {
            return 'Furniture';
        }
        if (str_contains($lower, 'computer') || str_contains($lower, 'laptop') ||
            str_contains($lower, 'electronic') || str_contains($lower, 'phone')) {
            return 'Electronics';
        }
        if (str_contains($lower, 'building') || str_contains($lower, 'premises') ||
            str_contains($lower, 'property')) {
            return 'Building';
        }
        if (str_contains($lower, 'land') || str_contains($lower, 'plot')) {
            return 'Land';
        }
        if (str_contains($lower, 'machine') || str_contains($lower, 'machinery') ||
            str_contains($lower, 'plant')) {
            return 'Machinery';
        }
        return 'Equipment';
    }
}
