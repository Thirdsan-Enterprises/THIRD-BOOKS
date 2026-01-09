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
        Schema::create('tenants', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('name');
            $table->string('company_name');
            $table->string('email')->unique();
            $table->string('phone')->nullable();
            $table->text('address')->nullable();
            $table->string('country', 2)->default('UG'); // ISO 3166-1 alpha-2
            $table->string('base_currency', 3)->default('UGX'); // ISO 4217
            $table->string('fiscal_year_start', 5)->default('01-01'); // MM-DD format

            // Subscription
            $table->string('plan')->default('trial'); // trial, basic, premium, enterprise
            $table->timestamp('trial_ends_at')->nullable();
            $table->timestamp('subscription_ends_at')->nullable();
            $table->string('status')->default('active'); // active, suspended, cancelled

            // Settings and metadata
            $table->json('settings')->nullable();
            $table->json('data')->nullable();

            $table->timestamps();
            $table->softDeletes();

            // Indexes
            $table->index('email');
            $table->index('status');
            $table->index('plan');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('tenants');
    }
};
