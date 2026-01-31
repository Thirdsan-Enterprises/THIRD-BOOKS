<?php
/**
 * ThirdBooks Admin Panel - Dashboard
 */

define('ADMIN_PANEL', true);
require_once __DIR__ . '/config/config.php';

// Start session
session_name(SESSION_NAME);
session_start();

// Require authentication
requireAuth();

$user = getAuthUser();
$pdo = getDbConnection();

// Get statistics
try {
    // Total tenants
    $stmt = $pdo->query('SELECT COUNT(*) as count FROM tenants WHERE deleted_at IS NULL');
    $totalTenants = $stmt->fetch()['count'];

    // Active tenants
    $stmt = $pdo->query("SELECT COUNT(*) as count FROM tenants WHERE status = 'active' AND deleted_at IS NULL");
    $activeTenants = $stmt->fetch()['count'];

    // Total users
    $stmt = $pdo->query('SELECT COUNT(*) as count FROM users WHERE deleted_at IS NULL');
    $totalUsers = $stmt->fetch()['count'];

    // Recent tenants
    $stmt = $pdo->query('SELECT * FROM tenants WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT 5');
    $recentTenants = $stmt->fetchAll();

    // Tenants by plan
    $stmt = $pdo->query("SELECT plan, COUNT(*) as count FROM tenants WHERE deleted_at IS NULL GROUP BY plan");
    $tenantsByPlan = $stmt->fetchAll();

    // Tenants by status
    $stmt = $pdo->query("SELECT status, COUNT(*) as count FROM tenants WHERE deleted_at IS NULL GROUP BY status");
    $tenantsByStatus = $stmt->fetchAll();

} catch (PDOException $e) {
    logMessage('error', 'Dashboard query failed', ['error' => $e->getMessage()]);
    $totalTenants = $activeTenants = $totalUsers = 0;
    $recentTenants = $tenantsByPlan = $tenantsByStatus = [];
}

$pageTitle = 'Dashboard';
include __DIR__ . '/views/layouts/header.php';
?>

<div class="dashboard">
    <!-- Statistics Cards -->
    <div class="stats-grid">
        <div class="stat-card">
            <div class="stat-icon" style="background-color: #e3f2fd;">
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#1976d2" stroke-width="2">
                    <path d="M3 21h18M3 10h18M3 7l9-4 9 4M4 10h16v11H4z"/>
                </svg>
            </div>
            <div class="stat-content">
                <h3><?= number_format($totalTenants) ?></h3>
                <p>Total Tenants</p>
            </div>
        </div>

        <div class="stat-card">
            <div class="stat-icon" style="background-color: #e8f5e9;">
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#388e3c" stroke-width="2">
                    <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
                    <polyline points="22 4 12 14.01 9 11.01"/>
                </svg>
            </div>
            <div class="stat-content">
                <h3><?= number_format($activeTenants) ?></h3>
                <p>Active Tenants</p>
            </div>
        </div>

        <div class="stat-card">
            <div class="stat-icon" style="background-color: #fff3e0;">
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#f57c00" stroke-width="2">
                    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                    <circle cx="9" cy="7" r="4"/>
                    <path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>
                </svg>
            </div>
            <div class="stat-content">
                <h3><?= number_format($totalUsers) ?></h3>
                <p>Total Users</p>
            </div>
        </div>

        <div class="stat-card">
            <div class="stat-icon" style="background-color: #fce4ec;">
                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#c2185b" stroke-width="2">
                    <line x1="12" y1="1" x2="12" y2="23"/>
                    <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>
                </svg>
            </div>
            <div class="stat-content">
                <h3><?= number_format($totalTenants - $activeTenants) ?></h3>
                <p>Inactive/Suspended</p>
            </div>
        </div>
    </div>

    <div class="dashboard-grid">
        <!-- Recent Tenants -->
        <div class="card">
            <div class="card-header">
                <h2>Recent Tenants</h2>
                <a href="tenants.php" class="btn btn-sm btn-outline">View All</a>
            </div>
            <div class="card-body">
                <?php if (empty($recentTenants)): ?>
                    <p class="text-muted">No tenants yet.</p>
                <?php else: ?>
                    <table class="table">
                        <thead>
                            <tr>
                                <th>Company</th>
                                <th>Plan</th>
                                <th>Status</th>
                                <th>Created</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($recentTenants as $tenant): ?>
                            <tr>
                                <td>
                                    <strong><?= e($tenant['company_name'] ?: $tenant['name']) ?></strong>
                                    <br>
                                    <small class="text-muted"><?= e($tenant['email']) ?></small>
                                </td>
                                <td>
                                    <span class="badge badge-<?= $tenant['plan'] === 'enterprise' ? 'primary' : ($tenant['plan'] === 'professional' ? 'info' : 'secondary') ?>">
                                        <?= ucfirst($tenant['plan']) ?>
                                    </span>
                                </td>
                                <td>
                                    <span class="badge badge-<?= $tenant['status'] === 'active' ? 'success' : ($tenant['status'] === 'suspended' ? 'danger' : 'warning') ?>">
                                        <?= ucfirst($tenant['status']) ?>
                                    </span>
                                </td>
                                <td><?= formatDate($tenant['created_at']) ?></td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                <?php endif; ?>
            </div>
        </div>

        <!-- Tenants by Plan -->
        <div class="card">
            <div class="card-header">
                <h2>Tenants by Plan</h2>
            </div>
            <div class="card-body">
                <?php if (empty($tenantsByPlan)): ?>
                    <p class="text-muted">No data available.</p>
                <?php else: ?>
                    <div class="plan-stats">
                        <?php foreach ($tenantsByPlan as $plan): ?>
                        <div class="plan-stat">
                            <div class="plan-stat-bar">
                                <div class="plan-stat-fill" style="width: <?= $totalTenants > 0 ? ($plan['count'] / $totalTenants * 100) : 0 ?>%; background-color: <?= $plan['plan'] === 'enterprise' ? '#1976d2' : ($plan['plan'] === 'professional' ? '#0097a7' : ($plan['plan'] === 'starter' ? '#7cb342' : '#9e9e9e')) ?>;"></div>
                            </div>
                            <div class="plan-stat-label">
                                <span><?= ucfirst($plan['plan']) ?></span>
                                <span class="count"><?= $plan['count'] ?></span>
                            </div>
                        </div>
                        <?php endforeach; ?>
                    </div>
                <?php endif; ?>
            </div>
        </div>
    </div>

    <!-- Quick Actions -->
    <div class="card">
        <div class="card-header">
            <h2>Quick Actions</h2>
        </div>
        <div class="card-body">
            <div class="quick-actions">
                <a href="tenants.php" class="quick-action">
                    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M3 21h18M3 10h18M3 7l9-4 9 4M4 10h16v11H4z"/>
                    </svg>
                    <span>Manage Tenants</span>
                </a>
                <a href="users.php" class="quick-action">
                    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                        <circle cx="9" cy="7" r="4"/>
                        <path d="M23 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>
                    </svg>
                    <span>Manage Users</span>
                </a>
                <a href="reports.php" class="quick-action">
                    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/>
                        <polyline points="14 2 14 8 20 8"/>
                        <line x1="16" y1="13" x2="8" y2="13"/>
                        <line x1="16" y1="17" x2="8" y2="17"/>
                    </svg>
                    <span>View Reports</span>
                </a>
                <a href="settings.php" class="quick-action">
                    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <circle cx="12" cy="12" r="3"/>
                        <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>
                    </svg>
                    <span>Settings</span>
                </a>
            </div>
        </div>
    </div>
</div>

<?php include __DIR__ . '/views/layouts/footer.php'; ?>
