<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Extend asset_registers with an asset_nature field ('tangible' | 'intangible')
     * so that software, patents, and licenses are tracked separately from PP&E.
     *
     * Extend depreciation_entries with entry_type ('depreciation' | 'amortization')
     * so that reports can distinguish the two non-cash charges.
     */
    public function up(): void
    {
        Schema::table('asset_registers', function (Blueprint $table) {
            // 'tangible' keeps all existing rows working unchanged
            $table->string('asset_nature', 20)->default('tangible')->after('status');
            $table->index(['company_id', 'asset_nature']);
        });

        Schema::table('depreciation_entries', function (Blueprint $table) {
            $table->string('entry_type', 20)->default('depreciation')->after('status');
            $table->index(['company_id', 'entry_type', 'period_date']);
        });
    }

    public function down(): void
    {
        Schema::table('asset_registers', function (Blueprint $table) {
            $table->dropIndex(['company_id', 'asset_nature']);
            $table->dropColumn('asset_nature');
        });

        Schema::table('depreciation_entries', function (Blueprint $table) {
            $table->dropIndex(['company_id', 'entry_type', 'period_date']);
            $table->dropColumn('entry_type');
        });
    }
};
