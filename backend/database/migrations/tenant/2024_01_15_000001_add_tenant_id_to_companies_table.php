<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Adds tenant_id to companies table for single-database multi-tenancy mode.
     * This enables data isolation at the company level within a shared database.
     */
    public function up(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            // Add tenant_id as UUID to match tenants table primary key
            $table->uuid('tenant_id')->nullable()->after('id');

            // Add index for faster lookups
            $table->index('tenant_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('companies', function (Blueprint $table) {
            $table->dropIndex(['tenant_id']);
            $table->dropColumn('tenant_id');
        });
    }
};
