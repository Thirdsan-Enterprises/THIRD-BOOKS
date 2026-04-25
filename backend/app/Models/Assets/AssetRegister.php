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

    // ── Status ───────────────────────────────────────────────────────────────

    const STATUS_ACTIVE     = 'active';
    const STATUS_DISPOSED   = 'disposed';
    const STATUS_DAMAGED    = 'damaged';
    const STATUS_WRITTEN_OFF = 'written_off';

    // ── Asset nature (IAS 16 tangible vs IAS 38 intangible) ──────────────────

    const NATURE_TANGIBLE   = 'tangible';
    const NATURE_INTANGIBLE = 'intangible';

    // ── Depreciation / amortization methods ──────────────────────────────────

    const METHOD_STRAIGHT_LINE     = 'straight_line';
    const METHOD_DECLINING_BALANCE = 'declining_balance';

    // ── Depreciation / amortization periods ──────────────────────────────────

    const PERIOD_MONTHLY = 'monthly';
    const PERIOD_YEARLY  = 'yearly';

    // ── Tangible asset categories (IAS 16 / PP&E) ────────────────────────────

    const TANGIBLE_CATEGORIES = [
        'Equipment', 'Vehicle', 'Furniture', 'Electronics',
        'Building', 'Land', 'Machinery',
    ];

    // ── Intangible asset categories (IAS 38) ─────────────────────────────────

    const INTANGIBLE_CATEGORIES = [
        'Software', 'License', 'Patent', 'Trademark', 'Goodwill',
    ];

    // Merged list for validation (both natures combined)
    const CATEGORIES = [
        'Equipment', 'Vehicle', 'Furniture', 'Electronics',
        'Building', 'Land', 'Machinery',
        'Software', 'License', 'Patent', 'Trademark', 'Goodwill',
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
        'asset_nature',
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
        return $this->hasMany(DepreciationEntry::class, 'asset_register_id')
            ->where('entry_type', 'depreciation');
    }

    public function amortizationEntries(): HasMany
    {
        return $this->hasMany(DepreciationEntry::class, 'asset_register_id')
            ->where('entry_type', 'amortization');
    }

    // ── Computed attributes ──────────────────────────────────────────────────

    public function getAccumulatedDepreciationAttribute(): float
    {
        return $this->isIntangible() ? 0.0 : ((float) $this->cost - (float) $this->current_book_value);
    }

    public function getAccumulatedAmortizationAttribute(): float
    {
        return $this->isIntangible() ? ((float) $this->cost - (float) $this->current_book_value) : 0.0;
    }

    public function getIsFullyDepreciatedAttribute(): bool
    {
        return !$this->isIntangible() && (float) $this->current_book_value <= (float) $this->salvage_value;
    }

    public function getIsFullyAmortizedAttribute(): bool
    {
        return $this->isIntangible() && (float) $this->current_book_value <= 0;
    }

    // ── Nature helpers ───────────────────────────────────────────────────────

    public function isIntangible(): bool
    {
        return $this->asset_nature === self::NATURE_INTANGIBLE;
    }

    public function isTangible(): bool
    {
        return $this->asset_nature !== self::NATURE_INTANGIBLE;
    }

    // ── Calculation — depreciation (tangible) ────────────────────────────────

    /**
     * Calculate the next depreciation amount for a tangible asset (does NOT persist).
     * Applies salvage value floor per IAS 16.
     */
    public function calculateNextDepreciation(): float
    {
        if (!$this->depreciation_method || !$this->depreciation_rate) {
            return 0;
        }

        $annualRate   = (float) $this->depreciation_rate / 100;
        $periodFactor = $this->depreciation_period === self::PERIOD_MONTHLY ? 1 / 12 : 1;
        $periodRate   = $annualRate * $periodFactor;
        $bookValue    = (float) $this->current_book_value;
        $salvage      = (float) $this->salvage_value;

        if ($this->depreciation_method === self::METHOD_DECLINING_BALANCE) {
            $amount = $bookValue * $periodRate;
        } else {
            // Straight-line: (cost − salvage) / total periods
            $usefulLifeYears = (float) ($this->useful_life_years ?? 5);
            $periods = $this->depreciation_period === self::PERIOD_MONTHLY
                ? $usefulLifeYears * 12
                : $usefulLifeYears;
            $amount = ((float) $this->cost - $salvage) / $periods;
        }

        // Never depreciate below salvage value (IAS 16.50)
        $amount = min($amount, $bookValue - $salvage);
        return max(0, round($amount, 4));
    }

    // ── Calculation — amortization (intangible) ──────────────────────────────

    /**
     * Calculate the next amortization amount for an intangible asset (does NOT persist).
     *
     * IAS 38 rules applied:
     *  - Straight-line is the required method (no declining-balance for intangibles)
     *  - Residual value is assumed zero unless a third-party purchase commitment exists
     *  - Amortizes fully to zero (no salvage floor)
     */
    public function calculateNextAmortization(): float
    {
        if (!$this->useful_life_years || !$this->depreciation_period) {
            return 0;
        }

        $bookValue = (float) $this->current_book_value;
        if ($bookValue <= 0) {
            return 0;
        }

        $usefulLifeYears = (float) $this->useful_life_years;
        $periods = $this->depreciation_period === self::PERIOD_MONTHLY
            ? $usefulLifeYears * 12
            : $usefulLifeYears;

        // Straight-line over cost (IAS 38: residual value = 0)
        $amount = (float) $this->cost / $periods;

        // Never amortize below zero
        $amount = min($amount, $bookValue);
        return max(0, round($amount, 4));
    }

    // ── Scopes ───────────────────────────────────────────────────────────────

    public function scopeActive($query)
    {
        return $query->where('status', self::STATUS_ACTIVE);
    }

    public function scopeTangible($query)
    {
        return $query->where('asset_nature', self::NATURE_TANGIBLE);
    }

    public function scopeIntangible($query)
    {
        return $query->where('asset_nature', self::NATURE_INTANGIBLE);
    }

    /** Active tangible assets with depreciation configured. */
    public function scopeDepreciable($query)
    {
        return $query->active()
            ->tangible()
            ->whereNotNull('depreciation_method')
            ->whereNotNull('depreciation_rate');
    }

    /** Active intangible assets with amortization period configured. */
    public function scopeAmortizable($query)
    {
        return $query->active()
            ->intangible()
            ->whereNotNull('useful_life_years')
            ->whereNotNull('depreciation_period');
    }

    // ── Static helpers ───────────────────────────────────────────────────────

    /**
     * Infer whether a CoA account represents an intangible asset.
     * Mirrors Flutter-side detection logic.
     */
    public static function inferNatureFromAccountName(string $name): string
    {
        $lower = strtolower($name);
        if (
            str_contains($lower, 'software') ||
            str_contains($lower, 'license') ||
            str_contains($lower, 'licence') ||
            str_contains($lower, 'patent') ||
            str_contains($lower, 'trademark') ||
            str_contains($lower, 'goodwill') ||
            str_contains($lower, 'intangible') ||
            str_contains($lower, 'copyright') ||
            str_contains($lower, 'franchise')
        ) {
            return self::NATURE_INTANGIBLE;
        }
        return self::NATURE_TANGIBLE;
    }

    /**
     * Infer asset category from a CoA account name.
     * Mirrors the _inferAssetCategory() function in the Flutter bills screen.
     */
    public static function inferCategoryFromAccountName(string $name): string
    {
        $lower = strtolower($name);

        // Intangible categories first
        if (str_contains($lower, 'software')) {
            return 'Software';
        }
        if (str_contains($lower, 'license') || str_contains($lower, 'licence')) {
            return 'License';
        }
        if (str_contains($lower, 'patent')) {
            return 'Patent';
        }
        if (str_contains($lower, 'trademark') || str_contains($lower, 'copyright') || str_contains($lower, 'franchise')) {
            return 'Trademark';
        }
        if (str_contains($lower, 'goodwill')) {
            return 'Goodwill';
        }

        // Tangible categories
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
