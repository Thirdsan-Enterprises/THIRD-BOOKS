<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('client_sync_data')) {
            return;
        }

        Schema::create('client_sync_data', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('company_id')->index();
            $table->string('entity_type', 64)->index();
            // client_id is the UUID the Flutter device assigned the record
            $table->string('client_id', 128);
            $table->json('payload');
            $table->timestamp('updated_at')->useCurrent()->useCurrentOnUpdate();

            // One canonical row per (company, type, client record)
            $table->unique(['company_id', 'entity_type', 'client_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('client_sync_data');
    }
};
