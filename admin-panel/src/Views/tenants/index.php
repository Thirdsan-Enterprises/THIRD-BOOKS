<?php ob_start(); ?>

<div class="toolbar">
    <form method="GET" action="/tenants" class="search-form">
        <input type="text" name="search" value="<?= htmlspecialchars($search) ?>" placeholder="Search tenants...">
        <select name="status">
            <option value="">All Statuses</option>
            <option value="active" <?= $status === 'active' ? 'selected' : '' ?>>Active</option>
            <option value="suspended" <?= $status === 'suspended' ? 'selected' : '' ?>>Suspended</option>
            <option value="inactive" <?= $status === 'inactive' ? 'selected' : '' ?>>Inactive</option>
        </select>
        <button type="submit" class="btn btn-secondary">Search</button>
    </form>
    <a href="/tenants/create" class="btn btn-primary">+ New Tenant</a>
</div>

<div class="card">
    <div class="card-body">
        <?php if (empty($tenants)): ?>
            <div class="empty-state">
                <p>No tenants found.</p>
                <a href="/tenants/create" class="btn btn-primary">Create First Tenant</a>
            </div>
        <?php else: ?>
            <table class="table">
                <thead>
                    <tr>
                        <th>Company</th>
                        <th>Owner</th>
                        <th>Plan</th>
                        <th>Users</th>
                        <th>Status</th>
                        <th>Created</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($tenants as $tenant): ?>
                        <tr>
                            <td>
                                <strong><?= htmlspecialchars($tenant['company_name']) ?></strong>
                            </td>
                            <td>
                                <?= htmlspecialchars($tenant['owner_name'] ?? '-') ?><br>
                                <small><?= htmlspecialchars($tenant['owner_email'] ?? '') ?></small>
                            </td>
                            <td>
                                <span class="badge badge-info"><?= ucfirst($tenant['plan'] ?? 'basic') ?></span>
                            </td>
                            <td><?= $tenant['users_count'] ?? 0 ?></td>
                            <td>
                                <span class="badge badge-<?= ($tenant['status'] ?? 'active') === 'active' ? 'success' : 'warning' ?>">
                                    <?= ucfirst($tenant['status'] ?? 'active') ?>
                                </span>
                            </td>
                            <td><?= date('M j, Y', strtotime($tenant['created_at'])) ?></td>
                            <td>
                                <div class="action-buttons">
                                    <a href="/tenants/<?= $tenant['id'] ?>" class="btn btn-sm btn-secondary">View</a>
                                    <a href="/tenants/<?= $tenant['id'] ?>/edit" class="btn btn-sm btn-secondary">Edit</a>
                                </div>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>

            <?php if ($pagination['last_page'] > 1): ?>
                <div class="pagination">
                    <?php for ($i = 1; $i <= $pagination['last_page']; $i++): ?>
                        <a href="/tenants?page=<?= $i ?>&search=<?= urlencode($search) ?>&status=<?= urlencode($status) ?>"
                           class="pagination-link <?= $i === $pagination['current_page'] ? 'active' : '' ?>">
                            <?= $i ?>
                        </a>
                    <?php endfor; ?>
                </div>
            <?php endif; ?>
        <?php endif; ?>
    </div>
</div>

<?php $content = ob_get_clean(); ?>
<?php include __DIR__ . '/../layouts/main.php'; ?>
