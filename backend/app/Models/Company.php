<?php

namespace App\Models;

use App\Models\Accounting\Account;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Company extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'name',
        'legal_name',
        'tax_id',
        'registration_number',
        'email',
        'phone',
        'address',
        'city',
        'state',
        'postal_code',
        'country',
        'base_currency',
        'fiscal_year_start',
        'fiscal_year_end',
        'logo_url',
        'settings',
    ];

    protected $casts = [
        'settings' => 'array',
    ];

    protected $attributes = [
        'country' => 'UG',
        'base_currency' => 'UGX',
        'fiscal_year_start' => '01-01',
        'fiscal_year_end' => '12-31',
    ];

    /**
     * Get the base currency
     */
    public function baseCurrency(): BelongsTo
    {
        return $this->belongsTo(Currency::class, 'base_currency', 'code');
    }

    /**
     * Get all accounts
     */
    public function accounts(): HasMany
    {
        return $this->hasMany(Account::class);
    }

    /**
     * Get all journal entries
     */
    public function journalEntries(): HasMany
    {
        return $this->hasMany(\App\Models\Accounting\JournalEntry::class);
    }

    /**
     * Get all customers
     */
    public function customers(): HasMany
    {
        return $this->hasMany(\App\Models\Sales\Customer::class);
    }

    /**
     * Get all invoices
     */
    public function invoices(): HasMany
    {
        return $this->hasMany(\App\Models\Sales\Invoice::class);
    }

    /**
     * Get all vendors
     */
    public function vendors(): HasMany
    {
        return $this->hasMany(\App\Models\Purchases\Vendor::class);
    }

    /**
     * Get all bills
     */
    public function bills(): HasMany
    {
        return $this->hasMany(\App\Models\Purchases\Bill::class);
    }

    /**
     * Get setting value
     */
    public function getSetting(string $key, $default = null)
    {
        return data_get($this->settings, $key, $default);
    }

    /**
     * Set setting value
     */
    public function setSetting(string $key, $value): void
    {
        $settings = $this->settings ?? [];
        data_set($settings, $key, $value);
        $this->settings = $settings;
        $this->save();
    }

    /**
     * Check if fiscal year date is in current fiscal year
     */
    public function isInCurrentFiscalYear(\DateTime $date): bool
    {
        $startMonth = (int) substr($this->fiscal_year_start, 0, 2);
        $startDay = (int) substr($this->fiscal_year_start, 3, 2);

        $currentYear = (int) $date->format('Y');
        $currentMonth = (int) $date->format('m');
        $currentDay = (int) $date->format('d');

        if ($currentMonth > $startMonth || ($currentMonth === $startMonth && $currentDay >= $startDay)) {
            $fiscalYearStart = new \DateTime("{$currentYear}-{$this->fiscal_year_start}");
            $fiscalYearEnd = new \DateTime(($currentYear + 1) . "-{$this->fiscal_year_end}");
        } else {
            $fiscalYearStart = new \DateTime(($currentYear - 1) . "-{$this->fiscal_year_start}");
            $fiscalYearEnd = new \DateTime("{$currentYear}-{$this->fiscal_year_end}");
        }

        return $date >= $fiscalYearStart && $date <= $fiscalYearEnd;
    }
}
