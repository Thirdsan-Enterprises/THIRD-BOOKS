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
        Schema::create('events', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id')->index();
            $table->string('aggregate_type'); // invoice, payment, bill, etc
            $table->uuid('aggregate_id')->index(); // ID of the entity
            $table->string('event_type'); // invoice.created, payment.recorded, etc
            $table->json('event_data'); // The actual event payload
            $table->json('metadata')->nullable(); // User info, IP, device, etc
            $table->unsignedBigInteger('sequence_number')->index(); // Global sequence
            $table->string('device_id')->nullable()->index(); // Which device created it
            $table->uuid('user_id')->index();
            $table->timestamp('occurred_at')->useCurrent();
            $table->timestamp('synced_at')->nullable();
            $table->timestamps();

            // Ensure sequence numbers are unique per tenant
            $table->unique(['tenant_id', 'sequence_number']);

            // Index for sync queries
            $table->index(['tenant_id', 'occurred_at']);
            $table->index(['tenant_id', 'synced_at']);
        });

        Schema::create('sync_queue', function (Blueprint $table) {
            $table->id();
            $table->uuid('tenant_id')->index();
            $table->uuid('event_id');
            $table->string('device_id')->index();
            $table->enum('status', ['pending', 'syncing', 'synced', 'failed'])->default('pending');
            $table->text('error_message')->nullable();
            $table->integer('attempts')->default(0);
            $table->timestamp('last_attempt_at')->nullable();
            $table->timestamps();

            $table->foreign('event_id')->references('id')->on('events')->onDelete('cascade');
            $table->index(['tenant_id', 'status']);
            $table->index(['device_id', 'status']);
        });

        Schema::create('device_sync_state', function (Blueprint $table) {
            $table->id();
            $table->uuid('tenant_id')->index();
            $table->string('device_id')->index();
            $table->string('device_name');
            $table->string('device_type'); // mobile, web, desktop
            $table->unsignedBigInteger('last_synced_sequence')->default(0);
            $table->timestamp('last_sync_at')->nullable();
            $table->json('sync_metadata')->nullable(); // App version, OS, etc
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            $table->unique(['tenant_id', 'device_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('sync_queue');
        Schema::dropIfExists('device_sync_state');
        Schema::dropIfExists('events');
    }
};
