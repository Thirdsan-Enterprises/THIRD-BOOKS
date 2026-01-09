<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('sync_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('company_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();

            $table->string('entity_type'); // Invoice, Payment, JournalEntry, etc.
            $table->unsignedBigInteger('entity_id');
            $table->enum('action', ['create', 'update', 'delete']);
            $table->enum('sync_status', ['pending', 'synced', 'conflict', 'failed'])->default('pending');

            $table->json('data')->nullable(); // Sync payload
            $table->json('conflict_data')->nullable(); // If conflict detected
            $table->text('error_message')->nullable();

            $table->timestamp('synced_at')->nullable();
            $table->integer('retry_count')->default(0);

            $table->timestamps();

            $table->index(['company_id', 'sync_status']);
            $table->index(['entity_type', 'entity_id']);
            $table->index('user_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('sync_logs');
    }
};
