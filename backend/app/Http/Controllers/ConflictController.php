<?php

namespace App\Http\Controllers;

use App\Models\Sync\Conflict;
use App\Services\Sync\EventSourceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class ConflictController extends Controller
{
    public function __construct(
        protected EventSourceService $eventSourceService
    ) {}

    /**
     * Get all conflicts for the tenant
     */
    public function index(Request $request): JsonResponse
    {
        $query = Conflict::where('tenant_id', tenant('id'));

        // Filter by status
        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        // Filter by aggregate type
        if ($request->has('aggregate_type')) {
            $query->where('aggregate_type', $request->aggregate_type);
        }

        // Filter by device
        if ($request->has('device_id')) {
            $query->forDevice($request->device_id);
        }

        $conflicts = $query
            ->with(['serverEvent', 'clientEvent'])
            ->orderBy('created_at', 'desc')
            ->paginate($request->per_page ?? 20);

        return response()->json($conflicts);
    }

    /**
     * Get a specific conflict with details
     */
    public function show(string $id): JsonResponse
    {
        $conflict = Conflict::where('tenant_id', tenant('id'))
            ->with(['serverEvent', 'clientEvent'])
            ->findOrFail($id);

        // Get field-level conflicts
        $conflictFields = $conflict->identifyConflictFields();

        return response()->json([
            'conflict' => $conflict,
            'conflict_fields' => $conflictFields,
        ]);
    }

    /**
     * Resolve conflict with server data
     */
    public function resolveWithServer(string $id): JsonResponse
    {
        $conflict = Conflict::where('tenant_id', tenant('id'))
            ->where('status', 'pending')
            ->findOrFail($id);

        $conflict->resolveWithServer(Auth::id());

        return response()->json([
            'message' => 'Conflict resolved with server data',
            'conflict' => $conflict->fresh(),
        ]);
    }

    /**
     * Resolve conflict with client data
     */
    public function resolveWithClient(string $id): JsonResponse
    {
        $conflict = Conflict::where('tenant_id', tenant('id'))
            ->where('status', 'pending')
            ->findOrFail($id);

        $conflict->resolveWithClient(Auth::id());

        return response()->json([
            'message' => 'Conflict resolved with client data',
            'conflict' => $conflict->fresh(),
        ]);
    }

    /**
     * Resolve conflict with custom merged data
     */
    public function resolveWithMerge(Request $request, string $id): JsonResponse
    {
        $request->validate([
            'merged_data' => 'required|array',
        ]);

        $conflict = Conflict::where('tenant_id', tenant('id'))
            ->where('status', 'pending')
            ->findOrFail($id);

        $conflict->resolveWithMerge($request->merged_data, Auth::id());

        return response()->json([
            'message' => 'Conflict resolved with merged data',
            'conflict' => $conflict->fresh(),
        ]);
    }

    /**
     * Ignore conflict
     */
    public function ignore(string $id): JsonResponse
    {
        $conflict = Conflict::where('tenant_id', tenant('id'))
            ->where('status', 'pending')
            ->findOrFail($id);

        $conflict->ignore(Auth::id());

        return response()->json([
            'message' => 'Conflict ignored',
            'conflict' => $conflict->fresh(),
        ]);
    }

    /**
     * Bulk resolve conflicts with a specific strategy
     */
    public function bulkResolve(Request $request): JsonResponse
    {
        $request->validate([
            'conflict_ids' => 'required|array',
            'conflict_ids.*' => 'uuid|exists:conflicts,id',
            'strategy' => 'required|in:server_wins,client_wins,last_write_wins',
        ]);

        $resolved = 0;
        $failed = 0;

        foreach ($request->conflict_ids as $conflictId) {
            try {
                $conflict = Conflict::where('tenant_id', tenant('id'))
                    ->where('status', 'pending')
                    ->findOrFail($conflictId);

                $conflict->autoResolve($request->strategy);
                $resolved++;
            } catch (\Exception $e) {
                $failed++;
            }
        }

        return response()->json([
            'message' => "Resolved {$resolved} conflicts, {$failed} failed",
            'resolved' => $resolved,
            'failed' => $failed,
        ]);
    }

    /**
     * Get conflict statistics
     */
    public function statistics(): JsonResponse
    {
        $tenantId = tenant('id');

        $stats = [
            'total' => Conflict::where('tenant_id', $tenantId)->count(),
            'pending' => Conflict::where('tenant_id', $tenantId)->pending()->count(),
            'resolved' => Conflict::where('tenant_id', $tenantId)->resolved()->count(),
            'by_type' => Conflict::where('tenant_id', $tenantId)
                ->selectRaw('conflict_type, COUNT(*) as count')
                ->groupBy('conflict_type')
                ->get()
                ->pluck('count', 'conflict_type'),
            'by_aggregate' => Conflict::where('tenant_id', $tenantId)
                ->selectRaw('aggregate_type, COUNT(*) as count')
                ->groupBy('aggregate_type')
                ->get()
                ->pluck('count', 'aggregate_type'),
        ];

        return response()->json($stats);
    }
}
