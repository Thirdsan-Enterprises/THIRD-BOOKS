<?php

namespace App\Models\Assets;

use App\Models\Accounting\JournalEntry;
use App\Models\Company;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DepreciationEntry extends Model
{
    use HasFactory;

    protected $table = 'depreciation_entries';

    const STATUS_POSTED   = 'posted';
    const STATUS_REVERSED = 'reversed';

    protected $fillable = [
        'company_id',
        'asset_register_id',
        'journal_entry_id',
        'period_date',
        'period_label',
        'depreciation_amount',
        'accumulated_depreciation',
        'book_value_after',
        'method',
        'rate_used',
        'status',
        'created_by',
    ];

    protected $casts = [
        'period_date'              => 'date',
        'depreciation_amount'      => 'decimal:4',
        'accumulated_depreciation' => 'decimal:4',
        'book_value_after'         => 'decimal:4',
        'rate_used'                => 'decimal:4',
    ];

    public function asset(): BelongsTo
    {
        return $this->belongsTo(AssetRegister::class, 'asset_register_id');
    }

    public function journalEntry(): BelongsTo
    {
        return $this->belongsTo(JournalEntry::class);
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
