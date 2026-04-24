<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Auth;

/**
 * Generic blob-store sync endpoint.
 *
 * Each Flutter device can push arbitrary JSON payloads keyed by
 * (company_id, entity_type, client_id).  Other devices pull the same
 * payloads back.  This avoids needing one server table per entity type
 * for locally-managed entities (bank transactions, asset drafts, etc.).
 *
 * Routes:
 *   GET  /client-data/{type}          — pull all records of a type
 *   POST /client-data/{type}          — bulk upsert records
 */
class ClientDataSyncController extends Controller
{
    // Allowed entity types (whitelist for security)
    private const ALLOWED_TYPES = [
        'bank-transactions',
        'asset-drafts',
        'depreciation-schedules',
        'bank-statements',
        'outlet-revenues',
        'outlet-expenditures',
        'outlet-settlements',
        'commission-payments',
    ];

    public function index(Request $request, string $type)
    {
        if (!in_array($type, self::ALLOWED_TYPES, true)) {
            return response()->json(['message' => 'Unknown entity type'], 422);
        }

        $companyId = $this->resolveCompanyId($request);
        if (!$companyId) {
            return response()->json(['message' => 'Company not found'], 403);
        }

        $rows = DB::table('client_sync_data')
            ->where('company_id', $companyId)
            ->where('entity_type', $type)
            ->orderBy('updated_at')
            ->pluck('payload');

        $data = $rows->map(fn($p) => json_decode($p, true))->values();

        return response()->json(['data' => $data]);
    }

    public function bulkUpsert(Request $request, string $type)
    {
        if (!in_array($type, self::ALLOWED_TYPES, true)) {
            return response()->json(['message' => 'Unknown entity type'], 422);
        }

        $companyId = $this->resolveCompanyId($request);
        if (!$companyId) {
            return response()->json(['message' => 'Company not found'], 403);
        }

        $records = $request->input('records');
        if (!is_array($records) || empty($records)) {
            return response()->json(['message' => 'No records provided'], 422);
        }

        $now = now()->toDateTimeString();
        $upserted = 0;

        foreach ($records as $record) {
            if (empty($record['id'])) {
                continue;
            }

            DB::table('client_sync_data')->upsert(
                [
                    'company_id'  => $companyId,
                    'entity_type' => $type,
                    'client_id'   => $record['id'],
                    'payload'     => json_encode($record),
                    'updated_at'  => $now,
                ],
                ['company_id', 'entity_type', 'client_id'],
                ['payload', 'updated_at']
            );

            $upserted++;
        }

        return response()->json([
            'message'  => 'Synced successfully',
            'upserted' => $upserted,
        ]);
    }

    private function resolveCompanyId(Request $request): ?int
    {
        // Multi-tenant: the X-Tenant-ID header holds the tenant slug;
        // resolve to the companies.id for storage.
        $tenantId = $request->header('X-Tenant-ID');

        if ($tenantId) {
            $company = DB::table('companies')
                ->where('tenant_id', $tenantId)
                ->orWhere('slug', $tenantId)
                ->first();
            if ($company) {
                return $company->id;
            }
        }

        // Fall back to the authenticated user's company
        $user = Auth::user();
        if ($user && isset($user->company_id)) {
            return $user->company_id;
        }

        return null;
    }
}
