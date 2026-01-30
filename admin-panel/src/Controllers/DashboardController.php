<?php

namespace ThirdBooks\Admin\Controllers;

class DashboardController extends BaseController
{
    public function index(): void
    {
        // Fetch dashboard statistics from API
        $stats = $this->apiGet('/admin/dashboard/stats');

        // Default stats if API fails
        if (isset($stats['error'])) {
            $stats = [
                'total_tenants' => 0,
                'active_tenants' => 0,
                'total_users' => 0,
                'total_transactions' => 0,
                'monthly_revenue' => 0,
                'storage_used' => 0,
            ];
        }

        // Fetch recent activity
        $recentActivity = $this->apiGet('/admin/dashboard/activity');
        if (isset($recentActivity['error'])) {
            $recentActivity = ['data' => []];
        }

        // Fetch recent tenants
        $recentTenants = $this->apiGet('/admin/tenants', ['limit' => 5, 'sort' => '-created_at']);
        if (isset($recentTenants['error'])) {
            $recentTenants = ['data' => []];
        }

        $this->view('dashboard/index', [
            'title' => 'Dashboard',
            'stats' => $stats,
            'recentActivity' => $recentActivity['data'] ?? [],
            'recentTenants' => $recentTenants['data'] ?? [],
            'flash' => $this->getFlash(),
        ]);
    }
}
