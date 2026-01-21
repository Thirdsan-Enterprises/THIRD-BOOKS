<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Tenant\Tenant;
use App\Models\User;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;

class AnalyticsController extends Controller
{
    /**
     * Get system-wide dashboard statistics
     */
    public function dashboard(): JsonResponse
    {
        $stats = [
            'overview' => $this->getOverviewStats(),
            'tenants' => $this->getTenantStats(),
            'users' => $this->getUserStats(),
            'revenue' => $this->getRevenueStats(),
            'growth' => $this->getGrowthStats(),
            'activity' => $this->getRecentActivity(),
        ];

        return response()->json($stats);
    }

    /**
     * Get overview statistics
     */
    protected function getOverviewStats(): array
    {
        $totalTenants = Tenant::count();
        $activeTenants = Tenant::where('status', 'active')->count();
        $totalUsers = User::count();
        $activeUsers = User::where('is_active', true)->count();

        return [
            'total_tenants' => $totalTenants,
            'active_tenants' => $activeTenants,
            'suspended_tenants' => Tenant::where('status', 'suspended')->count(),
            'trial_tenants' => Tenant::where('plan', 'trial')->count(),
            'total_users' => $totalUsers,
            'active_users' => $activeUsers,
            'inactive_users' => $totalUsers - $activeUsers,
        ];
    }

    /**
     * Get tenant statistics
     */
    protected function getTenantStats(): array
    {
        $byPlan = Tenant::select('plan', DB::raw('count(*) as count'))
            ->groupBy('plan')
            ->pluck('count', 'plan')
            ->toArray();

        $byStatus = Tenant::select('status', DB::raw('count(*) as count'))
            ->groupBy('status')
            ->pluck('count', 'status')
            ->toArray();

        return [
            'by_plan' => $byPlan,
            'by_status' => $byStatus,
            'expiring_soon' => Tenant::where('subscription_ends_at', '<=', now()->addDays(30))
                ->where('subscription_ends_at', '>=', now())
                ->count(),
        ];
    }

    /**
     * Get user statistics
     */
    protected function getUserStats(): array
    {
        $byRole = User::select('role', DB::raw('count(*) as count'))
            ->groupBy('role')
            ->pluck('count', 'role')
            ->toArray();

        return [
            'by_role' => $byRole,
            'logged_in_today' => User::where('updated_at', '>=', now()->subDay())->count(),
            'new_this_month' => User::where('created_at', '>=', now()->startOfMonth())->count(),
        ];
    }

    /**
     * Get revenue statistics
     */
    protected function getRevenueStats(): array
    {
        // Calculate based on active subscriptions
        $planPrices = [
            'trial' => 0,
            'starter' => 29,
            'professional' => 79,
            'enterprise' => 199,
        ];

        $monthlyRecurringRevenue = Tenant::where('status', 'active')
            ->get()
            ->sum(function ($tenant) use ($planPrices) {
                return $planPrices[$tenant->plan] ?? 0;
            });

        $annualRecurringRevenue = $monthlyRecurringRevenue * 12;

        return [
            'mrr' => $monthlyRecurringRevenue,
            'arr' => $annualRecurringRevenue,
            'paying_tenants' => Tenant::where('status', 'active')
                ->whereNotIn('plan', ['trial'])
                ->count(),
        ];
    }

    /**
     * Get growth statistics
     */
    protected function getGrowthStats(): array
    {
        $last30Days = [];

        for ($i = 29; $i >= 0; $i--) {
            $date = now()->subDays($i)->toDateString();
            $last30Days[] = [
                'date' => $date,
                'tenants' => Tenant::whereDate('created_at', $date)->count(),
                'users' => User::whereDate('created_at', $date)->count(),
            ];
        }

        return [
            'last_30_days' => $last30Days,
            'new_tenants_this_month' => Tenant::where('created_at', '>=', now()->startOfMonth())->count(),
            'new_tenants_last_month' => Tenant::whereBetween('created_at', [
                now()->subMonth()->startOfMonth(),
                now()->subMonth()->endOfMonth(),
            ])->count(),
        ];
    }

    /**
     * Get recent activity
     */
    protected function getRecentActivity(): array
    {
        $recentLogs = AuditLog::with('user')
            ->orderBy('created_at', 'desc')
            ->limit(10)
            ->get();

        return $recentLogs->toArray();
    }

    /**
     * Get tenant activity timeline
     */
    public function tenantTimeline(string $tenantId): JsonResponse
    {
        $logs = AuditLog::byTenant($tenantId)
            ->with('user')
            ->orderBy('created_at', 'desc')
            ->paginate(50);

        return response()->json($logs);
    }

    /**
     * Get system health metrics
     */
    public function systemHealth(): JsonResponse
    {
        $health = [
            'database' => $this->checkDatabase(),
            'storage' => $this->checkStorage(),
            'api_response_time' => $this->checkApiResponseTime(),
            'recent_errors' => $this->getRecentErrors(),
        ];

        return response()->json($health);
    }

    /**
     * Check database health
     */
    protected function checkDatabase(): array
    {
        try {
            $start = microtime(true);
            DB::connection()->getPdo();
            $responseTime = round((microtime(true) - $start) * 1000, 2);

            return [
                'status' => 'healthy',
                'response_time_ms' => $responseTime,
            ];
        } catch (\Exception $e) {
            return [
                'status' => 'unhealthy',
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Check storage health
     */
    protected function checkStorage(): array
    {
        $totalSpace = disk_total_space('/');
        $freeSpace = disk_free_space('/');
        $usedSpace = $totalSpace - $freeSpace;
        $usedPercentage = round(($usedSpace / $totalSpace) * 100, 2);

        return [
            'total_gb' => round($totalSpace / 1024 / 1024 / 1024, 2),
            'used_gb' => round($usedSpace / 1024 / 1024 / 1024, 2),
            'free_gb' => round($freeSpace / 1024 / 1024 / 1024, 2),
            'used_percentage' => $usedPercentage,
            'status' => $usedPercentage > 90 ? 'critical' : ($usedPercentage > 75 ? 'warning' : 'healthy'),
        ];
    }

    /**
     * Check API response time
     */
    protected function checkApiResponseTime(): array
    {
        // This is a placeholder - implement based on your monitoring system
        return [
            'avg_response_time_ms' => 150,
            'status' => 'healthy',
        ];
    }

    /**
     * Get recent errors from logs
     */
    protected function getRecentErrors(): array
    {
        // This is a placeholder - implement based on your error tracking
        return [
            'count_24h' => 0,
            'critical_errors' => 0,
        ];
    }

    /**
     * Export statistics to CSV
     */
    public function export(Request $request): \Symfony\Component\HttpFoundation\StreamedResponse
    {
        $type = $request->get('type', 'tenants');

        $fileName = "thirdbooks_{$type}_" . now()->format('Y-m-d') . '.csv';

        $headers = [
            'Content-Type' => 'text/csv',
            'Content-Disposition' => "attachment; filename=\"{$fileName}\"",
        ];

        $callback = function () use ($type) {
            $file = fopen('php://output', 'w');

            if ($type === 'tenants') {
                fputcsv($file, ['ID', 'Name', 'Email', 'Plan', 'Status', 'Created At']);
                Tenant::chunk(100, function ($tenants) use ($file) {
                    foreach ($tenants as $tenant) {
                        fputcsv($file, [
                            $tenant->id,
                            $tenant->name,
                            $tenant->email,
                            $tenant->plan,
                            $tenant->status,
                            $tenant->created_at,
                        ]);
                    }
                });
            }

            fclose($file);
        };

        return response()->stream($callback, 200, $headers);
    }
}
