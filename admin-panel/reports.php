<?php
/**
 * ThirdBooks Admin Panel - Reports
 */

define('ADMIN_PANEL', true);
require_once __DIR__ . '/config/config.php';

session_name(SESSION_NAME);
session_start();
requireAuth();

$user = getAuthUser();
$pdo = getDbConnection();

// Get report data
try {
    // Tenants by month (last 6 months)
    $stmt = $pdo->query("
        SELECT DATE_FORMAT(created_at, '%Y-%m') as month, COUNT(*) as count
        FROM tenants
        WHERE created_at >= DATE_SUB(NOW(), INTERVAL 6 MONTH) AND deleted_at IS NULL
        GROUP BY month
        ORDER BY month
    ");
    $tenantsByMonth = $stmt->fetchAll();

    // Tenants by plan
    $stmt = $pdo->query("SELECT plan, COUNT(*) as count FROM tenants WHERE deleted_at IS NULL GROUP BY plan ORDER BY count DESC");
    $tenantsByPlan = $stmt->fetchAll();

    // Tenants by status
    $stmt = $pdo->query("SELECT status, COUNT(*) as count FROM tenants WHERE deleted_at IS NULL GROUP BY status");
    $tenantsByStatus = $stmt->fetchAll();

    // Users by role
    $stmt = $pdo->query("SELECT role, COUNT(*) as count FROM users WHERE deleted_at IS NULL GROUP BY role ORDER BY count DESC");
    $usersByRole = $stmt->fetchAll();

    // Recent activity
    $stmt = $pdo->query("
        SELECT 'tenant' as type, name, created_at FROM tenants WHERE deleted_at IS NULL
        UNION ALL
        SELECT 'user' as type, name, created_at FROM users WHERE deleted_at IS NULL
        ORDER BY created_at DESC LIMIT 10
    ");
    $recentActivity = $stmt->fetchAll();

} catch (PDOException $e) {
    $tenantsByMonth = $tenantsByPlan = $tenantsByStatus = $usersByRole = $recentActivity = [];
}

$pageTitle = 'Reports';
include __DIR__ . '/views/layouts/header.php';
?>

<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr)); gap: 24px;">
    <!-- Tenants by Plan -->
    <div class="card">
        <div class="card-header">
            <h2>Tenants by Plan</h2>
        </div>
        <div class="card-body">
            <?php if (empty($tenantsByPlan)): ?>
            <p class="text-muted">No data available.</p>
            <?php else: ?>
            <?php
            $total = array_sum(array_column($tenantsByPlan, 'count'));
            $colors = ['free' => '#9e9e9e', 'starter' => '#7cb342', 'professional' => '#0097a7', 'enterprise' => '#1976d2'];
            ?>
            <?php foreach ($tenantsByPlan as $plan): ?>
            <div style="margin-bottom: 16px;">
                <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
                    <span><?= ucfirst($plan['plan']) ?></span>
                    <span><strong><?= $plan['count'] ?></strong> (<?= $total > 0 ? round($plan['count'] / $total * 100) : 0 ?>%)</span>
                </div>
                <div style="height: 8px; background: #e5e7eb; border-radius: 4px; overflow: hidden;">
                    <div style="height: 100%; width: <?= $total > 0 ? ($plan['count'] / $total * 100) : 0 ?>%; background: <?= $colors[$plan['plan']] ?? '#666' ?>;"></div>
                </div>
            </div>
            <?php endforeach; ?>
            <?php endif; ?>
        </div>
    </div>

    <!-- Tenants by Status -->
    <div class="card">
        <div class="card-header">
            <h2>Tenants by Status</h2>
        </div>
        <div class="card-body">
            <?php if (empty($tenantsByStatus)): ?>
            <p class="text-muted">No data available.</p>
            <?php else: ?>
            <?php
            $total = array_sum(array_column($tenantsByStatus, 'count'));
            $colors = ['active' => '#10b981', 'suspended' => '#ef4444', 'pending' => '#f59e0b', 'cancelled' => '#6b7280'];
            ?>
            <?php foreach ($tenantsByStatus as $status): ?>
            <div style="margin-bottom: 16px;">
                <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
                    <span><?= ucfirst($status['status']) ?></span>
                    <span><strong><?= $status['count'] ?></strong></span>
                </div>
                <div style="height: 8px; background: #e5e7eb; border-radius: 4px; overflow: hidden;">
                    <div style="height: 100%; width: <?= $total > 0 ? ($status['count'] / $total * 100) : 0 ?>%; background: <?= $colors[$status['status']] ?? '#666' ?>;"></div>
                </div>
            </div>
            <?php endforeach; ?>
            <?php endif; ?>
        </div>
    </div>

    <!-- Users by Role -->
    <div class="card">
        <div class="card-header">
            <h2>Users by Role</h2>
        </div>
        <div class="card-body">
            <?php if (empty($usersByRole)): ?>
            <p class="text-muted">No data available.</p>
            <?php else: ?>
            <table class="table" style="margin: 0;">
                <thead>
                    <tr>
                        <th>Role</th>
                        <th style="text-align: right;">Count</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($usersByRole as $role): ?>
                    <tr>
                        <td><?= ucfirst(str_replace('_', ' ', $role['role'])) ?></td>
                        <td style="text-align: right;"><strong><?= $role['count'] ?></strong></td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
            <?php endif; ?>
        </div>
    </div>

    <!-- Recent Activity -->
    <div class="card">
        <div class="card-header">
            <h2>Recent Registrations</h2>
        </div>
        <div class="card-body">
            <?php if (empty($recentActivity)): ?>
            <p class="text-muted">No recent activity.</p>
            <?php else: ?>
            <table class="table" style="margin: 0;">
                <thead>
                    <tr>
                        <th>Type</th>
                        <th>Name</th>
                        <th>Date</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($recentActivity as $activity): ?>
                    <tr>
                        <td><span class="badge badge-<?= $activity['type'] === 'tenant' ? 'primary' : 'secondary' ?>"><?= ucfirst($activity['type']) ?></span></td>
                        <td><?= e($activity['name']) ?></td>
                        <td><?= formatDateTime($activity['created_at']) ?></td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
            <?php endif; ?>
        </div>
    </div>
</div>

<!-- Monthly Growth -->
<div class="card" style="margin-top: 24px;">
    <div class="card-header">
        <h2>Tenant Growth (Last 6 Months)</h2>
    </div>
    <div class="card-body">
        <?php if (empty($tenantsByMonth)): ?>
        <p class="text-muted">No data available for the selected period.</p>
        <?php else: ?>
        <div style="display: flex; gap: 24px; align-items: flex-end; height: 200px;">
            <?php
            $maxCount = max(array_column($tenantsByMonth, 'count'));
            foreach ($tenantsByMonth as $month):
                $height = $maxCount > 0 ? ($month['count'] / $maxCount * 100) : 0;
            ?>
            <div style="flex: 1; display: flex; flex-direction: column; align-items: center;">
                <div style="width: 100%; background: #0d9488; border-radius: 4px 4px 0 0; height: <?= $height ?>%; min-height: 4px;"></div>
                <div style="margin-top: 8px; text-align: center;">
                    <strong><?= $month['count'] ?></strong><br>
                    <small class="text-muted"><?= date('M Y', strtotime($month['month'] . '-01')) ?></small>
                </div>
            </div>
            <?php endforeach; ?>
        </div>
        <?php endif; ?>
    </div>
</div>

<?php include __DIR__ . '/views/layouts/footer.php'; ?>
