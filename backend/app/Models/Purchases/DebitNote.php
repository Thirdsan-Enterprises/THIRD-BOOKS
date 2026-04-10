<?php

namespace App\Models\Purchases;

use App\Traits\BelongsToCompany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class DebitNote extends Model
{
    use HasFactory, SoftDeletes, BelongsToCompany;

    protected $fillable = [
        'company_id',
        'vendor_id',
        'bill_id',
        'journal_entry_id',
        'debit_note_number',
        'date',
        'reason',
        'notes',
        'currency_code',
        'amount',
        'status',
    ];

    protected $casts = [
        'date' => 'date',
        'amount' => 'decimal:4',
    ];

    public function vendor(): BelongsTo
    {
        return $this->belongsTo(Vendor::class);
    }

    public function bill(): BelongsTo
    {
        return $this->belongsTo(Bill::class);
    }
}
