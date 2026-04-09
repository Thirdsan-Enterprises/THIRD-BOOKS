<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Polymorphic attachments — any model (JournalEntry, Invoice, Bill,
     * BillPayment, Payment) can have multiple file attachments.
     */
    public function up(): void
    {
        Schema::create('attachments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();

            // Polymorphic relation: attachable_type + attachable_id
            $table->morphs('attachable');

            $table->string('file_name');           // Original filename shown to user
            $table->string('file_path');           // Storage path (relative to disk root)
            $table->string('disk')->default('local'); // Storage disk (local, s3, etc.)
            $table->string('mime_type')->nullable();
            $table->unsignedBigInteger('file_size')->nullable(); // bytes
            $table->string('label')->nullable();   // Optional human label, e.g. "Receipt", "Invoice copy"

            $table->foreignId('uploaded_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->softDeletes();

            $table->index(['attachable_type', 'attachable_id']);
            $table->index('company_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('attachments');
    }
};
