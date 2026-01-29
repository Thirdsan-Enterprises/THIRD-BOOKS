<?php

namespace App\Http\Controllers\Admin\Web;

use App\Http\Controllers\Controller;
use App\Models\Tenant\Tenant;
use App\Models\User;
use Illuminate\Http\Request;
use Spatie\Activitylog\Models\Activity;

class DashboardController extends Controller
{
    public function index()
    {
        $stats = [
            'total_tenants' => Tenant::count(),
            'active_tenants' => Tenant::where('status', 'active')->count(),
            'trial_tenants' => Tenant::where('plan', 'trial')->count(),
            'suspended_tenants' => Tenant::where('status', 'suspended')->count(),
            'total_users' => User::count(),
            'active_users' => User::where('is_active', true)->count(),
            'new_tenants_this_month' => Tenant::whereMonth('created_at', now()->month)
                ->whereYear('created_at', now()->year)
                ->count(),
        ];

        $recentTenants = Tenant::orderBy('created_at', 'desc')
            ->limit(5)
            ->get();

        $recentActivity = Activity::with('causer')
            ->orderBy('created_at', 'desc')
            ->limit(10)
            ->get();

        $planDistribution = Tenant::selectRaw('plan, COUNT(*) as count')
            ->groupBy('plan')
            ->pluck('count', 'plan')
            ->toArray();

        // Ensure all plans are represented
        $plans = ['trial', 'basic', 'premium', 'enterprise'];
        foreach ($plans as $plan) {
            if (!isset($planDistribution[$plan])) {
                $planDistribution[$plan] = 0;
            }
        }

        return view('admin.dashboard', compact(
            'stats',
            'recentTenants',
            'recentActivity',
            'planDistribution'
        ));
    }
}
