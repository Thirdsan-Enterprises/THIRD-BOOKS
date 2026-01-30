<?php ob_start(); ?>

<div class="toolbar">
    <form method="GET" action="/users" class="search-form">
        <input type="text" name="search" value="<?= htmlspecialchars($search) ?>" placeholder="Search users...">
        <button type="submit" class="btn btn-secondary">Search</button>
    </form>
</div>

<div class="card">
    <div class="card-body">
        <?php if (empty($users)): ?>
            <div class="empty-state">
                <p>No users found.</p>
            </div>
        <?php else: ?>
            <table class="table">
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Email</th>
                        <th>Tenant</th>
                        <th>Role</th>
                        <th>Status</th>
                        <th>Last Login</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($users as $user): ?>
                        <tr>
                            <td><?= htmlspecialchars($user['name']) ?></td>
                            <td><?= htmlspecialchars($user['email']) ?></td>
                            <td><?= htmlspecialchars($user['tenant_name'] ?? '-') ?></td>
                            <td><?= ucfirst($user['role'] ?? 'user') ?></td>
                            <td>
                                <span class="badge badge-<?= ($user['status'] ?? 'active') === 'active' ? 'success' : 'warning' ?>">
                                    <?= ucfirst($user['status'] ?? 'active') ?>
                                </span>
                            </td>
                            <td><?= $user['last_login_at'] ? date('M j, Y H:i', strtotime($user['last_login_at'])) : 'Never' ?></td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
    </div>
</div>

<?php $content = ob_get_clean(); ?>
<?php include __DIR__ . '/../layouts/main.php'; ?>
