<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class AuditLogController extends Controller
{
    /**
     * Get all audit logs with filtering
     */
    public function index(Request $request): JsonResponse
    {
        $query = AuditLog::with('user');

        // Filter by action
        if ($request->has('action')) {
            $query->forAction($request->action);
        }

        // Filter by entity
        if ($request->has('entity_type') && $request->has('entity_id')) {
            $query->forEntity($request->entity_type, $request->entity_id);
        }

        // Filter by user
        if ($request->has('user_id')) {
            $query->byUser($request->user_id);
        }

        // Filter by tenant
        if ($request->has('tenant_id')) {
            $query->byTenant($request->tenant_id);
        }

        // Filter by date range
        if ($request->has('from_date')) {
            $query->where('created_at', '>=', $request->from_date);
        }

        if ($request->has('to_date')) {
            $query->where('created_at', '<=', $request->to_date);
        }

        // Search in action or entity
        if ($request->has('search')) {
            $search = $request->search;
            $query->where(function ($q) use ($search) {
                $q->where('action', 'LIKE', "%{$search}%")
                    ->orWhere('entity_type', 'LIKE', "%{$search}%")
                    ->orWhere('entity_id', 'LIKE', "%{$search}%");
            });
        }

        // Sort
        $sortBy = $request->get('sort_by', 'created_at');
        $sortOrder = $request->get('sort_order', 'desc');
        $query->orderBy($sortBy, $sortOrder);

        $perPage = $request->get('per_page', 50);
        $logs = $query->paginate($perPage);

        return response()->json($logs);
    }

    /**
     * Get single audit log details
     */
    public function show(int $id): JsonResponse
    {
        $log = AuditLog::with('user')->findOrFail($id);

        return response()->json($log);
    }

    /**
     * Get audit log statistics
     */
    public function statistics(Request $request): JsonResponse
    {
        $days = $request->get('days', 30);

        $stats = [
            'total_logs' => AuditLog::recent($days)->count(),
            'by_action' => AuditLog::recent($days)
                ->select('action', \DB::raw('count(*) as count'))
                ->groupBy('action')
                ->orderBy('count', 'desc')
                ->limit(10)
                ->pluck('count', 'action'),
            'by_user' => AuditLog::recent($days)
                ->select('user_id', \DB::raw('count(*) as count'))
                ->whereNotNull('user_id')
                ->groupBy('user_id')
                ->orderBy('count', 'desc')
                ->limit(10)
                ->with('user:id,name,email')
                ->get()
                ->mapWithKeys(function ($item) {
                    return [$item->user?->name ?? 'Unknown' => $item->count];
                }),
            'recent_critical' => AuditLog::recent($days)
                ->whereIn('action', ['tenant.suspended', 'tenant.deleted', 'user.deleted', 'user.deactivated'])
                ->count(),
        ];

        return response()->json($stats);
    }

    /**
     * Get activity timeline
     */
    public function timeline(Request $request): JsonResponse
    {
        $limit = $request->get('limit', 100);

        $timeline = AuditLog::with('user')
            ->orderBy('created_at', 'desc')
            ->limit($limit)
            ->get()
            ->groupBy(function ($log) {
                return $log->created_at->format('Y-m-d');
            });

        return response()->json($timeline);
    }

    /**
     * Export audit logs to CSV
     */
    public function export(Request $request): \Symfony\Component\HttpFoundation\StreamedResponse
    {
        $fileName = "audit_logs_" . now()->format('Y-m-d_H-i-s') . '.csv';

        $headers = [
            'Content-Type' => 'text/csv',
            'Content-Disposition' => "attachment; filename=\"{$fileName}\"",
        ];

        $callback = function () use ($request) {
            $file = fopen('php://output', 'w');

            // CSV headers
            fputcsv($file, [
                'ID',
                'User',
                'Action',
                'Entity Type',
                'Entity ID',
                'IP Address',
                'Timestamp',
            ]);

            // Build query with filters
            $query = AuditLog::with('user');

            if ($request->has('from_date')) {
                $query->where('created_at', '>=', $request->from_date);
            }

            if ($request->has('to_date')) {
                $query->where('created_at', '<=', $request->to_date);
            }

            // Stream data
            $query->orderBy('created_at', 'desc')->chunk(100, function ($logs) use ($file) {
                foreach ($logs as $log) {
                    fputcsv($file, [
                        $log->id,
                        $log->user?->name ?? 'System',
                        $log->action,
                        $log->entity_type ?? '-',
                        $log->entity_id ?? '-',
                        $log->ip_address ?? '-',
                        $log->created_at,
                    ]);
                }
            });

            fclose($file);
        };

        return response()->stream($callback, 200, $headers);
    }
}
