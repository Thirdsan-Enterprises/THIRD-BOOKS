<?php ob_start(); ?>

<div class="tenant-header">
    <div class="tenant-info">
        <h2><?= htmlspecialchars($tenant['company_name']) ?></h2>
        <span class="badge badge-<?= ($tenant['status'] ?? 'active') === 'active' ? 'success' : 'warning' ?>">
            <?= ucfirst($tenant['status'] ?? 'active') ?>
        </span>
    </div>
    <div class="tenant-actions">
        <a href="/tenants/<?= $tenant['id'] ?>/edit" class="btn btn-secondary">Edit</a>
        <form method="POST" action="/tenants/<?= $tenant['id'] ?>/toggle-status" style="display:inline;">
            <button type="submit" class="btn btn-<?= ($tenant['status'] ?? 'active') === 'active' ? 'warning' : 'success' ?>">
                <?= ($tenant['status'] ?? 'active') === 'active' ? 'Suspend' : 'Activate' ?>
            </button>
        </form>
    </div>
</div>

<div class="stats-grid">
    <div class="stat-card">
        <div class="stat-icon blue">👥</div>
        <div class="stat-content">
            <div class="stat-value"><?= number_format($stats['users_count'] ?? 0) ?></div>
            <div class="stat-label">Users</div>
        </div>
    </div>
    <div class="stat-card">
        <div class="stat-icon green">📝</div>
        <div class="stat-content">
            <div class="stat-value"><?= number_format($stats['transactions_count'] ?? 0) ?></div>
            <div class="stat-label">Transactions</div>
        </div>
    </div>
    <div class="stat-card">
        <div class="stat-icon purple">💾</div>
        <div class="stat-content">
            <div class="stat-value"><?= $stats['storage_used'] ?? '0 MB' ?></div>
            <div class="stat-label">Storage Used</div>
        </div>
    </div>
    <div class="stat-card">
        <div class="stat-icon orange">🕐</div>
        <div class="stat-content">
            <div class="stat-value"><?= $stats['last_activity'] ? date('M j, Y', strtotime($stats['last_activity'])) : 'Never' ?></div>
            <div class="stat-label">Last Activity</div>
        </div>
    </div>
</div>

<div class="card">
    <div class="card-header">
        <h2 class="card-title">Tenant Details</h2>
    </div>
    <div class="card-body">
        <div class="details-grid">
            <div class="detail-item">
                <span class="detail-label">Company Name</span>
                <span class="detail-value"><?= htmlspecialchars($tenant['company_name']) ?></span>
            </div>
            <div class="detail-item">
                <span class="detail-label">Owner</span>
                <span class="detail-value"><?= htmlspecialchars($tenant['owner_name'] ?? '-') ?></span>
            </div>
            <div class="detail-item">
                <span class="detail-label">Email</span>
                <span class="detail-value"><?= htmlspecialchars($tenant['owner_email'] ?? '-') ?></span>
            </div>
            <div class="detail-item">
                <span class="detail-label">Phone</span>
                <span class="detail-value"><?= htmlspecialchars($tenant['phone'] ?? '-') ?></span>
            </div>
            <div class="detail-item">
                <span class="detail-label">Plan</span>
                <span class="detail-value"><?= ucfirst($tenant['plan'] ?? 'basic') ?></span>
            </div>
            <div class="detail-item">
                <span class="detail-label">Created</span>
                <span class="detail-value"><?= date('F j, Y', strtotime($tenant['created_at'])) ?></span>
            </div>
            <div class="detail-item full-width">
                <span class="detail-label">Address</span>
                <span class="detail-value"><?= htmlspecialchars($tenant['address'] ?? '-') ?></span>
            </div>
        </div>
    </div>
</div>

<div class="card danger-zone">
    <div class="card-header">
        <h2 class="card-title">Danger Zone</h2>
    </div>
    <div class="card-body">
        <p>Deleting a tenant will permanently remove all their data including users, transactions, and files.</p>
        <form method="POST" action="/tenants/<?= $tenant['id'] ?>/delete"
              onsubmit="return confirm('Are you sure you want to delete this tenant? This action cannot be undone.');">
            <button type="submit" class="btn btn-danger">Delete Tenant</button>
        </form>
    </div>
</div>

<?php $content = ob_get_clean(); ?>
<?php include __DIR__ . '/../layouts/main.php'; ?>
