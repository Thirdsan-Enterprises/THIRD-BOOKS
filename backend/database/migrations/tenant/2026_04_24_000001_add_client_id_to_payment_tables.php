<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Add client_id (Flutter UUID) to payments and bill_payments tables.
 * Used for idempotent upserts when the Flutter client syncs payment records.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('payments') && !Schema::hasColumn('payments', 'client_id')) {
            Schema::table('payments', function (Blueprint $table) {
                $table->string('client_id', 64)->nullable()->unique()->after('id');
            });
        }

        if (Schema::hasTable('bill_payments') && !Schema::hasColumn('bill_payments', 'client_id')) {
            Schema::table('bill_payments', function (Blueprint $table) {
                $table->string('client_id', 64)->nullable()->unique()->after('id');
            });
        }
    }

    public function down(): void
    {
        Schema::table('payments', fn(Blueprint $t) => $t->dropColumn('client_id'));
        Schema::table('bill_payments', fn(Blueprint $t) => $t->dropColumn('client_id'));
    }
};
