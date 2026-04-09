<?php

namespace App\Models;

use App\Traits\BelongsToCompany;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\MorphTo;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Support\Facades\Storage;

class Attachment extends Model
{
    use HasFactory, SoftDeletes, BelongsToCompany;

    protected $fillable = [
        'company_id',
        'attachable_type',
        'attachable_id',
        'file_name',
        'file_path',
        'disk',
        'mime_type',
        'file_size',
        'label',
        'uploaded_by',
    ];

    protected $casts = [
        'file_size' => 'integer',
    ];

    protected $appends = ['url', 'size_human'];

    /**
     * The parent model (JournalEntry, Invoice, Bill, BillPayment, Payment, etc.)
     */
    public function attachable(): MorphTo
    {
        return $this->morphTo();
    }

    public function uploader(): BelongsTo
    {
        return $this->belongsTo(User::class, 'uploaded_by');
    }

    /**
     * Public URL accessor — returns a temporary signed URL (S3) or a local URL.
     */
    public function getUrlAttribute(): ?string
    {
        if (!$this->file_path) {
            return null;
        }

        if ($this->disk === 's3') {
            return Storage::disk('s3')->temporaryUrl($this->file_path, now()->addHours(1));
        }

        return Storage::disk($this->disk)->url($this->file_path);
    }

    /**
     * Human-readable file size.
     */
    public function getSizeHumanAttribute(): string
    {
        $bytes = $this->file_size ?? 0;

        if ($bytes >= 1048576) {
            return round($bytes / 1048576, 1) . ' MB';
        }
        if ($bytes >= 1024) {
            return round($bytes / 1024, 1) . ' KB';
        }

        return $bytes . ' B';
    }

    /**
     * Delete the physical file when the model is permanently deleted.
     */
    protected static function boot(): void
    {
        parent::boot();

        static::forceDeleting(function (Attachment $attachment) {
            if ($attachment->file_path) {
                Storage::disk($attachment->disk)->delete($attachment->file_path);
            }
        });
    }
}
