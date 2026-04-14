<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * AccountDataController
 *
 * Allows an authenticated client to permanently delete all their own
 * data from the system. This is the "Right to Erasure" / data-management
 * endpoint. Only the authenticated user's tenant data is affected.
 *
 * Deleted entities (tenant-scoped):
 *   - bank_statements + bank_statement_lines + reconciliation_items
 *   - asset_registers + depreciation_entries
 *   - credit_notes + debit_notes
 *   - attachments + audit_logs
 *   - invoices + invoice_lines
 *   - bills + bill_lines
 *   - journal_entries + journal_lines
 *   - payments
 *   - customers
 *   - vendors
 *   - accounts (non-system)
 *   - events (sync log)
 *   - sync_queue, device_sync_state, conflicts
 *
 * The tenant record itself and the user account are NOT deleted here —
 * use the admin panel for full tenant removal.
 */
class AccountDataController extends Controller
{
    /**
     * DELETE /api/me/data
     *
     * Permanently deletes all tenant business data for the authenticated user.
     * Requires confirmation header to prevent accidental calls.
     */
    public function deleteAllData(Request $request): JsonResponse
    {
        $request->validate([
            'confirmation' => 'required|in:DELETE_ALL_MY_DATA',
        ]);

        $user = $request->user();

        // Resolve the tenant database connection
        // With Stancl Tenancy the tenant context is already initialised by
        // the 'tenant' middleware. We use the default connection here because
        // this route sits outside the tenant middleware group intentionally —
        // we manually scope every query by tenant_id for safety.
        $tenantId = $user->tenant_id;

        if (!$tenantId) {
            return response()->json([
                'message' => 'Unable to identify tenant. Please contact support.',
            ], 422);
        }

        Log::warning('AccountDataController: deleteAllData requested', [
            'user_id'   => $user->id,
            'tenant_id' => $tenantId,
            'ip'        => $request->ip(),
        ]);

        try {
            DB::transaction(function () use ($tenantId) {
                // Resolve all company IDs that belong to this tenant.
                // Many tables scope by company_id rather than tenant_id directly.
                $companyIds = DB::table('companies')
                    ->where('tenant_id', $tenantId)
                    ->pluck('id');

                // Sync / events tables
                DB::table('sync_queue')->where('tenant_id', $tenantId)->delete();
                DB::table('device_sync_state')->where('tenant_id', $tenantId)->delete();
                DB::table('conflicts')->where('tenant_id', $tenantId)->delete();
                DB::table('events')->where('tenant_id', $tenantId)->delete();

                if ($companyIds->isNotEmpty()) {
                    // ── Banking ─────────────────────────────────────────────────────
                    // Deleting bank_statements cascades → bank_statement_lines
                    //   → reconciliation_items (both have cascadeOnDelete FKs).
                    // Must come BEFORE accounts because bank_account_id has restrictOnDelete.
                    DB::table('bank_statements')
                        ->whereIn('company_id', $companyIds)
                        ->delete();

                    // ── Asset Register ───────────────────────────────────────────────
                    // Deleting asset_registers cascades → depreciation_entries.
                    DB::table('asset_registers')
                        ->whereIn('company_id', $companyIds)
                        ->delete();

                    // ── Credit / Debit Notes ─────────────────────────────────────────
                    // customer_id / vendor_id use restrictOnDelete, so notes must be
                    // removed BEFORE customers and vendors are deleted below.
                    DB::table('credit_notes')
                        ->whereIn('company_id', $companyIds)
                        ->delete();
                    DB::table('debit_notes')
                        ->whereIn('company_id', $companyIds)
                        ->delete();

                    // ── Attachments ──────────────────────────────────────────────────
                    // Polymorphic — no automatic cascade from parent models.
                    DB::table('attachments')
                        ->whereIn('company_id', $companyIds)
                        ->delete();

                    // ── Audit Logs ───────────────────────────────────────────────────
                    DB::table('audit_logs')
                        ->whereIn('company_id', $companyIds)
                        ->delete();
                }

                // Financial transaction data
                DB::table('invoice_lines')
                    ->whereIn('invoice_id', function ($q) use ($tenantId) {
                        $q->select('id')->from('invoices')->where('tenant_id', $tenantId);
                    })->delete();
                DB::table('invoices')->where('tenant_id', $tenantId)->forceDelete();

                DB::table('bill_lines')
                    ->whereIn('bill_id', function ($q) use ($tenantId) {
                        $q->select('id')->from('bills')->where('tenant_id', $tenantId);
                    })->delete();
                DB::table('bills')->where('tenant_id', $tenantId)->forceDelete();

                DB::table('journal_lines')
                    ->whereIn('journal_entry_id', function ($q) use ($tenantId) {
                        $q->select('id')->from('journal_entries')->where('tenant_id', $tenantId);
                    })->delete();
                DB::table('journal_entries')->where('tenant_id', $tenantId)->forceDelete();

                DB::table('payments')->where('tenant_id', $tenantId)->forceDelete();

                // Master data
                DB::table('customers')->where('tenant_id', $tenantId)->forceDelete();
                DB::table('vendors')->where('tenant_id', $tenantId)->forceDelete();

                // Only delete user-created accounts, keep system defaults
                DB::table('accounts')
                    ->where('tenant_id', $tenantId)
                    ->where('is_system_account', false)
                    ->forceDelete();
            });

            Log::info('AccountDataController: deleteAllData completed', [
                'tenant_id' => $tenantId,
            ]);

            return response()->json([
                'message' => 'All data has been permanently deleted. System account defaults have been preserved.',
            ]);
        } catch (\Throwable $e) {
            Log::error('AccountDataController: deleteAllData failed', [
                'tenant_id' => $tenantId,
                'error'     => $e->getMessage(),
            ]);

            return response()->json([
                'message' => 'Failed to delete data. Please try again or contact support.',
                'error'   => $e->getMessage(),
            ], 500);
        }
    }
}
