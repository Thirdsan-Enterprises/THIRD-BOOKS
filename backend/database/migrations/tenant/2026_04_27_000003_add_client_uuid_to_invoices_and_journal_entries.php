<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Add client_uuid to invoices and journal_entries so the server can resolve
 * records by the UUID that desktop clients assign locally.
 *
 * Desktop clients use UUID primary keys; server tables use auto-increment
 * integer PKs.  Without this column every PUT /invoices/{uuid} and
 * PUT /journal-entries/{uuid} returns 404, meaning only the initial POST
 * (create) ever reaches the server — status updates, edits, and posting
 * are silently dropped.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            $table->string('client_uuid', 36)->nullable()->unique()->after('id');
        });

        Schema::table('journal_entries', function (Blueprint $table) {
            $table->string('client_uuid', 36)->nullable()->unique()->after('id');
        });
    }

    public function down(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            $table->dropColumn('client_uuid');
        });

        Schema::table('journal_entries', function (Blueprint $table) {
            $table->dropColumn('client_uuid');
        });
    }
};
