<?php ob_start(); ?>

<div class="stats-grid">
    <div class="stat-card">
        <div class="stat-icon blue">🏢</div>
        <div class="stat-content">
            <div class="stat-value"><?= number_format($stats['total_tenants'] ?? 0) ?></div>
            <div class="stat-label">Total Tenants</div>
        </div>
    </div>

    <div class="stat-card">
        <div class="stat-icon green">✓</div>
        <div class="stat-content">
            <div class="stat-value"><?= number_format($stats['active_tenants'] ?? 0) ?></div>
            <div class="stat-label">Active Tenants</div>
        </div>
    </div>

    <div class="stat-card">
        <div class="stat-icon purple">👥</div>
        <div class="stat-content">
            <div class="stat-value"><?= number_format($stats['total_users'] ?? 0) ?></div>
            <div class="stat-label">Total Users</div>
        </div>
    </div>

    <div class="stat-card">
        <div class="stat-icon orange">💰</div>
        <div class="stat-content">
            <div class="stat-value">UGX <?= number_format($stats['monthly_revenue'] ?? 0) ?></div>
            <div class="stat-label">Monthly Revenue</div>
        </div>
    </div>
</div>

<div class="dashboard-grid">
    <div class="card">
        <div class="card-header">
            <h2 class="card-title">Recent Tenants</h2>
            <a href="/tenants" class="card-action">View All →</a>
        </div>
        <div class="card-body">
            <?php if (empty($recentTenants)): ?>
                <p class="empty-state">No tenants yet. <a href="/tenants/create">Create the first tenant</a>.</p>
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
                                    <a href="/tenants/<?= $tenant['id'] ?>"><?= htmlspecialchars($tenant['company_name']) ?></a>
                                </td>
                                <td><?= ucfirst($tenant['plan'] ?? 'basic') ?></td>
                                <td>
                                    <span class="badge badge-<?= ($tenant['status'] ?? 'active') === 'active' ? 'success' : 'warning' ?>">
                                        <?= ucfirst($tenant['status'] ?? 'active') ?>
                                    </span>
                                </td>
                                <td><?= date('M j, Y', strtotime($tenant['created_at'])) ?></td>
                            </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            <?php endif; ?>
        </div>
    </div>

    <div class="card">
        <div class="card-header">
            <h2 class="card-title">Recent Activity</h2>
        </div>
        <div class="card-body">
            <?php if (empty($recentActivity)): ?>
                <p class="empty-state">No recent activity.</p>
            <?php else: ?>
                <ul class="activity-list">
                    <?php foreach ($recentActivity as $activity): ?>
                        <li class="activity-item">
                            <span class="activity-icon"><?= $activity['icon'] ?? '📝' ?></span>
                            <div class="activity-content">
                                <p class="activity-text"><?= htmlspecialchars($activity['description']) ?></p>
                                <span class="activity-time"><?= $activity['time_ago'] ?? '' ?></span>
                            </div>
                        </li>
                    <?php endforeach; ?>
                </ul>
            <?php endif; ?>
        </div>
    </div>
</div>

<div class="card">
    <div class="card-header">
        <h2 class="card-title">Quick Actions</h2>
    </div>
    <div class="card-body">
        <div class="quick-actions">
            <a href="/tenants/create" class="quick-action-btn">
                <span class="quick-action-icon">➕</span>
                <span>New Tenant</span>
            </a>
            <a href="/reports" class="quick-action-btn">
                <span class="quick-action-icon">📊</span>
                <span>View Reports</span>
            </a>
            <a href="/settings" class="quick-action-btn">
                <span class="quick-action-icon">⚙️</span>
                <span>Settings</span>
            </a>
        </div>
    </div>
</div>

<?php $content = ob_get_clean(); ?>
<?php include __DIR__ . '/../layouts/main.php'; ?>
