<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

// The original tenant audit_logs migration (000010) recorded as run on servers
// where the central migration had already created an audit_logs table with a
// different structure. This migration creates it idempotently.
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('audit_logs')) {
            return;
        }

        // Drop any stale foreign key constraints left from a partial prior migration
        // attempt — errno 121 (duplicate FK name) will block table creation otherwise.
        DB::statement('SET FOREIGN_KEY_CHECKS=0');
        try {
            DB::statement('ALTER TABLE audit_logs DROP FOREIGN KEY IF EXISTS audit_logs_company_id_foreign');
            DB::statement('ALTER TABLE audit_logs DROP FOREIGN KEY IF EXISTS audit_logs_user_id_foreign');
        } catch (\Throwable) {}
        DB::statement('SET FOREIGN_KEY_CHECKS=1');

        Schema::create('audit_logs', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('company_id');
            $table->unsignedBigInteger('user_id')->nullable();
            $table->string('action');
            $table->string('model_type');
            $table->unsignedBigInteger('model_id');
            $table->string('description')->nullable();
            $table->json('old_values')->nullable();
            $table->json('new_values')->nullable();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->timestamp('created_at');
            $table->index(['company_id', 'created_at']);
            $table->index(['model_type', 'model_id']);
            $table->index('user_id');

            // Use distinct constraint names to avoid collision with stale metadata
            $table->foreign('company_id', 'tal_company_fk')
                  ->references('id')->on('companies')->cascadeOnDelete();
            $table->foreign('user_id', 'tal_user_fk')
                  ->references('id')->on('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('audit_logs');
    }
};
