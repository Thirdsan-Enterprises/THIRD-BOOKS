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
        Schema::create('conflicts', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('tenant_id')->index();

            // The conflicting events
            $table->uuid('server_event_id')->index();
            $table->uuid('client_event_id')->index();

            // Conflict metadata
            $table->string('aggregate_type'); // invoice, bill, payment, etc
            $table->uuid('aggregate_id')->index();
            $table->string('conflict_type'); // concurrent_update, delete_modified, etc

            // Event data for comparison
            $table->json('server_data');
            $table->json('client_data');
            $table->json('conflict_fields')->nullable(); // Which fields differ

            // Resolution
            $table->string('resolution_strategy')->nullable(); // server_wins, client_wins, merge, manual
            $table->json('resolved_data')->nullable();
            $table->uuid('resolved_by')->nullable(); // User who resolved
            $table->timestamp('resolved_at')->nullable();

            // Device info
            $table->string('server_device_id')->nullable();
            $table->string('client_device_id');

            // Status
            $table->string('status')->default('pending'); // pending, resolved, ignored

            $table->timestamps();

            // Foreign keys
            $table->foreign('server_event_id')->references('id')->on('events')->onDelete('cascade');
            $table->foreign('client_event_id')->references('id')->on('events')->onDelete('cascade');

            // Indexes for querying
            $table->index(['tenant_id', 'status']);
            $table->index(['aggregate_type', 'aggregate_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('conflicts');
    }
};
