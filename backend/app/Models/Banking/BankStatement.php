<?php

namespace App\Models\Banking;

use App\Models\Accounting\Account;
use App\Models\Attachment;
use App\Models\Company;
use App\Models\User;
use App\Traits\BelongsToCompany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class BankStatement extends Model
{
    use HasFactory, SoftDeletes, BelongsToCompany;

    protected $fillable = [
        'company_id',
        'bank_account_id',
        'reference_number',
        'from_date',
        'to_date',
        'opening_balance',
        'closing_balance',
        'file_name',
        'file_path',
        'disk',
        'status',
        'notes',
        'uploaded_by',
    ];

    protected $casts = [
        'from_date' => 'date',
        'to_date' => 'date',
        'opening_balance' => 'decimal:4',
        'closing_balance' => 'decimal:4',
    ];

    protected $attributes = [
        'opening_balance' => 0,
        'closing_balance' => 0,
        'status' => 'pending',
        'disk' => 'local',
    ];

    const STATUS_PENDING = 'pending';
    const STATUS_IN_PROGRESS = 'in_progress';
    const STATUS_RECONCILED = 'reconciled';

    public function company(): BelongsTo
    {
        return $this->belongsTo(Company::class);
    }

    public function bankAccount(): BelongsTo
    {
        return $this->belongsTo(Account::class, 'bank_account_id');
    }

    public function uploader(): BelongsTo
    {
        return $this->belongsTo(User::class, 'uploaded_by');
    }

    public function lines(): HasMany
    {
        return $this->hasMany(BankStatementLine::class);
    }

    public function attachments(): MorphMany
    {
        return $this->morphMany(Attachment::class, 'attachable');
    }

    /**
     * Total lines on this statement.
     */
    public function getTotalLinesAttribute(): int
    {
        return $this->lines()->count();
    }

    /**
     * Lines not yet reconciled.
     */
    public function getUnmatchedLinesAttribute(): int
    {
        return $this->lines()->where('status', BankStatementLine::STATUS_UNMATCHED)->count();
    }

    /**
     * Recompute statement status from its lines.
     */
    public function refreshStatus(): void
    {
        $lines = $this->lines()->count();
        if ($lines === 0) {
            return;
        }

        $reconciled = $this->lines()->where('status', BankStatementLine::STATUS_RECONCILED)->count();

        if ($reconciled === $lines) {
            $this->status = self::STATUS_RECONCILED;
        } elseif ($reconciled > 0 || $this->lines()->where('status', BankStatementLine::STATUS_PARTIAL)->exists()) {
            $this->status = self::STATUS_IN_PROGRESS;
        } else {
            $this->status = self::STATUS_PENDING;
        }

        $this->saveQuietly();
    }
}
